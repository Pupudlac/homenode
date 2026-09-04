# 📖 Kompletní průvodce systémem HomeNode

Vítejte! Tento dokument vás krok za krokem provede instalací a používáním systému HomeNode. Nepotřebujete být IT expert – stačí pečlivě číst a následovat jednotlivé kroky.

## 🚀 Rychlý start (Expresní instalace)
Máte čistý Raspberry Pi OS Lite? Stačí zkopírovat tento jeden příkaz, vložit ho do terminálu (přes SSH) a stisknout Enter:

```bash
git clone https://github.com/Pupudlac/homenode.git && cd homenode && chmod +x install.sh && sudo ./install.sh
```

## 1. O co jde a k čemu to je?
HomeNode je plně automatizovaný instalační balíček, který promění váš minipočítač (Raspberry Pi) v neuvěřitelně výkonný, bezpečný a chytrý mozek vaší domácnosti.

**Co systém automaticky nainstaluje a zařídí:**
*   **Pi-hole (Blokování reklam):** Funguje jako černá díra na reklamy. Odstraní reklamy a sledovací kódy ze všech zařízení u vás doma (mobily, počítače, chytré televize), aniž byste do nich museli cokoliv instalovat.
*   **Unbound (Soukromí):** Skrytý štít, který šifruje vaše dotazy na webové stránky. Váš poskytovatel internetu díky němu neuvidí, jaké weby navštěvujete.
*   **WireGuard (Osobní VPN):** Bezpečný "tunel" domů. Když jste na veřejné Wi-Fi (např. v kavárně), jedním kliknutím v mobilu se bezpečně připojíte domů. Jako bonus budete mít internet bez reklam i na mobilních datech!
*   **Uptime Kuma (Monitoring):** Krásná vizuální nástěnka, která neustále hlídá, zda vaše weby, router a služby běží, a upozorní vás na výpadky.
*   **Docker & Portainer:** Moderní technologie, která umožňuje běh všech těchto aplikací v bezpečných "kontejnerech". Portainer vám poskytne grafické rozhraní pro jejich správu.
*   **Neprůstřelný Firewall:** Systém se automaticky uzamkne proti útokům z internetu.

## 2. Požadavky před spuštěním
1.  **Raspberry Pi** (minipočítač) připojený k vaší domácí síti (ideálně kabelem k routeru).
2.  **MicroSD kartu** (min. 16 GB) nebo NVMe/SSD disk.
3.  Počítač s Windows, Mac nebo Linuxem pro přípravu karty.
4.  **Veřejná IP adresa (Důležité):** Pro plnou funkčnost osobní VPN (WireGuard) zvenčí je vyžadována veřejná IPv4 adresa od vašeho poskytovatele internetu. Pokud ji nemáte, můžete systém stále používat pro lokální blokování reklam (Pi-hole), ale VPN vám mimo domov nebude fungovat.

## 3. KROK 1: Příprava paměťové karty (Instalace OS)
Aby Raspberry Pi fungovalo, potřebuje operační systém. **Tento skript je optimalizován pro Debian 12 (Bookworm) a novější Debian 13 (Trixie).**

