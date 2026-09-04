# 📖 Complete Guide to the HomeNode System

Welcome! This document will guide you step-by-step through the installation and use of the HomeNode system. You don't need to be an IT expert – just read carefully and follow the steps.

## 🚀 Quick Start (Express Installation)
Got a fresh Raspberry Pi OS Lite? Just paste this single command into your terminal (via SSH) and press Enter:

```bash
git clone https://github.com/Pupudlac/homenode.git && cd homenode && chmod +x install.sh && sudo ./install.sh
```

## 1. What is it and what is it for?
HomeNode is a fully automated installation package that transforms your mini-computer (Raspberry Pi) into an incredibly powerful, secure, and smart brain for your home.

**What the system automatically installs and configures:**
*   **Pi-hole (Ad Blocking):** Acts as a black hole for ads. It removes ads and tracking codes from all devices in your home (phones, computers, smart TVs) without needing to install anything on them.
*   **Unbound (Privacy):** A hidden shield that encrypts your website queries. Thanks to this, your Internet Service Provider cannot see which websites you visit.
*   **WireGuard (Personal VPN):** A secure "tunnel" to your home. When you are on a public Wi-Fi, you can securely connect home with one click on your phone. As a bonus, you get ad-free internet even on mobile data!
*   **Uptime Kuma (Monitoring):** A beautiful visual dashboard to monitor if your websites, routers, and services are online.
*   **Docker & Portainer:** Modern technology that allows all these applications to run in secure "containers". Portainer provides a graphical interface for managing them.
*   **Bulletproof Firewall:** The system automatically locks itself down against internet attacks.

## 2. Requirements before starting
1.  **A Raspberry Pi** connected to your home network (ideally via an Ethernet cable to the router).
2.  **A MicroSD card** (min. 16 GB) or NVMe/SSD drive.
3.  A computer with Windows, Mac, or Linux to prepare the card.
4.  **Public IP Address (Important):** For the personal VPN (WireGuard) to work from the outside, a public IPv4 address from your ISP is required. If you don't have one, you can still use the system for local ad-blocking (Pi-hole), but the VPN won't work outside your home.

## 3. STEP 1: Preparing the Memory Card (OS Installation)
For the Raspberry Pi to work, it needs an operating system. **This script is optimized for Debian 12 (Bookworm) and the newer Debian 13 (Trixie).**

1.  Download the official **Raspberry Pi Imager** from [raspberrypi.com](https://www.raspberrypi.com/software/).
2.  Insert the MicroSD card into your computer and launch the Imager.
3.  Choose the operating system: Select **Raspberry Pi OS Lite (64-bit)** (the Lite version without a desktop environment is ideal and fastest for this server).
4.  **IMPORTANT – Settings:** Before clicking the write button, click the gear icon (Edit Settings):
    *   Enable the **SSH** service (used for remote access).
    *   Set your **username and password** (remember them well!).
    *   Under localization, set the language to "en" (English) and the country to "US".
5.  Start writing. Once finished, insert the card into the Raspberry Pi and plug in the power.

## 4. STEP 2: First Connection to the Raspberry Pi
The Raspberry Pi runs without a monitor. We will connect to it remotely via a text console (SSH).
1.  Find the IP address of your Raspberry Pi (you can find it in your home Wi-Fi router's admin panel, usually looking like `192.168.1.x`).
2.  **Windows:** Download [PuTTY](https://www.putty.org/). In the *Host Name* field, enter the IP address, leave the port at `22`, and click Open. Enter your username and password (no asterisks will appear as you type).
3.  **Mac / Linux:** Open the Terminal and type `ssh your_username@ip_address`.

## 5. STEP 3: Installation

You have two options to install the system. We highly recommend the first (Express) method.

### Method A: Express Installation (One-Liner)
No more complicated file copying! Just copy this single command, paste it into the black window (PuTTY/Terminal), and press Enter:

```bash
git clone https://github.com/Pupudlac/homenode.git && cd homenode && chmod +x install.sh && sudo ./install.sh
```

### Method B: Local Installation (via WinSCP)
If you downloaded the files to your Windows computer and transferred them to the Raspberry Pi manually (e.g., via WinSCP) instead of using `git clone`, you must run these three commands before starting to remove invisible Windows characters:

```bash
# 1. Clean files from invisible Windows line endings
sed -i 's/\r$//' *.sh utils/*.sh test/*.sh 2>/dev/null || true

# 2. Make scripts executable
chmod +x *.sh utils/*.sh test/*.sh

# 3. Run the installer
sudo ./install.sh
```

---

A graphical wizard will pop up on your screen. We recommend choosing the **Express Installation**, which auto-detects everything. For Pi-hole, you can choose the blocking level (from a safe family mode to an aggressive Paranoia mode).

💡 **ATTENTION AFTER INSTALLATION:** Once the installer finishes, for security reasons, it will lock the default SSH port 22 and move it to port **2222**. The next time you connect to the Raspberry Pi, don't forget to change the port in PuTTY to 2222!

## 6. How do I access it? (Basic Access)
After a successful installation, the system will list all the addresses. Here is an overview (replace `IP_ADDRESS` with your Raspberry Pi's IP address):

*   **Pi-hole Web Administration (Ad-block):** `http://IP_ADDRESS:8080/admin`
    *   *For ad blocking to work on all devices in your home, you must find the DHCP settings in your Wi-Fi router and change the DNS server exactly to the IP address of this Raspberry Pi.*
*   **Portainer Container Management:** `http://IP_ADDRESS:9000`
    *   *(On the first launch, you will need the **Setup Token**. This long code was displayed in the terminal at the end of the installation. Copy and paste it into your browser to create your admin account.)*
*   **Uptime Kuma (Monitoring):** `http://IP_ADDRESS:3001`
    *   *(Here you can add monitors for your router or websites. To monitor your router, use the "Ping" monitor type.)*
*   **Remote Access via SSH:** `ssh your_username@IP_ADDRESS -p 2222`

## 7. Troubleshooting & Useful Commands

If you need to manage the system, connect via SSH (remember to use port 2222) and use these commands:

**Change Pi-hole Password:**
If you forget your Pi-hole web admin password, you can change it anytime with this command:
```bash
sudo docker exec pihole pihole setpassword "YOUR_NEW_PASSWORD"
```

**Portainer Timeout (Setup Token Expired):**
Portainer gives you exactly 5 minutes to log in for the first time. If you miss it, it locks itself. To generate a new token and restart the timer, type:
```bash
sudo docker restart portainer
sudo docker logs portainer
```
*(You will find the new Setup Token at the bottom of the log).*

**WireGuard Backup (Before Reinstalling):**
If you ever need to reinstall the system but want your phones to connect without scanning QR codes again, backup this folder:
`/home/your_username/docker/wireguard/`
After a clean install, just put the folder back and everything will work as before.

## 8. Emergency Brake (Uninstallation)
If something goes wrong or you don't like the system, you can revert everything to its original state. Connect via SSH and type:

```bash
cd homenode
sudo ./uninstall.sh
```

This script will delete all containers, disable the firewall, and revert the network to its original state.

Thank you for using HomeNode! Enjoy a secure, ad-free internet.