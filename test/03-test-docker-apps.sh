#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# ==============================================================================
set -euo pipefail

source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

log_info "=== Testing Docker Apps & Services (03) ==="

check_container() {
  NAME="$1"
  if docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${NAME}$"; then
      log_ok "Container ${NAME} is running"
    else
      log_err "Container ${NAME} is stopped"
    fi
  else
    log_info "Container ${NAME} is not installed – test skipped"
  fi
}

log_info "--- Docker Containers ---"
[ "$INSTALL_PORTAINER" = true ] && check_container "portainer"
[ "$INSTALL_PIHOLE" = true ] && check_container "pihole"
[ "$INSTALL_WIREGUARD" = true ] && check_container "wireguard"
[ "$INSTALL_WATCHTOWER" = true ] && check_container "watchtower"
[ "$INSTALL_UPTIMEKUMA" = true ] && check_container "uptime-kuma"

log_info "--- System Services ---"
if [ "$INSTALL_UNBOUND" = true ]; then
  if systemctl is-active --quiet unbound; then
    log_ok "Unbound is running"
  else
    log_err "Unbound is not running"
  fi
  
  log_info "--- DNS Resolver Test (Unbound) ---"
  DNS_OUT=$(dig @127.0.0.1 -p 5335 example.com +short)
  if [[ -n "$DNS_OUT" ]]; then
    log_ok "Unbound successfully answered the DNS query"
  else
    log_err "Unbound failed to answer the DNS query"
  fi
else
  log_info "Unbound is not installed – test skipped"
fi

log_info "=== Docker Apps Test Completed ==="