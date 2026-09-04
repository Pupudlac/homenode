#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Main interactive installation wizard.
# ==============================================================================
set -eo pipefail

# === Root Check ===
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[0;31m[ERROR]\033[0m This script must be run as root (use: sudo ./install.sh)"
  exit 1
fi

# === OS Check (Debian 12 Bookworm / Debian 13 Trixie) ===
OS_VERSION=$(grep -oP '(?<=^VERSION_CODENAME=).+' /etc/os-release || echo "unknown")
if [[ "$OS_VERSION" != "bookworm" && "$OS_VERSION" != "trixie" ]]; then
  echo -e "\033[0;31m[VAROVÁNÍ / WARNING]\033[0m"
  echo -e "Tento skript je optimalizován pro Debian 12 (Bookworm) a novější."
  echo -e "Váš systém je detekován jako: $OS_VERSION"
  echo -e "Pokračování může způsobit problémy se sítí (NetworkManager vs dhcpcd)."
  read -p "Chcete přesto pokračovat? / Continue anyway? (y/N): " confirm
  if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    exit 1
  fi
fi

# === Project Definitions ===
PROJECT_NAME="HomeNode"
LOG_FILE="/var/log/homenode-install.log"
CONFIG_FILE="./config.sh"

source ./utils/colors.sh

if ! command -v whiptail >/dev/null 2>&1; then
  echo -e "\033[1;33m[INFO]\033[0m Installing whiptail UI..."
  apt-get update >/dev/null && apt-get install -y whiptail curl >/dev/null
fi

# === LANGUAGE SELECTION ===
LANG_CHOICE=$(whiptail --title "Language / Jazyk" --menu "Choose your language / Vyberte jazyk:" 12 45 2 \
  "EN" "English" \
  "CZ" "Čeština" 3>&1 1>&2 2>&3)

if [ -z "$LANG_CHOICE" ]; then exit 0; fi

# === DICTIONARY / TRANSLATIONS ===
if [ "$LANG_CHOICE" = "EN" ]; then
  T_WELC_TIT="Welcome to $PROJECT_NAME"
  T_WELC_MSG="Welcome!\n\nThis wizard will turn your Raspberry Pi into a secure home server.\n\nLet's get started!"
  T_MODE_TIT="Installation Mode"
  T_MODE_MSG="Choose installation mode:"
  T_MODE_EXP="Express (Auto-detect everything - Recommended)"
  T_MODE_CUS="Custom (Manual configuration)"
  T_USR_TIT="System User"
  T_USR_MSG="Enter the main username for your system.\n(This user will own the Docker configuration files):"
  T_DOM_TIT="INTERNAL Network Domain"
  T_DOM_MSG="Enter the name of your INTERNAL network (e.g., home.local).\n(Do NOT enter your public domain here!):"
  T_IP_TIT="Static IP Address"
  T_IP_MSG="Enter the STATIC IP address for this server.\n(Crucial: The server must not change its IP, otherwise ad-blocking will stop working):"
  T_SUB_TIT="Network Subnet"
  T_SUB_MSG="Enter your local network subnet (e.g., 192.168.1.0/24).\n(The firewall needs this to allow traffic from your home devices):"
  T_PUB_TIT="PUBLIC IP / DDNS"
  T_PUB_MSG="Enter your PUBLIC IP or DDNS domain.\n(WARNING: If you don't have a public IP from your ISP, WireGuard VPN won't work from the outside. Other services will work fine):"
  T_SD_TIT="Storage Type"
  T_SD_MSG="Is this system running on a MicroSD card?\n(If YES, we will disable disk SWAP to protect the card from wearing out quickly)"
  T_APP_TIT="Select Apps"
  T_APP_MSG="Use SPACE to select apps, then press ENTER:"
  T_PWD_TIT="Pi-hole Password"
  T_PWD_MSG="Enter the password for Pi-hole web admin:\n(Empty field = 'changeme')"
  T_LVL_TIT="Pi-hole Blocking Level"
  T_LVL_MSG="Select the strictness of ad-blocking:"
  T_LVL_1="Standard (Basic protection, ideal for families)"
  T_LVL_2="Strict (Also blocks gambling and adult content)"
  T_LVL_3="Maximum (Paranoia mode - blocks telemetry and AI farms)"
  T_CANCEL="Installation cancelled."
  T_INST_TIT="Installing $PROJECT_NAME"
  T_INST_MSG="Initializing..."
  
  # Dynamic progress bar texts
  P_PH1="Updating system and configuring storage..."
  P_PH2="Building bulletproof firewall and security rules..."
  P_PH3="Downloading Docker and applications (this takes a while)..."
  P_PH4="Compiling hundreds of thousands of ad-block rules..."
  P_DONE="All phases completed! Running diagnostics..."
else
  T_WELC_TIT="Vítejte v instalátoru $PROJECT_NAME"
  T_WELC_MSG="Vítejte!\n\nTento průvodce z vašeho Raspberry Pi vytvoří bezpečné centrum pro vaši domácnost.\n\nJdeme na to!"
  T_MODE_TIT="Režim instalace"
  T_MODE_MSG="Vyberte režim instalace:"
  T_MODE_EXP="Expresní (Vše detekovat automaticky - Doporučeno)"
  T_MODE_CUS="Vlastní (Manuální nastavení sítě)"
  T_USR_TIT="Systémový uživatel"
  T_USR_MSG="Zadejte hlavní uživatelské jméno vašeho systému.\n(Tento uživatel bude vlastnit konfigurační soubory):"
  T_DOM_TIT="VNITŘNÍ doména sítě"
  T_DOM_MSG="Zadejte název vaší VNITŘNÍ sítě (např. home.local).\n(Vaše veřejná doména sem NEPATŘÍ!):"
  T_IP_TIT="Statická IP adresa"
  T_IP_MSG="Zadejte PEVNOU IP adresu pro tento server.\n(Kritické: Server nesmí měnit IP, jinak přestane fungovat blokování reklam):"
  T_SUB_TIT="Rozsah domácí sítě"
  T_SUB_MSG="Zadejte rozsah sítě pro firewall (např. 192.168.1.0/24).\n(Firewall to potřebuje, aby propustil vaše domácí zařízení):"
  T_PUB_TIT="VEŘEJNÁ IP / DDNS"
  T_PUB_MSG="Zadejte vaši VEŘEJNOU IP nebo DDNS doménu.\n(POZOR: Pokud nemáte od poskytovatele veřejnou IP, WireGuard VPN zvenčí nepojede. Ostatní služby ano):"
  T_SD_TIT="Typ úložiště"
  T_SD_MSG="Běží tento systém na MicroSD kartě?\n(Pokud ANO, vypneme diskový SWAP, abychom kartu ochránili před rychlým zničením)"
  T_APP_TIT="Výběr aplikací"
  T_APP_MSG="Pomocí MEZERNÍKU zaškrtněte aplikace a potvrďte ENTERem:"
  T_PWD_TIT="Heslo pro Pi-hole"
  T_PWD_MSG="Zadejte heslo pro administraci Pi-hole:\n(Prázdné pole = 'changeme')"
  T_LVL_TIT="Úroveň blokování Pi-hole"
  T_LVL_MSG="Vyberte přísnost blokování reklam:"
  T_LVL_1="Standardní (Základní ochrana, ideální pro rodiny)"
  T_LVL_2="Zvýšená (Blokuje navíc hazard a obsah pro dospělé)"
  T_LVL_3="Maximální (Paranoia mód - blokuje i telemetrii a AI farmy)"
  T_CANCEL="Instalace zrušena."
  T_INST_TIT="Instalace $PROJECT_NAME"
  T_INST_MSG="Inicializace instalačního procesu..."
  
  # Dynamické texty pro lištu
  P_PH1="Aktualizuji systém a nastavuji úložiště..."
  P_PH2="Stavím neprůstřelný firewall a bezpečnostní pravidla..."
  P_PH3="Stahuji Docker a aplikace (tohle chvíli potrvá)..."
  P_PH4="Kompiluji statisíce blokovacích pravidel pro Pi-hole..."
  P_DONE="Všechny fáze dokončeny! Spouštím diagnostiku..."
fi

# === AUTO-DETECTION ===
DETECTED_IP=$(hostname -I | awk '{print $1}')
if [ -z "$DETECTED_IP" ]; then DETECTED_IP="192.168.1.100"; fi
DETECTED_SUBNET=$(echo "$DETECTED_IP" | cut -d. -f1-3).0/24
DETECTED_USER="${SUDO_USER:-$(whoami)}"
if [ "$DETECTED_USER" = "root" ]; then DETECTED_USER="admin"; fi

if command -v curl >/dev/null 2>&1; then
  DETECTED_PUB_IP=$(curl -s --max-time 3 ifconfig.me || echo "myvpn.example.com")
else
  DETECTED_PUB_IP="myvpn.example.com"
fi

# === WIZARD ===
whiptail --title "$T_WELC_TIT" --msgbox "$T_WELC_MSG" 10 60

INSTALL_MODE=$(whiptail --title "$T_MODE_TIT" --menu "$T_MODE_MSG" 12 65 2 \
  "EXPRESS" "$T_MODE_EXP" \
  "CUSTOM" "$T_MODE_CUS" 3>&1 1>&2 2>&3)
if [ -z "$INSTALL_MODE" ]; then echo "$T_CANCEL"; exit 0; fi

if [ "$INSTALL_MODE" = "EXPRESS" ]; then
  NEW_USER="$DETECTED_USER"
  NEW_DOMAIN="home.local"
  NEW_IP="$DETECTED_IP"
  NEW_SUBNET="$DETECTED_SUBNET"
  NEW_PUB="$DETECTED_PUB_IP"
else
  NEW_USER=$(whiptail --title "$T_USR_TIT" --inputbox "$T_USR_MSG" 11 65 "$DETECTED_USER" 3>&1 1>&2 2>&3)
  if [ -z "$NEW_USER" ]; then echo "$T_CANCEL"; exit 0; fi

  NEW_DOMAIN=$(whiptail --title "$T_DOM_TIT" --inputbox "$T_DOM_MSG" 11 65 "home.local" 3>&1 1>&2 2>&3)
  if [ -z "$NEW_DOMAIN" ]; then echo "$T_CANCEL"; exit 0; fi

  NEW_IP=$(whiptail --title "$T_IP_TIT" --inputbox "$T_IP_MSG" 12 65 "$DETECTED_IP" 3>&1 1>&2 2>&3)
  if [ -z "$NEW_IP" ]; then echo "$T_CANCEL"; exit 0; fi

  NEW_SUBNET=$(whiptail --title "$T_SUB_TIT" --inputbox "$T_SUB_MSG" 11 65 "$DETECTED_SUBNET" 3>&1 1>&2 2>&3)
  if [ -z "$NEW_SUBNET" ]; then echo "$T_CANCEL"; exit 0; fi
  
  NEW_PUB=$(whiptail --title "$T_PUB_TIT" --inputbox "$T_PUB_MSG" 11 65 "$DETECTED_PUB_IP" 3>&1 1>&2 2>&3)
  if [ -z "$NEW_PUB" ]; then echo "$T_CANCEL"; exit 0; fi
fi

# SD Card Check
if whiptail --title "$T_SD_TIT" --yesno "$T_SD_MSG" 11 65; then
  NEW_SWAP="false"
else
  NEW_SWAP="true"
fi

CHOICES=$(whiptail --title "$T_APP_TIT" --checklist "$T_APP_MSG" 20 78 7 \
  "PIHOLE" "Pi-hole (Ad-block / DNS)" ON \
  "UNBOUND" "Unbound (Private DNS Resolver)" ON \
  "PORTAINER" "Portainer (Docker Web UI)" ON \
  "WIREGUARD" "WireGuard (VPN Server)" ON \
  "WATCHTOWER" "Watchtower (Auto-updates)" ON \
  "UPTIMEKUMA" "Uptime Kuma (Monitoring)" ON \
  3>&1 1>&2 2>&3)
if [ -z "$CHOICES" ]; then echo "$T_CANCEL"; exit 0; fi

PIHOLE_PWD="changeme"
PIHOLE_LVL="1"
if [[ $CHOICES == *"PIHOLE"* ]]; then
  PIHOLE_PWD=$(whiptail --title "$T_PWD_TIT" --passwordbox "$T_PWD_MSG" 10 60 3>&1 1>&2 2>&3)
  if [ -z "$PIHOLE_PWD" ]; then PIHOLE_PWD="changeme"; fi
  
  PIHOLE_LVL=$(whiptail --title "$T_LVL_TIT" --menu "$T_LVL_MSG" 12 75 3 \
    "1" "$T_LVL_1" \
    "2" "$T_LVL_2" \
    "3" "$T_LVL_3" 3>&1 1>&2 2>&3)
  if [ -z "$PIHOLE_LVL" ]; then PIHOLE_LVL="1"; fi
fi

# === Write to config.sh ===
sed -i "s|^USER_NAME=.*|USER_NAME=\"$NEW_USER\"|" "$CONFIG_FILE"
sed -i "s|^DOMAIN_NAME=.*|DOMAIN_NAME=\"$NEW_DOMAIN\"|" "$CONFIG_FILE"
sed -i "s|^LAN_SUBNET=.*|LAN_SUBNET=\"$NEW_SUBNET\"|" "$CONFIG_FILE"
sed -i "s|^STATIC_IP=.*|STATIC_IP=\"$NEW_IP\"|" "$CONFIG_FILE"
sed -i "s|^PUBLIC_DDNS=.*|PUBLIC_DDNS=\"$NEW_PUB\"|" "$CONFIG_FILE"
sed -i "s|^SWAP_ENABLED=.*|SWAP_ENABLED=$NEW_SWAP|" "$CONFIG_FILE"
sed -i "s|^PIHOLE_PASSWORD=.*|PIHOLE_PASSWORD=\"$PIHOLE_PWD\"|" "$CONFIG_FILE"
sed -i "s|^PIHOLE_LEVEL=.*|PIHOLE_LEVEL=$PIHOLE_LVL|" "$CONFIG_FILE"

set_config() { local key=$1; local val=$2; sed -i "s/^$key=.*/$key=$val/" "$CONFIG_FILE"; }
for app in INSTALL_PIHOLE INSTALL_UNBOUND INSTALL_PORTAINER INSTALL_WIREGUARD INSTALL_WATCHTOWER INSTALL_UPTIMEKUMA; do set_config "$app" "false"; done
if ! grep -q "^LANGUAGE=" "$CONFIG_FILE"; then echo "LANGUAGE=\"$LANG_CHOICE\"" >> "$CONFIG_FILE"; else sed -i "s|^LANGUAGE=.*|LANGUAGE=\"$LANG_CHOICE\"|" "$CONFIG_FILE"; fi

[[ $CHOICES == *"PIHOLE"* ]] && set_config "INSTALL_PIHOLE" "true"
[[ $CHOICES == *"UNBOUND"* ]] && set_config "INSTALL_UNBOUND" "true"
[[ $CHOICES == *"PORTAINER"* ]] && set_config "INSTALL_PORTAINER" "true"
[[ $CHOICES == *"WIREGUARD"* ]] && set_config "INSTALL_WIREGUARD" "true"
[[ $CHOICES == *"WATCHTOWER"* ]] && set_config "INSTALL_WATCHTOWER" "true"
[[ $CHOICES == *"UPTIMEKUMA"* ]] && set_config "INSTALL_UPTIMEKUMA" "true"

# === INSTALLATION WITH DYNAMIC PROGRESS BAR ===
chmod +x ./*.sh ./utils/*.sh >/dev/null 2>&1 || true
> "$LOG_FILE"

{
  export DEBIAN_FRONTEND=noninteractive
  
  echo "XXX"; echo "10"; echo "$P_PH1"; echo "XXX"
  ./01-setup-initial-system.sh >> "$LOG_FILE" 2>&1
  
  echo "XXX"; echo "40"; echo "$P_PH2"; echo "XXX"
  ./02-setup-security.sh >> "$LOG_FILE" 2>&1
  
  echo "XXX"; echo "70"; echo "$P_PH3"; echo "XXX"
  ./03-setup-docker-apps.sh >> "$LOG_FILE" 2>&1
  
  if [[ $CHOICES == *"PIHOLE"* ]]; then
    echo "XXX"; echo "90"; echo "$P_PH4"; echo "XXX"
    ./04-pihole-setup.sh >> "$LOG_FILE" 2>&1
  fi

  echo "XXX"; echo "100"; echo "$P_DONE"; echo "XXX"
  sleep 2
} | whiptail --title "$T_INST_TIT" --gauge "$T_INST_MSG" 10 75 0

# === RUN DIAGNOSTICS ===
clear
chmod +x ./test.sh ./test/*.sh 2>/dev/null || true
./test.sh