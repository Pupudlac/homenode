#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# ==============================================================================
set -euo pipefail

source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

log_info "=== Testing Pi-hole Configuration (04) ==="

if [ "$INSTALL_PIHOLE" != true ]; then
  log_info "Pi-hole is not active – test skipped"
  exit 0
fi

if docker ps --format '{{.Names}}' | grep -q '^pihole$'; then
  log_ok "Pi-hole container is running"
else
  log_err "Pi-hole container is not running"
  exit 1
fi

log_info "Listing active adlists from gravity.db:"
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db "SELECT comment, address FROM adlist;" | head -n 5 | while IFS='|' read -r comment url; do
  echo -e "${GREEN}✓${NC} $comment → $url"
done
echo "  ... and more."

log_info "Testing DNS query through Pi-hole (port 53)..."
if dig @127.0.0.1 -p 53 example.com +short &>/dev/null; then
  log_ok "DNS query through Pi-hole OK"
else
  log_err "DNS query through Pi-hole FAILED"
fi

if [ "$INSTALL_UNBOUND" = true ]; then
  log_info "Testing DNS chain Pi-hole → Unbound (port 5335)..."
  if docker exec pihole dig @127.0.0.1 -p 5335 example.com +short &>/dev/null; then
    log_ok "DNS chain Pi-hole → Unbound successful"
  else
    log_err "DNS chain Pi-hole → Unbound FAILED"
  fi
fi

log_info "=== Pi-hole Test Completed ==="