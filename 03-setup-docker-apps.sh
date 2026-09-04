#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Installs and configures Docker containers (Pi-hole, WG, etc.).
# ==============================================================================
set -euo pipefail

source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

if [ "$(id -u)" -eq 0 ]; then
  if [ -n "${SUDO_USER-}" ]; then
    USER="$SUDO_USER"
    HOME=$(eval echo "~$SUDO_USER")
  else
    USER="root"
    HOME="/root"
  fi
else
  USER=$(whoami)
  HOME=$(eval echo "~$USER")
fi

log_info "Current user: $USER"
log_info "Home directory: $HOME"

if ! command -v docker >/dev/null 2>&1; then
  log_info "Docker is not installed. Downloading and installing..."
  if ! command -v curl >/dev/null 2>&1; then
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y curl >/dev/null 2>&1
  fi
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh >/dev/null 2>&1
  rm get-docker.sh
  sudo usermod -aG docker "$USER"
  
  log_info "Waiting for Docker daemon to wake up..."
  for i in {1..15}; do
    if docker info >/dev/null 2>&1; then break; fi
    sleep 2
  done
  log_ok "Docker was successfully installed."
else
  log_ok "Docker is already installed."
fi

log_info "Configuring Docker log rotation..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker

if ! docker compose version >/dev/null 2>&1; then
  sudo apt-get update >/dev/null 2>&1
  sudo apt-get install -y docker-compose-plugin >/dev/null 2>&1
fi

if [ "$INSTALL_UNBOUND" = true ]; then
  PIHOLE_DNS="127.0.0.1#5335"
else
  PIHOLE_DNS="9.9.9.9;149.112.112.112"
fi
log_info "Upstream DNS for Pi-hole set to: $PIHOLE_DNS"

# --- Portainer ---
if [ "$INSTALL_PORTAINER" = true ]; then
  mkdir -p "$HOME/docker/portainer"
  chown -R "$USER:$USER" "$HOME/docker/portainer"
  chmod 755 "$HOME/docker/portainer"

  if ! docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
    log_info "Starting Portainer..."
    docker pull portainer/portainer-ce:latest
    docker run -d -p 9000:9000 --name=portainer --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$HOME/docker/portainer:/data" \
      portainer/portainer-ce:latest
  else
    if ! docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
      docker start portainer
    fi
  fi
fi

# --- Unbound ---
if [ "$INSTALL_UNBOUND" = true ]; then
  if ! command -v unbound > /dev/null 2>&1; then
    log_info "Installing Unbound on host..."
    sudo apt update
    sudo apt install -y unbound
  fi

  UNBOUND_CONF="/etc/unbound/unbound.conf.d/pi-hole.conf"
  log_info "Creating/Updating Unbound configuration for Pi-hole..."
  sudo mkdir -p /etc/unbound/unbound.conf.d
  sudo tee "$UNBOUND_CONF" > /dev/null <<EOF
server:
  verbosity: 0
  interface: 127.0.0.1
  access-control: 127.0.0.0/8 allow
  port: 5335
  do-ip4: yes
  do-udp: yes
  do-tcp: yes
  do-ip6: no
  prefer-ip6: no
  harden-glue: yes
  harden-dnssec-stripped: yes
  root-hints: "/var/lib/unbound/root.hints"
  hide-identity: yes
  hide-version: yes
  use-caps-for-id: no
  qname-minimisation: yes
  aggressive-nsec: yes
  val-clean-additional: yes
  tcp-idle-timeout: 10000
EOF

  if [ ! -f "/var/lib/unbound/root.hints" ]; then
    log_info "Downloading root hints for Unbound..."
    sudo curl -sS -L --retry 3 -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache || true
  fi

  sudo systemctl disable --now unbound-resolvconf.service >/dev/null 2>&1 || true
  [ -f /etc/resolvconf.conf ] && sudo sed -Ei 's/^unbound_conf=/#unbound_conf=/' /etc/resolvconf.conf
  sudo rm -f /etc/unbound/unbound.conf.d/resolvconf_resolvers.conf || true

  sudo systemctl enable unbound
  sudo systemctl restart unbound
fi

# --- Pi-hole ---
if [ "$INSTALL_PIHOLE" = true ]; then
  mkdir -p "$HOME/docker/pihole/etc-pihole"
  chown -R "$USER:$USER" "$HOME/docker/pihole"
  chmod -R 755 "$HOME/docker/pihole"

  PIHOLE_DIR="$HOME/docker/pihole"
  COMPOSE_FILE="$PIHOLE_DIR/docker-compose.yml"
  log_info "Creating/Updating docker-compose.yml for Pi-hole..."
  cat > "$COMPOSE_FILE" <<EOF
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    network_mode: "host"
    shm_size: '256mb'
    environment:
      TZ: '$TIMEZONE'
      FTLCONF_dns_upstreams: '${PIHOLE_DNS}'
      FTLCONF_dns_listeningMode: 'ALL'
      FTLCONF_dns_rateLimit_count: '5000'
      FTLCONF_webserver_port: '8080'
      FTLCONF_dns_domain_name: '${DOMAIN_NAME}'
      FTLCONF_dns_revServers: 'true,${LAN_SUBNET},${STATIC_IP%.*}.1,${DOMAIN_NAME}'
    volumes:
      - './etc-pihole:/etc/pihole'
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
EOF

  cd "$PIHOLE_DIR"
  docker compose up -d
fi

# --- WireGuard ---
if [ "$INSTALL_WIREGUARD" = true ]; then
  mkdir -p "$HOME/docker/wireguard"
  chown -R "$USER:$USER" "$HOME/docker/wireguard"

  docker rm -f wireguard 2>/dev/null || true
  
  log_info "Starting WireGuard..."
  docker run -d \
    --name=wireguard \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_MODULE \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ=$TIMEZONE \
    -e SERVERURL=$PUBLIC_DDNS \
    -e SERVERPORT=$WG_PORT \
    -e PEERS=20 \
    -e PEERDNS=$STATIC_IP \
    -e INTERNAL_SUBNET=10.13.13.0 \
    -e ALLOWEDIPS="0.0.0.0/0, $LAN_SUBNET" \
    -p $WG_PORT:$WG_PORT/udp \
    -v "$HOME/docker/wireguard:/config" \
    -v /lib/modules:/lib/modules \
    --restart unless-stopped \
    lscr.io/linuxserver/wireguard
fi

# --- Watchtower ---
if [ "$INSTALL_WATCHTOWER" = true ]; then
  mkdir -p "$HOME/docker/watchtower"
  docker rm -f watchtower 2>/dev/null || true
  log_info "Starting Watchtower..."
  docker run -d --name watchtower -e DOCKER_API_VERSION=1.40 --restart unless-stopped -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --cleanup --interval 43200
fi

# --- Uptime Kuma ---
if [ "$INSTALL_UPTIMEKUMA" = true ]; then
  mkdir -p "$HOME/docker/uptimekuma"
  chown -R "$USER:$USER" "$HOME/docker/uptimekuma"
  chmod -R 777 "$HOME/docker/uptimekuma"
  if ! docker ps -a --format '{{.Names}}' | grep -q '^uptime-kuma$'; then
    log_info "Starting Uptime Kuma..."
    docker run -d --name uptime-kuma --restart unless-stopped -p 3001:3001 -v "$HOME/docker/uptimekuma:/app/data" louislam/uptime-kuma:1
  fi
fi

log_info "=== Docker Apps Setup Completed ==="