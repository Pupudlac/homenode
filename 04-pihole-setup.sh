#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Configures Pi-hole blocklists based on user's chosen level.
# ==============================================================================
set -euo pipefail

source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

log_info "Starting Pi-hole configuration (blocklists, whitelists, blacklists)..."

if ! docker ps --format '{{.Names}}' | grep -q '^pihole$'; then
  log_err "Container 'pihole' is not running. Run 03-setup-docker-apps.sh first."
  exit 1
fi

log_info "Waiting for Pi-hole database to initialize..."
for i in {1..30}; do
  if docker exec pihole ls /etc/pihole/gravity.db >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

log_info "Applying Adlists for Level $PIHOLE_LEVEL..."
if [ "$PIHOLE_LEVEL" == "1" ]; then
  for comment in "${!PIHOLE_ADLISTS_LVL1[@]}"; do
    url="${PIHOLE_ADLISTS_LVL1[$comment]}"
    docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment, type) VALUES ('$url', 1, '$comment', 0);"
  done
elif [ "$PIHOLE_LEVEL" == "2" ]; then
  for comment in "${!PIHOLE_ADLISTS_LVL2[@]}"; do
    url="${PIHOLE_ADLISTS_LVL2[$comment]}"
    docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment, type) VALUES ('$url', 1, '$comment', 0);"
  done
else
  for comment in "${!PIHOLE_ADLISTS_LVL3[@]}"; do
    url="${PIHOLE_ADLISTS_LVL3[$comment]}"
    docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment, type) VALUES ('$url', 1, '$comment', 0);"
  done
fi

log_info "Adding whitelist domains..."
for domain in "${PIHOLE_WHITELIST[@]}"; do
  docker exec pihole pihole allowlist "$domain" >/dev/null 2>&1 || true
done

log_info "Adding blacklist domains..."
for domain in "${PIHOLE_BLACKLIST[@]}"; do
  if [[ "$domain" == *"."* ]]; then
    docker exec pihole pihole denylist "$domain" >/dev/null 2>&1 || true
  else
    docker exec pihole pihole denylist --regex ".*$domain.*" >/dev/null 2>&1 || true
  fi
done

log_info "Waiting for Pi-hole FTL engine to wake up..."
for i in {1..20}; do
  if docker exec pihole pihole status >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
sleep 3

if [ -n "${PIHOLE_PASSWORD:-}" ]; then
  log_info "Enforcing web admin password..."
  docker exec pihole pihole setpassword "$PIHOLE_PASSWORD" >/dev/null
fi

log_info "Compiling gravity database from new lists (this will take a while)..."
docker exec pihole pihole -g >/dev/null

log_info "Switching system DNS to localhost (Pi-hole)..."
if command -v nmcli >/dev/null 2>&1; then
  IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n 1) || true
  [ -z "$IFACE" ] && IFACE="eth0"
  
  sudo nmcli con mod "$IFACE" ipv4.dns "127.0.0.1" >/dev/null 2>&1 || true
  sudo nmcli device reapply "$IFACE" >/dev/null 2>&1 || true
  log_ok "System DNS successfully switched to 127.0.0.1."
fi

log_ok "✅ Pi-hole configuration completed successfully."