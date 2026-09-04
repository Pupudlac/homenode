#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# ==============================================================================
set -euo pipefail

source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

log_info "=== Testing System Setup (01) ==="

# === 1) ZRAM Check ===
if [ "$ZRAM_ENABLED" = true ]; then
  if systemctl is-active --quiet homenode-zram.service; then
    # Zjistíme reálnou velikost běžícího ZRAMu
    ZRAM_SIZE_MB=$(zramctl --output DISKSIZE --bytes | tail -n 1 | awk '{print int($1/1024/1024)}')
    log_ok "ZRAM is active and persistent (Size: ${ZRAM_SIZE_MB}MB)"
  else
    log_err "ZRAM service (homenode-zram) is not active"
  fi
else
  log_info "ZRAM is disabled (ZRAM_ENABLED=false) – test skipped"
fi

# === 2) Disk SWAP Check ===
if [ "$SWAP_ENABLED" = true ]; then
  EXPECTED_SWAP_MB=$((SWAP_SIZE_GB * 1024))
  if [ -f "$SWAP_FILE" ]; then
    SWAP_SIZE_BYTES=$(stat -c %s "$SWAP_FILE" 2>/dev/null || echo 0)
    SWAP_SIZE_MB=$((SWAP_SIZE_BYTES / 1024 / 1024))
    if [ "$SWAP_SIZE_MB" -eq "$EXPECTED_SWAP_MB" ]; then
      log_ok "Disk SWAP size is ${SWAP_SIZE_MB}MB"
    else
      log_err "Disk SWAP has unexpected size: ${SWAP_SIZE_MB}MB (expected ${EXPECTED_SWAP_MB}MB)"
    fi
  else
    log_err "SWAP file (${SWAP_FILE}) does not exist"
  fi
else
  log_info "Disk SWAP is disabled (SWAP_ENABLED=false) – test skipped"
fi

# === 3) dnsutils (dig) ===
if command -v dig >/dev/null 2>&1; then
  log_ok "dnsutils (dig) is installed"
else
  log_err "dnsutils (dig) is not installed"
fi

# === 4) Cleanup script + cron ===
CLEANUP_SCRIPT="/usr/local/bin/system-cleanup.sh"
if [ -f "$CLEANUP_SCRIPT" ]; then
  log_ok "Cleanup script exists"
else
  log_err "Cleanup script is missing ($CLEANUP_SCRIPT)"
fi

crontab -l 2>/dev/null | grep -q "$CLEANUP_SCRIPT" && \
  log_ok "Cron job for cleanup exists" || \
  log_err "Cron job for cleanup not found"

# === 5) unattended-upgrades ===
dpkg -s unattended-upgrades >/dev/null 2>&1 && log_ok "unattended-upgrades package is installed" || log_err "unattended-upgrades package is not installed"

if systemctl is-enabled unattended-upgrades &>/dev/null; then
  if systemctl is-active unattended-upgrades &>/dev/null; then
    log_ok "unattended-upgrades service is active"
  else
    log_warn "unattended-upgrades service is installed but inactive"
  fi
else
  log_err "unattended-upgrades service is not enabled"
fi

log_info "=== System Setup Test Completed ==="