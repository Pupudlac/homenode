#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Emergency Rollback Script. Removes Docker, resets Network & SSH.
# ==============================================================================
set -eo pipefail

if [ "$EUID" -ne 0 ]; then
  echo -e "\033[0;31m[ERROR]\033[0m This script must be run as root (use: sudo ./uninstall.sh)"
  exit 1
fi

source ./utils/colors.sh
source ./config.sh

echo -e "${RED}=====================================================================${NC}"
echo -e "${RED}                      ⚠️ EMERGENCY UNINSTALL ⚠️                      ${NC}"
echo -e "${RED}=====================================================================${NC}"
echo -e "This script will:"
echo -e "1. Stop and remove all HomeNode Docker containers."
echo -e "2. Delete all container data in $USER_HOME/docker."
echo -e "3. Disable the nftables firewall and Fail2Ban."
echo -e "4. Revert SSH port back to 22."
echo -e "5. Revert NetworkManager to automatic DHCP (removes static IP)."
echo -e "${YELLOW}WARNING: If you are connected via SSH, you might be disconnected when the network resets!${NC}\n"

read -p "Are you absolutely sure you want to proceed? (Type 'YES' to confirm): " confirm
if [ "$confirm" != "YES" ]; then
  echo "Uninstall cancelled."
  exit 0
fi

log_info "Stopping and removing Docker containers..."
docker rm -f pihole portainer wireguard watchtower uptime-kuma 2>/dev/null || true

log_info "Removing Docker data directories..."
rm -rf "$USER_HOME/docker"

log_info "Disabling Firewall (nftables) and Fail2Ban..."
systemctl disable --now fail2ban 2>/dev/null || true
nft flush ruleset 2>/dev/null || true
systemctl disable --now nftables 2>/dev/null || true

log_info "Reverting SSH port to 22..."
sed -i "s/^Port $SSH_PORT/Port 22/" /etc/ssh/sshd_config 2>/dev/null || true
systemctl disable --now ssh.service 2>/dev/null || true
systemctl enable --now ssh.socket 2>/dev/null || true
systemctl restart ssh 2>/dev/null || true

log_info "Reverting NetworkManager to DHCP (Auto) and resetting DNS..."
if command -v nmcli >/dev/null 2>&1; then
  CON_NAME=$(nmcli -t -f NAME,DEVICE connection show --active | grep -E 'eth0|enp|Wired' | head -n 1 | cut -d: -f1)
  if [ -n "$CON_NAME" ]; then
    # Vrátíme DHCP a nastavíme záchranné DNS (Google), aby systém neoslepl
    nmcli con mod "$CON_NAME" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns "8.8.8.8"
    nmcli device reapply "$CON_NAME" >/dev/null 2>&1 || true
    log_ok "Network reverted to DHCP and DNS reset to 8.8.8.8."
  fi
fi

echo -e "\n${GREEN}Uninstall complete. It is highly recommended to reboot the system now: sudo reboot${NC}"