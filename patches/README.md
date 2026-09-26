# patches/ – Neanderfunk-eigene Änderungen an Gluon

*Patches for Gluon v2023.2.x used only by Freifunk Neanderland. Patches that
are useful to others live in their own repositories, see below.*

## Wo die Patches liegen

Seit 27.09.2026 sind die Patches nach Nutzen für Dritte getrennt:

| Repo | Inhalt |
| --- | --- |
| [Neanderfunk/gluon-patches-hardware](https://github.com/Neanderfunk/gluon-patches-hardware) | zusätzliche Geräte und Targets, Geräte-Korrekturen, Treiber, primäre MACs |
| [Neanderfunk/gluon-patches-fixes](https://github.com/Neanderfunk/gluon-patches-fixes) | lowmem, allgemeine Fehlerbehebungen, Config-Mode-Wizard, Outdoor-Schalter, Paketpatches für Airtime und ffac |
| dieses Verzeichnis | was nur für Neanderfunk Sinn ergibt |

Welche Stände gebaut werden, steht in der Pin-Datei
`templates/common/patchrepos` (REPO, BRANCH und COMMIT je Repo, wie Gluons
`modules`). `templates/common/prepare.sh` holt die Repos in beiden Phasen am
gepinnten Commit nach `patch-repos/<name>` neben dem Gluon-Baum, ruft deren
`apply.sh` auf und danach die Skripte hier:

- **pre-update**, vor Gluons `make update`: legt Dateien ab, die
  `make update` auf die Module anwendet.
- **post-update**, danach.

Die Reihenfolge steht nur in `prepare.sh`.

## Inhalt

| Skript | Phase | Zweck |
| --- | --- | --- |
| `build/add-gluon-package-patches.sh` | pre-update | Paketpatch für packages/gluon: `/etc/opkg/keys` beim Autoupdater-Upgrade löschen |
| `bugfixes/fix-respondd-rsk.sh` | post-update | respondd-Listener auf den Gluon-2016.x-Wert; Begründung im Skriptkopf |
| `network/interface-role-migration21.sh` | post-update | Migration 2021: Schnittstellen mit Client-Netz behalten ihre Rolle |
| `build/patch-gluon-makefiles.sh` | post-update | Gluon-Makefile: `GLUON_TARGETS` per override |
| `status-page/statuspage-moredetails.sh` | post-update | Statusseite: weitere MACs und Gluon-Version |
| `status-page/statuspage-ssid.sh` | post-update | Statusseite: SSID, HT-Modus und ssid-changer |
| `status-page/statuspage-hwdetails.sh` | post-update | Statusseite: CPU-Typ, Kernzahl und BIOS |
| `status-page/statuspage-ethlinks.sh` | post-update | Statusseite: Ethernet-Geschwindigkeit je Port |
| `status-page/statuspage-ssidchanger-zaehler.sh` | post-update | Statusseite: Zähler des ssid-changer seit Boot |
| `status-page/statuspage-respondd.sh` | post-update | Statusseite: Werte aus neanderfunk-respondd, live, inkl. Temperatur |
| `status-page/web-static-version.sh` | post-update | Statusseite und Config-Mode: CSS/JS mit Versionsanhang gegen den Browser-Cache |
| `setup-mode-network/setup-mode-hostnames.sh` | post-update | `gluon.setup` und `setup.gluon` per DNS auf 192.168.1.1 |
| `setup-mode-network/setup-mode-captive.sh` | post-update | Portal-Erkennung der Clients führt auf die Setup-Seite |
| `setup-mode-network/setup-mode-wifi.sh` | post-update | dnsmasq an br-setup, Portal-Umleitung (für neanderfunk-setup-wifi) |

**Übergang:** `status-page/` und `setup-mode-network/` gehören zu Paketen aus
[Neanderfunk/packages](https://github.com/Neanderfunk/packages) und ziehen in
ein Repo der Paketverwaltung um. Bis dahin laufen sie von hier.

## Abhängigkeiten

* **`status-page/`** ist eine Kette auf dieselbe Datei: `moredetails` →
  `ssid` → `hwdetails` → `ethlinks` → `ssidchanger-zaehler` → `respondd` →
  `web-static-version`. `statuspage-respondd` braucht das Paket
  `neanderfunk-respondd`; ohne es bleiben die betreffenden Zeilen leer. Die
  Kette läuft nur auf einem frischen Baum durch: Ein zweiter Lauf bricht bei
  `statuspage-hwdetails` ab, weil `statuspage-respondd` dessen Teil
  umgeschrieben hat. `build.sh` setzt den Gluon-Baum vor jedem Lauf zurück.
* **`setup-mode-network/`**: `setup-mode-captive` baut auf
  `setup-mode-hostnames` auf, `setup-mode-wifi` auf beiden;
  `setup-mode-wifi` ist nur mit dem Paket `neanderfunk-setup-wifi` sinnvoll.
* pre-update-Skripte wirken nur, wenn danach `make update` läuft.
