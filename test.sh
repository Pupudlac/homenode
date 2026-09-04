#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Master test script and final dashboard generator.
# ==============================================================================
set -eo pipefail

source ./utils/colors.sh
source ./utils/functions.sh
source ./config.sh

chmod +x ./test/01-test-*.sh ./test/02-test-*.sh ./test/03-test-*.sh ./test/04-test-*.sh 2>/dev/null || true

clear
echo -e "${CYAN}=====================================================================${NC}"
if [ "${LANGUAGE:-CZ}" = "EN" ]; then
  echo -e "${CYAN}                 RUNNING COMPREHENSIVE SYSTEM DIAGNOSTICS            ${NC}"
else
  echo -e "${CYAN}                 SPOUŠTÍM KOMPLEXNÍ DIAGNOSTIKU SYSTÉMU              ${NC}"
fi
echo -e "${CYAN}=====================================================================${NC}\n"

./test/01-test-initial-system.sh
./test/02-test-security.sh
./test/03-test-docker-apps.sh

if [ "$INSTALL_PIHOLE" = true ]; then
  ./test/04-test-pihole.sh
fi

# === FETCH PORTAINER TOKEN (BULLETPROOF METHOD V2) ===
PORTAINER_TOKEN=""
if [ "$INSTALL_PORTAINER" = true ]; then
  log_info "Waiting for Portainer to generate Setup Token..."
  for i in {1..15}; do
    PORTAINER_TOKEN=$(docker logs portainer 2>&1 | grep "setup_token=" | tail -n 1 | grep -oP '[a-f0-9]{64}')
    
    if [ -z "$PORTAINER_TOKEN" ]; then
      PORTAINER_TOKEN=$(docker logs portainer 2>&1 | grep "Setup token:" | tail -n 1 | grep -oP '[a-f0-9]{64}')
    fi

    if [ -n "$PORTAINER_TOKEN" ]; then
      break
    fi
    sleep 2
  done
fi

# === FINAL DASHBOARD ===
echo -e "\n${GREEN}=====================================================================${NC}"
if [ "${LANGUAGE:-CZ}" = "EN" ]; then
  echo -e "${GREEN}                 🎉 DIAGNOSTICS COMPLETED 🎉                 ${NC}"
else
  echo -e "${GREEN}                 🎉 DIAGNOSTIKA DOKONČENA 🎉                 ${NC}"
fi
echo -e "${GREEN}=====================================================================${NC}"
echo -e "IP adresa / Address: ${YELLOW}$STATIC_IP${NC}\n"

if [ "$INSTALL_PIHOLE" = true ]; then
  echo -e "${YELLOW}▶ Pi-hole (Ad-block):${NC}    http://$STATIC_IP:8080/admin"
  echo -e "   Heslo / Password:     $PIHOLE_PASSWORD"
  if [ "${LANGUAGE:-CZ}" = "EN" ]; then echo -e "   -> Set your router's DNS server to: $STATIC_IP\n"; else echo -e "   -> Aby blokování fungovalo, nastavte v routeru DNS na: $STATIC_IP\n"; fi
fi

if [ "$INSTALL_PORTAINER" = true ]; then
  echo -e "${YELLOW}▶ Portainer (Docker):${NC}    http://$STATIC_IP:9000"
  if [ -n "$PORTAINER_TOKEN" ]; then
    echo -e "   Setup Token:          ${CYAN}$PORTAINER_TOKEN${NC}"
    if [ "${LANGUAGE:-CZ}" = "EN" ]; then echo -e "   -> IMPORTANT: You have exactly 5 minutes to use this token!\n"; else echo -e "   -> DŮLEŽITÉ: Máte přesně 5 minut na použití tohoto tokenu!\n"; fi
  else
    if [ "${LANGUAGE:-CZ}" = "EN" ]; then echo -e "   -> Check logs for token: docker logs portainer\n"; else echo -e "   -> Token nenalezen, zkontrolujte logy: docker logs portainer\n"; fi
  fi
fi

if [ "$INSTALL_UPTIMEKUMA" = true ]; then
  echo -e "${YELLOW}▶ Uptime Kuma (Monitor):${NC} http://$STATIC_IP:3001\n"
fi

