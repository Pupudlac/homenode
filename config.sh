#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Main configuration file. Values are overwritten by install.sh.
# ==============================================================================

# --- Global Script Behavior ---
DRY_RUN=false
LANGUAGE="CZ"

# === User Credentials ===
USER_NAME="admin"
USER_HOME="/home/$USER_NAME"

# === Network & Access ===
LAN_SUBNET="192.168.1.0/24"
STATIC_IP="192.168.1.100"
PUBLIC_DDNS="myvpn.example.com"
SSH_PORT="2222"
WG_PORT="51820"

# === Localization ===
TIMEZONE="Europe/Prague"
DOMAIN_NAME="home.local"

# === Pi-hole Web Interface Password ===
PIHOLE_PASSWORD="changeme"

# === Storage & Performance ===
ZRAM_ENABLED=true
SWAP_ENABLED=true
SWAP_SIZE_GB=4
SWAP_FILE="/var/swap"

# === Container Selection ===
INSTALL_PIHOLE=true
INSTALL_UNBOUND=true
INSTALL_PORTAINER=true
INSTALL_WIREGUARD=true
INSTALL_WATCHTOWER=true
INSTALL_UPTIMEKUMA=true

# === Pi-hole Settings ===
# Blocking Level: 1 = Standard, 2 = Strict, 3 = Aggressive
PIHOLE_LEVEL=3

# 1. STANDARD (Safe, rarely breaks websites)
declare -A PIHOLE_ADLISTS_LVL1=(
  ["OISD - Basic Safe List"]="https://big.oisd.nl"
  ["StevenBlack - Standard"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
)

# 2. STRICT (Standard + Porn & Gambling)
declare -A PIHOLE_ADLISTS_LVL2=(
  ["OISD - Basic Safe List"]="https://big.oisd.nl"
  ["StevenBlack - Fakenews, Gambling, Porn"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
  ["Adult Content (Top 1M)"]="https://raw.githubusercontent.com/chadmayfield/my-pihole-blocklists/master/lists/pi_blocklist_porn_top1m.list"
)

# 3. AGGRESSIVE (Paranoia mode - might break some links)
declare -A PIHOLE_ADLISTS_LVL3=(
  ["OISD - Basic Safe List"]="https://big.oisd.nl"
  ["StevenBlack - Fakenews, Gambling, Porn"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
  ["Adult Content (Top 1M)"]="https://raw.githubusercontent.com/chadmayfield/my-pihole-blocklists/master/lists/pi_blocklist_porn_top1m.list"
  ["Ad lists (Firebog)"]="https://v.firebog.net/hosts/AdguardDNS.txt"
  ["AMP blocker"]="https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt"
  ["AI blogs, MFA sites, SEO farms"]="https://raw.githubusercontent.com/DandelionSprout/adfilt/master/AnnoyancesList"
)

# Whitelist (Common for all levels - prevents false positives)
PIHOLE_WHITELIST=(
  "di.fm"
  "bit.ly"
  "super.cz"
  "aukro.cz"
  "s.click.aliexpress.com"
  "heureka.cz"
)

# Blacklist (Common for all levels)
PIHOLE_BLACKLIST=(
  "tiktok.com"
  "amateri.cz"
  "amateri.com"
  "porn"
  "pornhubs.video"
  "pornhat.com"
  "onlyfans.com"
)