1.  Stáhněte si program **Raspberry Pi Imager** z [oficiálních stránek](https://www.raspberrypi.com/software/).
2.  Vložte MicroSD kartu do počítače a spusťte Imager.
3.  Vyberte operační systém: Zvolte **Raspberry Pi OS Lite (64-bit)** (verze Lite bez grafického rozhraní je pro tento server ideální a nejrychlejší).
4.  **DŮLEŽITÉ – Nastavení:** Před kliknutím na tlačítko zápisu klikněte na ikonu ozubeného kolečka (Edit Settings):
    *   Povolte službu **SSH** (slouží pro vzdálený přístup).
    *   Nastavte si **uživatelské jméno a heslo** (dobře si je zapamatujte!).
    *   U lokalizace nastavte jazyk "en" (English) a zemi "US" (kvůli správné synchronizaci času).
5.  Spusťte zápis. Po dokončení kartu vložte do Raspberry Pi a zapojte jej do napájení.

## 4. KROK 2: První připojení k Raspberry Pi
Raspberry Pi běží bez monitoru. Připojíme se k němu vzdáleně přes textovou konzoli (SSH).
1.  Zjistěte IP adresu svého Raspberry Pi (najdete ji v administraci vašeho domácího Wi-Fi routeru, obvykle vypadá jako `192.168.1.x`).
2.  **Windows:** Stáhněte si program [PuTTY](https://www.putty.org/). Do pole *Host Name* zadejte IP adresu, port nechte na `22` a klikněte na Open. Zadejte své jméno a heslo (při psaní hesla se neukazují hvězdičky).
3.  **Mac / Linux:** Otevřete Terminál a napište `ssh vase_jmeno@ip_adresa`.

## 5. KROK 3: Instalace systému

Máte dvě možnosti, jak systém nainstalovat. Doporučujeme první (Expresní) metodu.

### Metoda A: Expresní instalace (One-Liner)
Už žádné složité kopírování souborů! Stačí zkopírovat tento jeden příkaz, vložit ho do černého okna (PuTTY/Terminálu) a stisknout Enter:

```bash
git clone https://github.com/Pupudlac/homenode.git && cd homenode && chmod +x install.sh && sudo ./install.sh
```

### Metoda B: Lokální instalace (přes WinSCP)
Pokud jste si stáhli soubory do počítače (Windows) a nahráli je na Raspberry Pi ručně (např. přes WinSCP), musíte před spuštěním provést tyto tři kroky, abyste odstranili neviditelné Windows znaky:

```bash
# 1. Očištění souborů od Windows znaků
sed -i 's/\r$//' *.sh utils/*.sh test/*.sh 2>/dev/null || true

# 2. Nastavení práv ke spuštění
chmod +x *.sh utils/*.sh test/*.sh

# 3. Odpalte instalaci
sudo ./install.sh
```

---

Na obrazovce na vás vyskočí grafický průvodce. Doporučujeme zvolit **Expresní instalaci**, která si vše detekuje sama. U Pi-hole si můžete vybrat úroveň blokování (od bezpečné rodinné až po agresivní Paranoia mód).

💡 **POZOR PO INSTALACI:** Jakmile instalátor dokončí svou práci, z bezpečnostních důvodů uzamkne výchozí SSH port 22 a přesune jej na port **2222**. Až se budete k Raspberry Pi připojovat příště, nezapomeňte v PuTTY změnit port na 2222!

## 6. Jak se tam dostanu? (Základní přístupy)
Po úspěšném dokončení instalace vám systém sám vypíše všechny adresy. Zde je jejich přehled (místo `IP_ADRESA` doplňte IP adresu vašeho Raspberry):

*   **Webová administrace Pi-hole (Reklamy):** `http://IP_ADRESA:8080/admin`
    *   *Aby blokování fungovalo na všech zařízeních u vás doma, musíte ve svém Wi-Fi routeru najít nastavení DHCP a změnit DNS server právě na IP adresu tohoto Raspberry Pi.*
*   **Správa kontejnerů Portainer:** `http://IP_ADRESA:9000`
    *   *(Při prvním spuštění budete potřebovat tzv. **Setup Token**. Tento dlouhý kód se vám vypsal na konci instalace v terminálu. Zkopírujte jej a vložte do prohlížeče pro vytvoření administrátorského účtu.)*
*   **Uptime Kuma (Monitoring):** `http://IP_ADRESA:3001`
    *   *(Zde si můžete přidat sledování vašeho routeru nebo webových stránek. Pro sledování routeru použijte typ monitoru "Ping".)*
*   **Vzdálený přístup přes SSH:** `ssh vase_jmeno@IP_ADRESA -p 2222`

## 7. Řešení problémů a užitečné příkazy

Pokud budete potřebovat systém spravovat, připojte se přes SSH (nezapomeňte na port 2222) a použijte tyto příkazy:

**Změna hesla do Pi-hole:**
Pokud zapomenete heslo do webové administrace Pi-hole, můžete ho kdykoliv změnit tímto příkazem:
```bash
sudo docker exec pihole pihole setpassword "VASE_NOVE_HESLO"
```

**Vypršel čas pro Portainer (Timeout):**
Portainer vám dává přesně 5 minut na první přihlášení. Pokud to nestihnete, zablokuje se. Pro vygenerování nového tokenu a restartování odpočtu zadejte:
```bash
sudo docker restart portainer
sudo docker logs portainer
```
*(V logu pak najdete nový Setup Token).*

**Záloha WireGuardu (Před reinstalací):**
Pokud budete někdy přeinstalovávat systém, ale chcete, aby se vám mobily připojily bez nutnosti znovu skenovat QR kódy, zazálohujte si tuto složku:
`/home/vase_jmeno/docker/wireguard/`
Po čisté instalaci ji stačí nahrát zpět a vše bude fungovat jako dřív.

## 8. Záchranná brzda (Odinstalace)
Pokud se něco pokazí, nebo vám systém nevyhovuje, můžete vše vrátit do původního stavu. Připojte se přes SSH a zadejte:

```bash
cd homenode
sudo ./uninstall.sh
```

Tento skript smaže všechny kontejnery, vypne firewall a vrátí síť do původního stavu.

Děkujeme, že používáte HomeNode! Užívejte si bezpečný internet bez reklam.