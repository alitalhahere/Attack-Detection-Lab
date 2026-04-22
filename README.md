# 🛡️ Attack Detection Lab

**A complete virtual lab for learning intrusion detection: Snort 3 IDS/IPS + Kali attacker + Metasploitable 2 target.**

![Snort](https://img.shields.io/badge/Snort-3.9.3.0-red)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)
![Kali](https://img.shields.io/badge/Kali-Linux-blue)
![Metasploitable](https://img.shields.io/badge/Metasploitable-2-green)

---

## 🎯 Purpose

This lab demonstrates how to:
- Set up a dedicated **Snort 3 IDS/IPS** on Ubuntu
- Launch real attacks from **Kali Linux** against **Metasploitable 2**
- Detect attacks using **custom Snort rules**
- Analyze alerts in real time

Perfect for blue team training, SOC analysts, and cybersecurity students.

---
## Lab Architecture

All three VMs are connected to the same virtual network. Snort's network interface is set to **promiscuous mode** so it can see all traffic between Kali and Metasploitable.

| Role       | VM              |
|------------|-----------------|
| Attacker   | Kali Linux      |
| IDS/IPS    | Snort (Ubuntu)  |
| Target     | Metasploitable 2 |

Same NAT / Host‑only Network

All three VMs are connected to the same virtual network. Snort’s network interface is set to **promiscuous mode** so it can see all traffic between Kali and Metasploitable.

---

## 📦 Requirements

- **Host machine**: 8+ GB RAM, 50+ GB free disk, VirtualBox or VMware
- **Guest VMs**:
  - Kali Linux (attacker) – you can use your existing Kali
  - Metasploitable 2 (target) – [download](https://sourceforge.net/projects/metasploitable/)
  - Ubuntu 22.04 (Snort) – fresh installation

---

## 🚀 Quick Setup (Snort VM)

1. **Create a new Ubuntu 22.04 VM** (2 GB RAM, 20 GB disk).  
   Attach its network interface to the same virtual network as Kali and Metasploitable.  
   Enable **promiscuous mode** (VirtualBox: VM Settings → Network → Advanced → Promiscuous Mode → Allow All).

2. **Clone this repository** inside the Ubuntu VM:

```bash
sudo apt update && sudo apt install git -y
git clone https://github.com/alitalhahere/Attack-Detection-Lab.git
cd Attack-Detection-Lab
```

Run the Snort installation script:
```bash
chmod +x install_snort3.sh
sudo ./install_snort3.sh
```
This installs Snort 3, configures custom rules, and adds the snort-run alias.

3. Reload your shell to use the alias:
```bash
source ~/.bashrc
```
5. Start Snort on the correct interface (e.g., eth0):
```bash
snort-run
```

You will see no output – Snort runs quietly in the background. Press Ctrl+C to stop and view alerts.

---

## Testing with Attacks

From your Kali VM, run these commands against the **Snort VM IP** (for ICMP‑based attacks) or **Metasploitable‑2 IP** (for service‑based attacks). 

Replace `<target_ip>` with the appropriate IP address.


| Attack           | Command                                                | Expected Snort Alert                         |
|------------------|--------------------------------------------------------|----------------------------------------------|
| Basic ping       | `ping -c 3 <target_ip>`                                | ICMP Test (sid:1000001)                      |
| Ping of Death    | `ping -l 65500 -c 1 <target_ip>`                      | ICMP Ping of Death Detected (sid:1000002)    |
| ICMP Flood       | `sudo hping3 --icmp --flood <target_ip>`              | ICMP Flood Attack Detected (sid:1000004)     |
| SYN Flood        | `sudo hping3 -S --flood <target_ip>`                  | SYN Flood Attack Detected (sid:1000005)      |
| UDP Flood        | `sudo hping3 --udp -p 445 --flood <target_ip>`        | UDP Flood Attack Detected (sid:1000006)      |


⚠️ **Warning:** Flood attacks generate heavy traffic. Use them only in this isolated lab environment.

After each attack, press Ctrl+C on the Snort terminal. The alerts will appear immediately.

---

## 📝 Custom Snort Rules
All custom rules are stored in /usr/local/etc/snort/rules/local.rules.

They are also available in this repository under rules/local.rules.

---

## 🛠️ Troubleshooting

**Snort doesn’t see any traffic:** Ensure the Snort VM’s interface is in promiscuous mode and that all VMs are on the same network.

**snort-run command not found:** Run source ~/.bashrc or open a new terminal.

**Installation fails:** Check your internet connection and that you are running Ubuntu 20.04/22.04.

---

## 👤 Author

Ali Talha – [LinkedIn](https://www.linkedin.com/in/imalitalha)

Build your own IDS lab – detect before you get hacked.

