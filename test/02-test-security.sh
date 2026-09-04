#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# ==============================================================================
set -euo pipefail

source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

log_info "=== Testing Security Setup (02) ==="

# === 1) nftables ===
if systemctl is-active --quiet nftables; then
  if sudo nft list ruleset &>/dev/null; then
    log_ok "nftables is running and rules are loaded"
  else
    log_err "nftables is active, but rules cannot be loaded"
  fi
else
  log_err "nftables is not active"
fi

# === 2) SSH ports ===
ss -tln | grep -q ":$SSH_PORT" && log_ok "SSH is listening on port $SSH_PORT" || log_err "SSH is NOT listening on port $SSH_PORT"
ss -tln | grep -q ':22 ' && log_warn "SSH port 22 is still listening (check LAN restrictions)" || log_ok "SSH port 22 is closed (which is OK)"

# === 3) Fail2Ban ===
if systemctl is-active --quiet fail2ban; then
  log_ok "Fail2Ban is running"
else
  log_err "Fail2Ban is not running"
fi

if fail2ban-client status sshd &>/dev/null; then
  log_ok "Fail2Ban jail 'sshd' is active"
else
  log_err "Fail2Ban jail 'sshd' not found or inactive"
fi

# === 4) WireGuard port ===
if [ "$INSTALL_WIREGUARD" = true ]; then
  ss -uln | grep -q ":$WG_PORT" && log_ok "WireGuard $WG_PORT/UDP is listening" || log_err "WireGuard port $WG_PORT/UDP is NOT listening"
else
  log_info "WireGuard is not active – test skipped"
fi

# === 5) DNS ports ===
ss -tln | grep -q ':53 ' && log_ok "DNS TCP 53 is listening" || log_err "DNS TCP 53 is NOT listening"
ss -uln | grep -q ':53 ' && log_ok "DNS UDP 53 is listening" || log_err "DNS UDP 53 is NOT listening"

log_info "=== Security Setup Test Completed ==="