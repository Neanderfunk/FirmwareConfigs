# Release Notes 24112319sackgasse

**Neanderfunk-Firmware "Sackgasse" auf Basis von Gluon 2021.1**

Version `24112319sackgasse`, im Feld seit dem 17. Oktober 2026, gebaut für 30
Domains.

Die Sackgasse ist die Firmware für Router, die unsere aktuelle Firmware nicht
mehr vertragen: vor allem Geräte mit 4 MB Flash und 32 MB RAM wie TP-Link
WR841N/ND, WR740N, WA901ND, MR3020 und D-Link DIR-615 C1, dazu einige Geräte
mit 8 MB Flash und 32 MB RAM wie Ubiquiti NanoStation M2 und loco M2.

**Wo es die Firmware gibt:** auf dem
[Firmware-Server](https://firmware.ffnef.de/firmware/sackgasse/), nach Domain
sortiert.

**Auto-Update:** Router im Zweig `sackgasse` mit eingeschaltetem Auto-Update
holen sich diese Version von selbst. Die Einstellungen bleiben erhalten.

Diese Release Notes beschreiben, was sich seit `24111216sackgasse` geändert
hat. Gluon 2021.1 und OpenWrt 19.07 bekommen von dort keine Updates mehr. Alles
hier Genannte ist aus neueren Versionen zurückgeholt.

Rückmeldungen bitte an:

- E-Mail: [projekt@neanderfunk.de](mailto:projekt@neanderfunk.de)
- Mastodon: [@neanderfunk@nrw.social](https://nrw.social/@neanderfunk)
- Telegram: [Neanderfunk-Gruppe](https://t.me/+_rWKhNAJyvg5MWY0)

## Basis

| | |
|---|---|
| Gluon | [`3181e496`](https://github.com/freifunk-gluon/gluon/commit/3181e496f4b79234beec1a90ed9fca206a6708c7) (Zweig v2021.1.x), im Image `gluon-v2021.1.2-21-g71345033+` |
| OpenWrt | [`1da2e82c11`](https://github.com/openwrt/openwrt/commit/1da2e82c1182a3fd681da5760be96821213afadd) (openwrt-19.07), Kernel 4.14.275, mac80211 4.19.237 |
| Site und Build | [FirmwareConfigs `853134a`](https://github.com/Neanderfunk/FirmwareConfigs/tree/853134a) |
| Paketfeed | [Neanderfunk/packages `6e6fa53`](https://github.com/Neanderfunk/packages/tree/6e6fa53) |
| Patches | [gluon-patches-packages `f226a7f`](https://github.com/Neanderfunk/gluon-patches-packages/tree/f226a7f), [gluon-patches-hardware `8d2460c`](https://github.com/Neanderfunk/gluon-patches-hardware/tree/8d2460c), [gluon-patches-fixes `80ac9bd`](https://github.com/Neanderfunk/gluon-patches-fixes/tree/80ac9bd) |
| Targets | `ar71xx-tiny`, `ar71xx-generic` |

## batman-adv 2024.3

- **batman-adv springt von 2019.2 auf 2024.3**, samt batctl und den Fixes aus
  openwrt-24.10. Das ist derselbe Stand wie in unserer Stable 2025.1.3.
- **Das hilft der ganzen Domain.** Seit batman-adv 2024.0 lassen sich
  Multicast-Pakete mit einer Empfängerliste durchs Mesh schicken. Das greift
  nur, wenn jeder Knoten der Domain es beherrscht. Sonst bleiben Einzelkopien
  oder das Fluten durch die Domain. Mit diesem Update können es auch die
  ältesten Router. Das betrifft nur Multicast, die Ersparnis ist nicht
  gemessen.
- **WLAN-Mesh-Broadcasts gehen mit 24 statt 12 Mbit/s raus**, auf beiden
  Bändern (`mcast_rate = 24000`). Rechnerisch halbiert das ihre Sendezeit. Im
  Kabel-Mesh gilt diese Grenze nicht.
- Der Backport baut auf der Vorarbeit von T-X auf,
  [Gluon-PR #3377](https://github.com/freifunk-gluon/gluon/pull/3377).

## Neuer Supernode, neues Netz

- **Weitere Supernodes in der Firmware:** `sinope` läuft, `lysithea` ist eine
  Reserve ohne Betrieb. Ein Router verbindet sich nur mit Supernodes, die in
  seiner Firmware stehen.
- **Neues IPv6-Netz `2a13:fcc0::/29`** (Freie Netze Südhessen, AS62028) in
  `extra_prefixes6`. Die Firmware lässt von angeschlossenen Geräten nur Absender
  aus den dort genannten Netzen ins Mesh.
- Der FFRL-Eintrag in `extra_prefixes6` umfasst jetzt das ganze
  `2a03:2260::/29` statt eines /32.

## Sicherheit

Kernel und WLAN:

- **Mesh:** Ein Gerät in Funkreichweite konnte einen Router mit einem
  präparierten Funkpaket zum Absturz bringen (CVE-2026-23279, CVE-2026-23396).
- **Speicherleck im Mesh** behoben (CVE-2024-40942).
- Fixes für zsmalloc, l2tp und den Netzwerktreiber ag71xx beim Laden.

Dienste auf dem Router:

- **uhttpd:** begrenzt Anzahl und Größe der Header je Anfrage.
- **dnsmasq:** DNS-Pakete über UDP sind auf 1232 Byte begrenzt.
- **uclient:** prüft `Content-Length` und Chunk-Größen.
- **odhcp6c** und **udhcpc:** Prüfungen beim Lesen empfangener DHCP-Daten.
- **ubus:** fehlende Längenprüfungen ergänzt, Rechteprüfung beim Empfang von
  Ereignissen korrigiert.
- **Autoupdater:** kein Absturz mehr nach einem abgebrochenen Download.
- **sse-multiplex:** gibt seine Dateideskriptoren wieder frei.

## Stabilität

- **Die Selbstheilung kommt aus der aktuellen Firmware.** Die alten Pakete sind
  durch ihre Nachfolger aus 2025.1 ersetzt: `neanderfunk-hotfix`, `-linkcheck`,
  `-weeklyreboot`, `-ssid-changer`, `-txpowerfix` und `-migrate-updatebranch`.
- **Mehrere Prüfungen arbeiten jetzt wirklich.** Einige griffen in den alten
  Images nie, etwa die hostapd-Prüfung. Repariert sind auch die Erkennung von
  Speichermangel, die DFS-Prüfung und die Prüfung auf ausbleibende Clients.
- **Linkcheck wie in 2025.1:** erst melden, dann das WLAN neu starten, erst
  danach den Router. In der ersten Stunde nach dem Start meldet er nur.
- **Verbindungsprüfung zum Gateway:** 20 Pings an die Anycast-Adresse je Lauf,
  Neustart nach drei Fehlläufen in Folge.
- **Tunnel:** Der Router repariert sich selbst, wenn das VPN aktiv ist, die
  Internetleitung aber fehlt. Der Wächter dafür läuft als Shell-Skript statt
  alle fünf Minuten als Lua-Programm.
- **Netzwerktreiber:** Ein leerer Empfangspuffer in ag71xx führt nicht mehr zum
  Absturz.
- **WLAN-Aussetzer:** `neanderfunk-wifi-blackout` ersetzt das alte
  ath9k-Blackout-Paket.
- **Geplante Aufgaben** starten mit versetzten Minuten statt alle zugleich.

## WLAN

- **Die Sendeleistung wird nicht mehr festgeschrieben.** Vorhandene Einträge
  werden einmal gelöscht, neue nicht gesetzt.
- **`preserve_channels` wirkt wieder**, Kanäle bleiben über Updates erhalten.
- **Offline-SSID:** Wenn hostapd die Änderung verschluckt, startet der Router
  das WLAN hart neu.
- **Auto-Update mit Rückfall:** Hat ein Router lange keine Verbindung, versucht
  er, sein Update über ein benachbartes Freifunk-WLAN zu holen.

## Oberfläche und Einrichtung

- **Statusseite wie in der aktuellen Firmware:** mehr Details, SSID, Darkmode,
  die Zahl der Clients nur für die Bänder, die der Router hat. Der Signalgraph
  fragt alle 300 ms ab und belastet den Router dadurch weniger.
- **Setup-Mode und Einrichtung:** neues Theme, der Router ist unter
  `http://setup.gluon` erreichbar, Handys erkennen die Seite als Anmeldeseite,
  dazu ein eigenes WLAN für die Einrichtung.
- **Wifi-Taster** im Config-Mode frei belegbar (`neanderfunk-button-bind`).
- **Auf der Konsole:** `nodestatus` zeigt die Übersicht des Knotens.
- **Nodeplacer:** dasselbe Manifest wie in 2025.1, mit dem Zweig `sackgasse` der
  Zieldomain.
- **`neanderfunk-respondd`** meldet Speicherwerte (`mem_available`, Refaults,
  Forks, zram), damit wir RAM-Druck auf den Geräten sehen.
- **Migrationshelfer:** `neanderfunk-legacy-migrate` holt sehr alte Gluon-Stände
  heran, vorab in Emulation mit 2014.4, 2015.1.1, 2016.1 und 2018.2.2 geprüft.

## Mehr Platz im Flash, weniger RAM-Bedarf

Trotz der neuen Funktionen stehen auf Geräten mit 4 MB Flash jetzt **448 KiB
Overlay statt 320 KiB** zur Verfügung.

- **tiny:** squashfs mit 1024-KiB-Blöcken, rund 73 KiB.
- **`socat` und `haveged` entfallen**, zusammen rund 75 KiB. Die Entropie
  liefert urngd.
- **zram nur noch mit lzo**, rund 13 KiB. Upgrade-Helfer fremder Boardfamilien
  entfallen, rund 6 KiB.
- `wireless-tools` entfällt, die deutschen Übersetzungen ebenfalls.
- **ath9k:** 128 statt 256 Empfangspuffer, rund 0.7 MB RAM auf diesen Geräten.

## Geräte

**Wieder dabei: D-Link DIR-615 C1.**

## Bekannte Einschränkungen

- **Nur Englisch.** Für Deutsch ist im Flash kein Platz mehr.
- **Nicht in NodeMonitor.** Auch dafür reicht der Platz nicht, diese Router
  erscheinen dort nicht.
- **SSH nur mit RSA.** dropbear 2019.78 kennt kein ed25519. Aktuelle
  OpenSSH-Clients brauchen deshalb:

  ```sh
  ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@<knoten>
  ```