if [ "$INSTALL_WIREGUARD" = true ]; then
  echo -e "${YELLOW}▶ WireGuard (VPN):${NC}"
  echo -e "   Show QR code:         sudo docker exec -it wireguard /app/show-peer 1"
  if [ "${LANGUAGE:-CZ}" = "EN" ]; then echo -e "   -> Download WireGuard app and scan the QR code generated above.\n"; else echo -e "   -> Stáhněte si aplikaci WireGuard a naskenujte QR kód vygenerovaný výše.\n"; fi
fi

if [ "${LANGUAGE:-CZ}" = "EN" ]; then
  echo -e "${CYAN}SSH access has been secured and moved to port $SSH_PORT:${NC} ssh $USER_NAME@$STATIC_IP -p $SSH_PORT"
else
  echo -e "${CYAN}Přístup přes SSH je z bezpečnostních důvodů přesunut na port $SSH_PORT:${NC} ssh $USER_NAME@$STATIC_IP -p $SSH_PORT"
fi
echo -e "${GREEN}=====================================================================${NC}\n"

# === INTERACTIVE MANUAL ===
if [ "${LANGUAGE:-CZ}" = "EN" ]; then
  echo -e "${YELLOW}Show detailed user manual? (m = Manual / any other key = Exit)${NC}"
else
  echo -e "${YELLOW}Chcete zobrazit podrobný manuál k obsluze? (m = Manuál / jakákoliv jiná klávesa = Konec)${NC}"
fi

