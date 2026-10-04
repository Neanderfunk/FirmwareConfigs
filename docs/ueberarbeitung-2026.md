# Sackgasse 2021.1: Überarbeitung 2026

Auftrag adorfer 04.10.2026: noch einmal eine Sackgasse für die 4/32-Geräte
bauen, die möglichst viel aus unseren höheren Zweigen (v2023.2.x, v2025.1.x)
mitbekommt.

**Rangfolge bei Platzkonflikten:** Sicherheit vor Stabilität vor
WLAN-Client-Optimierung vor Einrichtungskomfort. Fliegt dafür etwa der
Web-Setup-Mode heraus, ist das hinnehmbar, wenn stattdessen Client-Fixes
hineinkommen.

## Ausgangslage

- Dieser Zweig war bis `b642e73` identisch mit `eulenfunk/firmware` v2021.x
  (Tag `archiv/v2021.x-eulenfunk-b642e73`). Gebaut wurde daraus
  `24111216sackgasse`: Gluon `v2021.1.2-21-gb015481d` (OpenWrt 19.07,
  Kernel 4.14.275), Targets `ar71xx-tiny` und `ar71xx-generic`.
- Gluon v2021.1.x und openwrt-19.07 sind ausgeschöpft: Upstream kommt nichts
  mehr, alles weitere sind eigene Backports.
- Platz auf 4-MB-TP-Link: rund 315 KiB Overlay (4 bis 5 Erase-Blöcke).
- Bestandsaufnahme und Kandidaten: router-werkstatt
  `docs/sackgasse-rebuild-kandidaten.md`; Migrationspfade und Grenzen:
  `docs/gluon-migrationspfade.md`, `docs/gluon-historie.md`.

## Erledigt (04.10.2026)

- Altes Buildsystem entfernt (`build.sh`, `long-server-task.sh`, `esign`,
  CI-Dateien). Gebaut wird künftig mit dem ParallelBuildsystem.
- Feed: `Neanderfunk/packages` Branch `v2021.1.x` (Packages-Session) mit
  `neanderfunk-legacy-migrate` für 2021.1 (2015.1/2016.x heranholen), Basis
  `v2020.1.x` `cd24c70`. Noch nicht eingebunden, siehe unten.

## Plan

1. **Aufbau wie v2025.1.x:** `templates/common/` (site.conf, site.mk, modules,
   prepare.sh, i18n), `build.conf` mit Gluon-Pin, `domains.conf`,
   `targets.conf`, `patchrepos`. Die 85 Symlink-Templates und
   `sites.nefall.sackgasse` darauf abbilden.
2. **Gluon-Pin:** `v2021.1.x` Ende (`3181e496`), dazu unser
   WR841-8M/16M-Patch.
3. **Feed** von `eulenfunk/packages` auf `Neanderfunk/packages` `v2021.1.x`
   umstellen, `neanderfunk-legacy-migrate` in die Paketliste.
4. **Patch-Repos** `gluon-patches-hardware`/`-fixes` Zweig `v2021.1.x`
   (Buildsystem-Session), `gluon-patches-packages` `v2021.1.x`
   (Packages-Session). Die Patches aus `patches/` hier dorthin verteilen;
   wirkungslose streichen (Mi 4A Gigabit, Archer A7 v5, radiooffcrash,
   tunneldiggergit, NAPI, u-boot-upgrade).
5. **Diät** (Platz für Fixes): socat, haveged/libhavege, wireless-tools über
   txpowerfix-DEPENDS, ath9kblackout; je nach Bedarf Banner, Setup-Mode.
6. **Sicherheit:** dnsmasq CVE-2026-2291, Autoupdater-uclient-Fixes
   (`5521926`, `e4bd7a4`), uclient `007d9454`.
7. **Stabilität:** tote und fehlerhafte Teile in linkcheck, hotfix,
   weeklyreboot (Uhr-Schleife), ssid-changer; Entscheidungen zu Checks, die
   repariert erstmals scharf würden (Kandidatenliste, Abschnitt D).
8. **WLAN-Client:** was aus 2023.2/2025.1 auf 19.07/hostapd 2019 passt.
9. **ParallelBuildsystem:** Gluon 2021.1 / OpenWrt 19.07 bauen können
   (Host-Abhängigkeiten, Python 2/3, Overlay-Prüfung für tiny).
10. **Abnahme** am Gerät (4/32-Testgerät nötig), Manifest wie bisher
    `sackgasse` mit Merge ins Upgrade-Verzeichnis.

## Arbeitsteilung

