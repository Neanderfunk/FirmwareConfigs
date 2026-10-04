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
