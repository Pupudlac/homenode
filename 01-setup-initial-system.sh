#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Initial OS setup (Network, ZRAM, SWAP, Updates, Cleanup).
# ==============================================================================
set -euo pipefail

# === SILENCE INTERACTIVE PROMPTS ===
export DEBIAN_FRONTEND=noninteractive

# === Load shared files ===
source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

log_info "=== Starting initial system setup (01) ==="

# === Static IP Setup (NetworkManager for Debian 12) ===
log_info "Applying static IP address ($STATIC_IP) via NetworkManager..."
if command -v nmcli >/dev/null 2>&1; then
  # Dynamically detect the active network interface (e.g., eth0, ens3, enp1s0)
  IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n 1)
  [ -z "$IFACE" ] && IFACE="eth0" # Fallback to eth0 if detection fails
  
  log_info "Recreating NetworkManager profile for $IFACE..."
  sudo nmcli connection delete "Wired connection 1" >/dev/null 2>&1 || true
  sudo nmcli connection delete "$IFACE" >/dev/null 2>&1 || true
  
  sudo nmcli connection add type ethernet ifname "$IFACE" con-name "$IFACE" ipv4.method manual ipv4.addresses "$STATIC_IP/24" ipv4.gateway "${STATIC_IP%.*}.1" ipv4.dns "8.8.8.8"
  sudo nmcli connection up "$IFACE" >/dev/null 2>&1 || true
  log_ok "Static IP configured on $IFACE with temporary DNS (8.8.8.8)."
else
  log_warn "NetworkManager (nmcli) not found. Please set static IP in your router."
fi

# === System Update ===
log_info "Updating system packages..."
# Force default config options to prevent interactive prompts during upgrade
sudo apt update && sudo apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" && log_ok "System updated." || log_err "Update failed."

# === ZRAM Configuration ===
if [ "$ZRAM_ENABLED" = true ]; then
  log_info "Configuring ZRAM (Auto-sizing to 50% of RAM)..."
  
  if dpkg -s zram-tools >/dev/null 2>&1; then
    sudo systemctl stop zramswap >/dev/null 2>&1 || true
    sudo apt-get purge -y zram-tools >/dev/null 2>&1 || true
  fi
  sudo swapoff /dev/zram0 >/dev/null 2>&1 || true
  sudo rmmod zram >/dev/null 2>&1 || true

  TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
  ZRAM_SIZE_MB=$(awk "BEGIN {printf \"%d\", $TOTAL_RAM_MB / 2}")
  ZRAM_SIZE_BYTES=$(awk "BEGIN {printf \"%d\", $ZRAM_SIZE_MB * 1024 * 1024}")
  
  sudo tee /usr/local/bin/homenode-zram.sh > /dev/null <<EOF
#!/bin/bash
modprobe zram
echo lz4 > /sys/block/zram0/comp_algorithm
echo $ZRAM_SIZE_BYTES > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon /dev/zram0 -p 100
EOF
  sudo chmod +x /usr/local/bin/homenode-zram.sh

  sudo tee /usr/local/bin/homenode-zram-stop.sh > /dev/null <<EOF
#!/bin/bash
swapoff /dev/zram0
echo 1 > /sys/block/zram0/reset
EOF
  sudo chmod +x /usr/local/bin/homenode-zram-stop.sh

  sudo tee /etc/systemd/system/homenode-zram.service > /dev/null <<EOF
[Unit]
Description=HomeNode ZRAM Swap
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/homenode-zram.sh
ExecStop=/usr/local/bin/homenode-zram-stop.sh

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable homenode-zram.service >/dev/null 2>&1
  sudo systemctl restart homenode-zram.service
  
  log_ok "ZRAM configured and activated (${ZRAM_SIZE_MB} MB Persistent)."
else
  log_info "ZRAM is disabled in config.sh. Skipping."
fi

# === Disk SWAP Configuration ===
if [ "$SWAP_ENABLED" = true ]; then
  log_info "Checking disk SWAP status..."
  if ! swapon --summary | grep -q "$SWAP_FILE"; then
    log_info "SWAP not active. Setting to ${SWAP_SIZE_GB} GB..."
    sudo fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE"
    sudo chmod 600 "$SWAP_FILE"
    sudo mkswap "$SWAP_FILE"
    sudo swapon "$SWAP_FILE"
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
      echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab
    fi
    log_ok "Disk SWAP activated (${SWAP_SIZE_GB} GB)."
  else
    log_ok "Disk SWAP is already active."
  fi
else
  log_info "Disk SWAP is disabled (SD Card protection). Skipping."
fi

# === Essential Tools ===
log_info "Installing essential tools (dnsutils)..."
sudo apt install -y dnsutils && log_ok "Tools installed." || log_err "Tools installation failed."

# === SSD TRIM Optimization ===
log_info "Enabling SSD TRIM timer for disk health..."
sudo systemctl enable --now fstrim.timer >/dev/null 2>&1 || true
log_ok "SSD TRIM enabled."

# === Cleanup Script ===
CLEANUP_SCRIPT="/usr/local/bin/system-cleanup.sh"
log_info "Installing cleanup script to $CLEANUP_SCRIPT..."
sudo tee "$CLEANUP_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sudo apt autoremove -y
sudo apt autoclean
sudo journalctl --vacuum-time=7d
EOF
sudo chmod +x "$CLEANUP_SCRIPT"
log_ok "Cleanup script created."

# === Cron for Cleanup (1st Sunday of the month at 3:00 AM) ===
log_info "Scheduling cron job for cleanup..."
(crontab -l 2>/dev/null || true; echo "0 3 * * 0 [ \$(date +\%d) -le 7 ] && $CLEANUP_SCRIPT") | crontab -
log_ok "Cron job for cleanup scheduled."

# === Unattended-upgrades ===
log_info "Installing and configuring unattended-upgrades..."
sudo apt install -y unattended-upgrades apt-listchanges

AUTO_UPGRADES_CONF="/etc/apt/apt.conf.d/20auto-upgrades"
sudo tee "$AUTO_UPGRADES_CONF" > /dev/null <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

UNATTENDED_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"
sudo sed -i '/^Unattended-Upgrade::Origins-Pattern {/,/^};/d' "$UNATTENDED_CONF"

distro_codename=$(source /etc/os-release && echo "$VERSION_CODENAME")

sudo tee -a "$UNATTENDED_CONF" > /dev/null <<EOF
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
    "origin=Raspberry Pi Foundation,label=Raspberry Pi Foundation";
};
EOF

# === NTP Fallback ===
log_info "Configuring NTP fallback IP addresses..."
sudo sed -i 's/^#*FallbackNTP=.*/FallbackNTP=216.239.35.0 216.239.35.4/' /etc/systemd/timesyncd.conf
sudo systemctl restart systemd-timesyncd >/dev/null 2>&1 || true
log_ok "NTP fallback configured (Google Time IPs)."

log_ok "Unattended-upgrades configured."

log_info "=== Initial system setup completed ==="