- **Buildsystem-Session:** dieser Zweig (Aufbau, Pins, Paketliste),
  ParallelBuildsystem für 2021.1, `gluon-patches-hardware`/`-fixes`
  `v2021.1.x` (Gluon/OpenWrt-Backports, Sicherheit), Größenbilanz,
  Testplatz, Manifest.
- **Packages-Session:** Feed `v2021.1.x` (Paketfixes, Diät der Feed-Pakete,
  Client-Fixes, legacy-migrate), `gluon-patches-packages` `v2021.1.x`.

## Aufträge aus dem Feed v2021.1.x (beim Umbau erledigen)

Packages-Session, 04.10.2026 (noch kein Pin, Sammel-Pin nach Abschnitt C):

- [x] `eulenfunk-ath9kblackout` aus der Paketliste nehmen und den
  site.conf-Abschnitt `ath9kblackout { blackoutwait, resetwait, stepsize }`
  streichen (Paket im Feed entfernt, `a07f6d8`).
- [x] `wireless-tools`, falls irgendwo (stand nirgends ausdrücklich) ausdrücklich in site.mk/Paketliste,
  ebenfalls raus (txpowerfix hängt nicht mehr daran, `f812b42`, ~17 KB xz).
- Zur Kenntnis: `gluon-weeklyreboot` bringt `/etc/hotplug.d/ntp/99-weeklyreboot`
  mit (`79e8ec0`), nutzt das ntpd-hotplug von 19.07.

Feed-Commits bisher: `8b225c9` legacy-migrate, `abb7a40` linkcheck,
`79e8ec0` weeklyreboot, `758c2e7` migrate-updatebranch, `a07f6d8`
ath9kblackout raus, `f812b42` txpowerfix.

## Feed umgestellt (04.10.2026)

`templates/05_mon/modules`: Feed `neanderfunk` = Neanderfunk/packages
`v2021.1.x` `d0b4a86` (Sammel-Pin Abschnitt C), statt eulenfunk/packages
`cd24c70`. ffki-Feed entfernt (kein Paket daraus im Image, `git://`-URL geht
bei GitHub nicht mehr). `neanderfunk-legacy-migrate` in der Paketliste,
`eulenfunk-ath9kblackout` und der site.conf-Abschnitt `ath9kblackout` raus.

**web-wizard geklärt:** Er kommt in 2021.1 über keine Abhängigkeit mit; nur
das Feature `web-wizard` wählt die Wizard-Module (hostname, geo-location,
contact-info, outdoor, dazu autoupdater/mesh-vpn), `package/features` in
v2021.1.2. adorfer hat ihn am 28.01.2025 (`b642e73`) zusammen mit
`web-advanced`, `eulenfunk-ch13to9` und `gluon-config-mode-geo-location-osm`
aus dem Template genommen. Die Images `24111216sackgasse` stammen von davor
und haben den Wizard noch (build.log: gluon-config-mode-* in allen
Images). Ein Bau aus diesem Zweig hat ihn also nicht; passt zur Rangfolge
(Einrichtungskomfort zuletzt), nach der Größenbilanz neu entscheiden.

Feed danach `0f75cb7` (04.10.2026): `gluon-txpowerfix` ist der Port von
`neanderfunk-txpowerfix` aus v2025.1.x (Entscheidung adorfer: Country-Logik
und htmode bleiben, vorhandene txpower-Einträge werden einmal gelöscht, neue
nicht gesetzt; kein Init-Skript, kein wifi down/up mehr). Baut jetzt aus
luasrc, braucht also luasrcdiet/host wie legacy-migrate. Der Load-Check im
hotfix bleibt unverändert (adorfer).

## Tunneldigger ohne WAN (Pflicht, adorfer)

Der Fix für "VPN aktiv, aber kein WAN" kommt in jedem Fall mit, zwei Teile:

- Watchdog: `gluon-patches-packages` `v2021.1.x` `69eace4` (Packages-Session),
  Port von FirmwareConfigs v2023.2.x `e362e4d`.
- Client: `gluon-patches-fixes` `v2021.1.x` `c06ae99`
  (`tunneldigger-reinit-backoff`, Modulpatch nach `patches/packages/gluon`).

Pins in `templates/05_mon/patchrepos`; wirksam, sobald prepare.sh die
Patch-Repos anwendet (Umbau, Schritt 1). Beim ersten Bau prüfen, dass
`git am` im Modul packages/gluon greift.

Feed danach `884f5b9` (04.10.2026): `neanderfunk-wifi-blackout` (Port aus
v2025.1.x, reparierter Nachfolger von ath9kblackout, Zustimmung adorfer) in
der Paketliste, site.conf-Abschnitt `wifi_blackout` mit den alten Werten
171/281/10. Abhängigkeit `micrond` kommt aus dem OpenWrt-Paketfeed 19.07.

