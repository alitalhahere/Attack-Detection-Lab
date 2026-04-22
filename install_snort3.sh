#!/bin/bash
# Snort 3 Installation Script for Ubuntu 20.04/22.04
# Fully automated: builds Snort 3, configures custom rules, updates snort.lua (ips section only),
# and adds a convenient alias 'snort-run' to start Snort on eth0.

set -e  # Exit on any error

echo "[+] Starting Snort 3 installation..."

# 1. Update system and install required build dependencies
echo "[+] Installing dependencies..."
sudo apt update -y
sudo apt install -y \
    build-essential libpcap-dev libpcre3-dev libpcre2-dev libnet1-dev \
    zlib1g-dev libluajit-5.1-dev hwloc libdumbnet-dev \
    bison flex liblzma-dev libssl-dev pkg-config libhwloc-dev \
    cmake libsqlite3-dev uuid-dev libnetfilter-queue-dev libmnl-dev \
    autotools-dev libunwind-dev libfl-dev cpputest \
    wget tar xz-utils git curl

# 2. Create working directory in /opt/snort3
echo "[+] Creating /opt/snort3 and entering..."
sudo mkdir -p /opt/snort3
cd /opt/snort3

# 3. Build and install cmocka
echo "[+] Building cmocka..."
wget https://cmocka.org/files/1.1/cmocka-1.1.5.tar.xz
tar -xf cmocka-1.1.5.tar.xz
cd cmocka-1.1.5
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
sudo make install
cd ../..

# 4. Build and install libdaq
echo "[+] Building libdaq..."
git clone https://github.com/snort3/libdaq.git
cd libdaq
./bootstrap
./configure
make -j$(nproc)
sudo make install
cd ..

# 5. Download and build Snort 3
echo "[+] Building Snort 3..."
curl -LO https://github.com/snort3/snort3/archive/refs/tags/3.9.3.0.tar.gz
tar -xzf 3.9.3.0.tar.gz
cd snort3-3.9.3.0
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
sudo make install
cd ../..

# 6. Update shared library cache
echo "[+] Updating ldconfig..."
sudo ldconfig

# 7. Verify Snort version
echo "[+] Snort version:"
snort -v

# 8. Create directories for rules and logs
echo "[+] Creating rule and log directories..."
sudo mkdir -p /usr/local/etc/snort/rules /var/log/snort

# 9. Create local.rules with custom rules (no Smurf, UDP flood SID=1000006, no blank lines between rules)
echo "[+] Creating local.rules..."
sudo tee /usr/local/etc/snort/rules/local.rules > /dev/null <<'EOF'
# ICMP Echo Request detection
alert icmp any any -> any any (
    msg:"ICMP Test";
    sid:1000001;
    rev:1;
)
# Basic oversized ICMP detection (catches most Ping of Death variants)
alert icmp any any -> any any (
    msg:"ICMP Ping of Death Detected";
    dsize:>1000;
    sid:1000002;
)
# Fragmented ping detection (catches modern attacks)
alert icmp any any -> any any (
    msg:"ICMP Fragmented Ping Attack";
    fragbits:M;
    sid:1000003;
)
# ICMP Flood Detection Rule
alert icmp any any -> any any (
    msg:"ICMP Flood Attack Detected";
    detection_filter:track by_src, count 100, seconds 1;
    sid:1000004;
    rev:1;
)
# SYN Flood Attack Rule
alert tcp any any -> any any (
    msg:"SYN Flood Attack Detected";
    flags:S;
    detection_filter:track by_src, count 100, seconds 1;
    flow:stateless;
    sid:1000005;
    rev:1;
    metadata:service http;
)
# UDP Flood Attack Rule (targeting port 445)
alert udp any any -> any 445 (
    msg:"UDP Flood Attack Detected";
    detection_filter:track by_dst, count 300, seconds 1;
    sid:1000006;
    rev:1;
)
EOF

# 10. Download Snort 3 Community Rules
echo "[+] Downloading Snort 3 Community Rules..."
curl -L -o /opt/snort3/snort3-community-rules.tar.gz https://www.snort.org/downloads/community/snort3-community-rules.tar.gz
sudo tar -xzf /opt/snort3/snort3-community-rules.tar.gz -C /usr/local/etc/snort

# 11. Backup and update snort.lua (only the ips section)
echo "[+] Updating snort.lua (ips section only)..."
sudo cp /usr/local/etc/snort/snort.lua /usr/local/etc/snort/snort.lua.bak

sudo python3 << 'EOF'
import re

with open('/usr/local/etc/snort/snort.lua', 'r') as f:
    content = f.read()

new_ips = '''ips =
{
    enable_builtin_rules = true,
    rules = [[
        include /usr/local/etc/snort/snort3-community-rules/snort3-community.rules
        include /usr/local/etc/snort/rules/local.rules
    ]],
    variables = default_variables
}'''

# Match 'ips =' followed by optional whitespace and a brace-balanced block (supports nested braces)
pattern = r'ips\s*=\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}'
new_content = re.sub(pattern, new_ips, content, flags=re.DOTALL)

with open('/usr/local/etc/snort/snort.lua', 'w') as f:
    f.write(new_content)

print("[+] snort.lua updated (ips section replaced, other configuration preserved)")
EOF

# 12. Validate the configuration
echo "[+] Validating Snort configuration..."
snort -c /usr/local/etc/snort/snort.lua -T

# 13. Add convenient alias 'snort-run' to user's .bashrc (preserve existing, avoid duplicates)
echo "[+] Adding alias 'snort-run' to ~/.bashrc..."
ALIAS_CMD="alias snort-run='sudo snort -c /usr/local/etc/snort/snort.lua -i eth0 -A alert_fast -l /var/log/snort -k none -q'"

# Determine the real user's home directory (even when running with sudo)
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi

BASHRC="$USER_HOME/.bashrc"
if [ -f "$BASHRC" ]; then
    if ! grep -Fxq "$ALIAS_CMD" "$BASHRC"; then
        echo "$ALIAS_CMD" >> "$BASHRC"
        echo "[+] Alias added to $BASHRC"
    else
        echo "[+] Alias already exists in $BASHRC"
    fi
else
    echo "$ALIAS_CMD" > "$BASHRC"
    echo "[+] Created $BASHRC and added alias"
fi

echo ""
echo "[+] Snort 3 installation completed successfully!"
echo "To start Snort on eth0, simply type:  snort-run"
echo "(You may need to restart your terminal or run 'source ~/.bashrc' first.)"
echo ""
echo "Test with a ping from another machine:"
echo "  ping -c 3 <IP_of_snort_machine>"
echo "Then press Ctrl+C to stop Snort and see alerts."