read -n 1 -s -r key
if [[ $key == "m" || $key == "M" ]]; then
  clear
  echo -e "${CYAN}=====================================================================${NC}"
  if [ "${LANGUAGE:-CZ}" = "EN" ]; then
    echo -e "${CYAN}                   📖 DETAILED USER MANUAL 📖                        ${NC}"
  else
    echo -e "${CYAN}                   📖 PODROBNÝ UŽIVATELSKÝ MANUÁL 📖                 ${NC}"
  fi
  echo -e "${CYAN}=====================================================================${NC}\n"

  if [ "${LANGUAGE:-CZ}" = "EN" ]; then
    # --- ENGLISH MANUAL ---
    if [ "$INSTALL_PIHOLE" = true ]; then
      echo -e "${YELLOW}▶ Pi-hole (Ad-block & Tracking Protection)${NC}"
      echo -e "  - Acts as a 'black hole' for ads across your entire network."
      echo -e "  - To cover all devices (phones, TVs), you must change the DNS server"
      echo -e "    in your Wi-Fi router's DHCP settings to: ${GREEN}$STATIC_IP${NC}"
      echo -e "  - Web Management Interface: http://$STATIC_IP/admin\n"
    fi
    if [ "$INSTALL_UNBOUND" = true ]; then
      echo -e "${YELLOW}▶ Unbound (Private DNS Resolver)${NC}"
      echo -e "  - An invisible but critical privacy shield. No web interface."
      echo -e "  - Runs in the background; Pi-hole asks it for all domain translations."
      echo -e "  - Prevents your ISP from seeing which websites you visit.\n"
    fi
    if [ "$INSTALL_PORTAINER" = true ]; then
      echo -e "${YELLOW}▶ Portainer (Docker Container Management)${NC}"
      echo -e "  - A graphical interface to manage everything running on your server."
      echo -e "  - On the first launch, you will need the Setup Token."
      echo -e "  - Copy the long token displayed above and paste it into your browser.\n"
    fi
    if [ "$INSTALL_UPTIMEKUMA" = true ]; then
      echo -e "${YELLOW}▶ Uptime Kuma (Monitoring Dashboard)${NC}"
      echo -e "  - A beautiful dashboard to monitor if your websites and services are online."
      echo -e "  - Access it at: http://$STATIC_IP:3001"
      echo -e "  - Tip: To monitor your router, add a new monitor and select type 'Ping'.\n"
    fi
    if [ "$INSTALL_WIREGUARD" = true ]; then
      echo -e "${YELLOW}▶ WireGuard (Personal VPN)${NC}"
      echo -e "  - A secure tunnel home when on public Wi-Fi or mobile data."
      echo -e "  - 🛡️ IMPORTANT: Because your traffic is routed home, Pi-hole applies!"
      echo -e "    You will enjoy an ad-free internet even on mobile data outside."
      echo -e "  - The system auto-generated 20 ready-to-use client keys."
      echo -e "  - To show the QR code for your first phone, type in SSH:"
      echo -e "    ${GREEN}sudo docker exec -it wireguard /app/show-peer 1${NC}"
      echo -e "  - For a second phone, just change the number 1 to 2 (up to 20)."
      echo -e "  - Text configs physically reside in: ${GREEN}/home/$USER_NAME/docker/wireguard/${NC}\n"
    fi
    if [ "$INSTALL_WATCHTOWER" = true ]; then
      echo -e "${YELLOW}▶ Watchtower (Automated Updates)${NC}"
      echo -e "  - An invisible bot that regularly checks for new versions of your"
      echo -e "    apps and safely updates them in the background without downtime.\n"
    fi
    echo -e "${CYAN}=====================================================================${NC}"
    echo -e "Press any key to exit the manual..."
  else
    # --- CZECH MANUAL ---
    if [ "$INSTALL_PIHOLE" = true ]; then
      echo -e "${YELLOW}▶ Pi-hole (Blokování reklam a sledování)${NC}"
      echo -e "  - Funguje jako 'černá díra' pro reklamy na úrovni celé domácí sítě."
      echo -e "  - Aby fungoval pro všechny mobily a TV, musíte ve svém Wi-Fi routeru"
      echo -e "    najít nastavení DHCP/DNS a přepsat IP adresu DNS serveru na: ${GREEN}$STATIC_IP${NC}"
      echo -e "  - Webové rozhraní pro správu: http://$STATIC_IP/admin\n"
    fi
    if [ "$INSTALL_UNBOUND" = true ]; then
      echo -e "${YELLOW}▶ Unbound (Privátní DNS Resolver)${NC}"
      echo -e "  - Neviditelný, ale kritický štít vašeho soukromí. Nemá webové rozhraní."
      echo -e "  - Běží na pozadí a Pi-hole se ho automaticky ptá na všechny adresy."
      echo -e "  - Díky němu váš poskytovatel internetu nevidí, jaké weby navštěvujete.\n"
    fi
    if [ "$INSTALL_PORTAINER" = true ]; then
      echo -e "${YELLOW}▶ Portainer (Správa Docker kontejnerů)${NC}"
      echo -e "  - Grafické rozhraní pro správu všeho, co na serveru běží."
      echo -e "  - Při prvním spuštění budete potřebovat tzv. Setup Token."
      echo -e "  - Zkopírujte si dlouhý kód vypsaný výše a vložte jej do prohlížeče.\n"
    fi
    if [ "$INSTALL_UPTIMEKUMA" = true ]; then
      echo -e "${YELLOW}▶ Uptime Kuma (Monitorovací nástěnka)${NC}"
      echo -e "  - Krásný dashboard pro sledování, zda vaše weby a služby běží."
      echo -e "  - Přístup na adrese: http://$STATIC_IP:3001"
      echo -e "  - Tip: Pro sledování vašeho routeru přidejte nový monitor typu 'Ping'.\n"
    fi
    if [ "$INSTALL_WIREGUARD" = true ]; then
      echo -e "${YELLOW}▶ WireGuard (Osobní VPN)${NC}"
      echo -e "  - Bezpečný tunel domů, když jste na veřejné Wi-Fi nebo mobilních datech."
      echo -e "  - 🛡️ DŮLEŽITÉ: Protože se tunelujete domů, platí na mobilu pravidla Pi-hole."
      echo -e "    Budete mít tedy internet zcela bez reklam i mimo domácí Wi-Fi!"
      echo -e "  - Systém vygeneroval 20 připravených klíčů (klientů)."
      echo -e "  - Pro zobrazení QR kódu pro první mobil zadejte v terminálu:"
      echo -e "    ${GREEN}sudo docker exec -it wireguard /app/show-peer 1${NC}"
      echo -e "  - Pro druhý mobil prostě v příkazu změňte číslo 1 na 2 (až do 20)."
      echo -e "  - Textové konfigurace leží na serveru ve složce: ${GREEN}/home/$USER_NAME/docker/wireguard/${NC}\n"
    fi
    if [ "$INSTALL_WATCHTOWER" = true ]; then
      echo -e "${YELLOW}▶ Watchtower (Automatické aktualizace)${NC}"
      echo -e "  - Neviditelný robot. Pravidelně kontroluje, zda nevyšla nová verze"
      echo -e "    vašich aplikací, a případně ji sám bezpečně aktualizuje.\n"
    fi
    echo -e "${CYAN}=====================================================================${NC}"
    echo -e "Pro ukončení manuálu a návrat do systému stiskněte libovolnou klávesu..."
  fi
  read -n 1 -s -r
  clear
fi