## SSH-Schlüssel: nur RSA (dropbear 2019.78)

dropbear aus OpenWrt 19.07 kann kein ed25519 (Packages-Session, am Testknoten
WR841N v9 bestätigt: nur Hostkey ssh-rsa, ed25519-Login abgelehnt). Die
`buildkeys/*.sshkeys` dieses Zweigs enthalten nur `ssh-rsa`; die meisten
Sackgasse-Domains bauen ohnehin mit `*.nokeys` (keine Schlüssel). Beim Umbau
**nicht** die Schlüsseldateien aus v2025.1.x übernehmen (dort ed25519,
FirmwareConfigs `2b67aa2`), sonst kommt auf 2021.1-Knoten niemand mehr per
Schlüssel hinein. Zugriff: `ssh -o HostKeyAlgorithms=+ssh-rsa
-o PubkeyAcceptedAlgorithms=+ssh-rsa` (keine rsa-sha2-Signaturen).

Feed danach `c8cd015` (04.10.2026): eulenfunk-hotfix `check_hostapd` repariert
(Entscheidung adorfer): phy aus dem Pidfile-Namen statt aus `ps` (busybox ps
kürzt ohne Terminal auf 80 Spalten), der Kanal-unbekannt-Check ist damit zum
ersten Mal scharf (drei Läufe ohne Kanal -> WLAN-Neustart).

Gerätedaten Testknoten WR841N v9 (24111111sta, Packages-Session): Overlay
320 KiB gesamt, 84 KiB frei; RAM verfügbar ~9 MB. Alle Feed-Skripte liefen
dort als Kopien mit Attrappen gegen die echten 2021.1-Bibliotheken fehlerfrei.

## Speicher: squashfs, zram, WLAN-Puffer, Sprachen (Prüfung 04.10.2026)

Grundlage: die echten Images `24111216sackgasse`, OpenWrt 19.07
(`1da2e82c11`), Gluon `3181e496`. Ziel ist dieselbe Art Entlastung wie bei den
64-MB-Dualband-Geräten in 2023.2/2025.1 (router-werkstatt
`docs/ramdruck-64mb.md`), hier aber mit 4 MB Flash **und** 32 MB RAM.

**squashfs-Blockgröße.** Gemessen: tiny-Images 256 KiB (Gluon
`targets/generic`), generic-Images 64 KiB (Gluon setzt das für
ar71xx-generic). Das Rootfs des WR841N v9 neu gepackt (xz, ohne die
OpenWrt-eigenen Feinoptionen, deshalb nur relativ zu lesen):

| Block | Rootfs | gegenüber 256 KiB |
| --- | --- | --- |
| 64 KiB | 2270 KiB | +117 KiB |
| 128 KiB | 2203 KiB | +50 KiB |
| 256 KiB | 2153 KiB | 0 |
| 512 KiB | 2117 KiB | -35 KiB |
| 1024 KiB | 2079 KiB | -73 KiB |

- **tiny bleibt bei 256 KiB.** Kleiner geht nicht (84 KiB Overlay frei),
  größer kostet RAM: Der Kernel hält einen Fragment-Cache von drei Blöcken
  (`CONFIG_SQUASHFS_FRAGMENT_CACHE_SIZE=3`) plus Lesepuffer und
  xz-Wörterbuch je Blockgröße, bei 1024 KiB also gut 3 MB mehr; auf 32 MB mit
  ~9 MB verfügbar nicht vertretbar. 512 KiB brächte einen halben
  Erase-Block für über 1 MB RAM: nein.
- **generic bleibt bei 64 KiB** (8-MB-Flash, dort ist RAM knapper als Flash).
- **Kandidat ohne Flash-Kosten:** `CONFIG_SQUASHFS_FRAGMENT_CACHE_SIZE=1` für
  tiny spart zwei Blöcke, also 512 KiB RAM. Risiko: mehr Dekompression bei
  Dateien in Fragmenten. Am Testgerät messen (MemAvailable, Refaults, Load).

**zram.** Die Sackgasse baut zram mit `KERNEL_SWAP` (Patch `kernelswapon`)
und einem gekürzten `zram.init`: Größe RAM/2 minus 5 MB, also etwa 8 MB.
Algorithmus ist die Kernel-Vorgabe lzo.
- **Kandidat ohne Flash-Kosten:** `vm.page-cluster=0` in sysctl.d (keine
  Swap-Vorauslese von 8 Seiten, für zram üblich), ggf. `vm.swappiness=100`.
  Eine Zeile, am Testgerät prüfen.
