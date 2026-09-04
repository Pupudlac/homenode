#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Security setup (nftables firewall, Fail2Ban, SSH hardening).
# ==============================================================================
set -euo pipefail

source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

log_info "=== Starting security setup (02) ==="

# === 1. Install nftables ===
if ! command -v nft >/dev/null 2>&1; then
  log_info "Installing nftables (firewall)..."
  run sudo apt install -y nftables
fi
log_ok "nftables installed, waiting for configuration."

# === 2. Firewall Rules ===
NFT_FILE="/etc/nftables.conf"
log_info "Generating firewall configuration: $NFT_FILE"

[ -f "$NFT_FILE" ] && sudo cp "$NFT_FILE" "${NFT_FILE}.bak"

sudo tee "$NFT_FILE" > /dev/null <<EOF
#!/usr/sbin/nft -f

table inet filter
delete table inet filter

table inet filter {
  set allowed_lan_ips {
    type ipv4_addr
    flags interval
    elements = { $LAN_SUBNET, 172.16.0.0/12, 10.13.13.0/24 }
  }

  chain input {
    type filter hook input priority 0; policy drop;

    # === Allow localhost (loopback) ===
    iif "lo" accept

    # === Established connections ===
    ct state established,related accept
    ct state invalid drop

    # === Allow LAN and Docker networks ===
    ip saddr @allowed_lan_ips accept

    # === ICMP (ping) ===
    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept

    # === SSH from internet (port $SSH_PORT) - rate limit ===
    tcp dport $SSH_PORT limit rate 3/minute accept
    tcp dport $SSH_PORT log prefix "nft-ssh-drop: " drop

    # === WireGuard (UDP $WG_PORT) ===
    udp dport $WG_PORT accept

    # === Drop broadcasts silently to prevent log spam ===
    ip daddr 224.0.0.0/4 drop
    ip daddr 255.255.255.255 drop

    # === Log and drop everything else ===
    log prefix "nft-default-drop: " drop
  }
}
EOF

if sudo nft list ruleset >/dev/null 2>&1 && diff -q "$NFT_FILE" <(sudo nft list ruleset) >/dev/null 2>&1; then
  log_ok "Firewall rules are already up to date. Skipping restart."
else
  log_info "Applying new firewall rules..."
  run sudo systemctl enable nftables
  run sudo systemctl start nftables
  run sudo nft -f "$NFT_FILE"
  log_ok "Firewall successfully configured and reloaded."
fi

# === 3. Fail2Ban ===
if ! dpkg -s fail2ban >/dev/null 2>&1; then
  log_info "Installing Fail2Ban..."
  run sudo apt install -y fail2ban
  log_ok "Fail2Ban installed."
else
  log_ok "Fail2Ban is already installed."
fi

run sudo systemctl enable fail2ban
run sudo systemctl start fail2ban

# === 4. SSH Jail for Fail2Ban ===
log_info "Adding standard jail configuration for SSH (port $SSH_PORT)..."
JAIL_FILE="/etc/fail2ban/jail.d/sshd.local"
sudo tee "$JAIL_FILE" > /dev/null <<EOF
[sshd]
enabled = true
port    = $SSH_PORT
backend = systemd
banaction = nftables-multiport
maxretry = 3
findtime = 600
bantime  = 3600
EOF

run sudo systemctl restart fail2ban
log_ok "Fail2Ban jail for SSH port $SSH_PORT is active."

# === 5. Change Default SSH Port (Aggressive Fix for Debian 12) ===
log_info "Checking SSH port configuration..."

if ss -tln | grep -q ":$SSH_PORT "; then
  log_ok "SSH is already listening on port $SSH_PORT. Skipping reconfiguration."
else
  log_info "Changing default SSH port to $SSH_PORT and killing port 22..."

  run sudo systemctl stop ssh.socket >/dev/null 2>&1 || true
  run sudo systemctl disable ssh.socket >/dev/null 2>&1 || true
  run sudo systemctl mask ssh.socket >/dev/null 2>&1 || true

  SSH_CONF="/etc/ssh/sshd_config"
  [ -f "$SSH_CONF" ] && sudo cp "$SSH_CONF" "${SSH_CONF}.bak"

  if grep -q "^Port " "$SSH_CONF"; then
    sudo sed -i "s/^Port .*/Port $SSH_PORT/" "$SSH_CONF"
  elif grep -q "^#Port " "$SSH_CONF"; then
    sudo sed -i "s/^#Port .*/Port $SSH_PORT/" "$SSH_CONF"
  else
    echo "Port $SSH_PORT" | sudo tee -a "$SSH_CONF" >/dev/null
  fi

  sudo mkdir -p /etc/ssh/sshd_config.d
  echo "Port $SSH_PORT" | sudo tee /etc/ssh/sshd_config.d/custom_port.conf >/dev/null

  run sudo systemctl enable ssh.service >/dev/null 2>&1 || true
  run sudo systemctl restart ssh.service

  log_ok "SSH is now listening ONLY on port $SSH_PORT."
fi

log_info "=== Security setup completed ==="