- **Kandidat Flash:** `kmod-lib-lz4` kommt über `kmod-zram` mit ins Image, wird
  bei lzo aber nicht genutzt. Weglassen spart einige KiB; braucht eine
  Anpassung an der Abhängigkeit von kmod-zram. Vorher die Größe des Pakets im
  Image messen.

**WLAN-Puffer.**
- Gluon 2021.1 setzt bei 32 MB RAM schon `fq_memory_limit` auf 256 KiB
  (`01-gluon-core-codel-memusage`); mehr bringt dort nichts.
- **Kandidat ath9k:** Der Treiber legt fest `ATH_RXBUF` 512 und `ATH_TXBUF`
  512 Puffer an (`ath9k.h`). Jeder Empfangspuffer ist ein skb für eine volle
  MPDU (3840 Byte plus Verwaltung), vermutlich aus dem 8-KiB-Slab. Das wären
  bis zu 2-4 MB vorab belegt. 128 statt 512 könnte auf 32 MB viel bringen,
  Risiko sind Paketverluste unter Last. **Erst am Testgerät messen**
  (`/proc/slabinfo` bzw. MemFree mit und ohne geladenes ath9k), dann als
  Patch an mac80211 entscheiden.

**Sprachen.** adorfer: nur eine Sprache; weil Gluon 2021.1 `en` immer
mitnimmt (Quellsprache, `package/gluon.mk`), fliegt **Deutsch** raus:
`GLUON_LANGS ?= en`. Gemessen am WR841N-v9-Rootfs: 14 `*.de.lmo` mit 9,8 KB,
ohne sie 4 KiB weniger squashfs. `i18n/de.po` der Site bleibt im Repo
(Content-Session hat die Texte am 04.10. gekürzt, `90531ed`), wird aber nicht
mehr gebaut.

**Nachtrag adorfer:** RAM ist auf 4/32 nicht kritisch, Flash beißt. Deshalb:
- tiny bekommt **1024-KiB-squashfs-Blöcke** (`gluon-patches-fixes` `v2021.1.x`
  `62fe6ce`, `lowflash/squashfs-1024-tiny`), rund 73 KiB Flash weniger.
- Die RAM-Kandidaten (Fragment-Cache, ath9k-Puffer, page-cluster) haben
  Nachrang; nur angehen, wenn das Testgerät Druck zeigt.
- `kmod-lib-lz4` raus (adorfer): `kmod-zram` hängt nur noch an lzo
  (`lowflash/zram-lzo-only`), ~13 KiB weniger.
- **RAM-Druck im Auge behalten** (adorfer): 1024-KiB-Blöcke und lzo-only am
  Testgerät über Tage beobachten (MemAvailable, Swap-Nutzung,
  `workingset_refault`, Load); Gegenmittel in Reserve: Fragment-Cache 1,
  `vm.page-cluster=0`, ath9k-Puffer.

## Neue Leitlinie: reparieren statt streichen (adorfer, 04.10.2026)

Fehlerhafte Checks werden nicht mehr gestrichen, sondern repariert, und zwar
mit den Reparaturen aus 2025.1 zurückportiert, wo es geht. Das löst die
Empfehlung "ohne Entscheidung streichen" aus der Kandidatenliste
(router-werkstatt `docs/sackgasse-rebuild-kandidaten.md`, Abschnitt D) ab.

Feed danach `a4d58cc`:
- `c7d085a` eulenfunk-hotfix: neues `common.sh` (strike, autoupdater_busy,
  WLAN-Lock, harter Reboot); healthcheck (OOM-Muster, DFS mit 200 Zeilen und
  3 Läufen, br-client nach 4 Läufen, flock), check_hostapd (Pending per
  jsonfilter, 30 min Sperre; BSS-Status per ubus geht mit hostapd 2019 nicht),
  rebootIfNoGw (Gateway-Leiter zurück, 4 Läufe), IfNoWificlient.
- `2d8ec74` gluon-linkcheck: Leiter wie 2025.1 (melden, melden, WLAN neu,
  Reboot; erste Stunde nur melden), flock, Scan mit 20-s-Abbruch.
- `a4d58cc` gluon-ssid-changer: Schalter tolerant, leerer Zähler = 0.

Mehrere Checks sind damit **zum ersten Mal scharf**. Abnahme am Testgerät
muss auch "nichts passiert im Normalbetrieb über Tage" zeigen.
Als Nächstes prüft die Packages-Session `neanderfunk-respondd` (Wunsch
adorfer) für 19.07.
