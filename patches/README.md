# patches/ – Neanderfunk-eigene Änderungen an Gluon

*Patches for Gluon v2025.1.x used only by Freifunk Neanderland. Patches that
are useful to others live in their own repositories, see below.*

## Wo die Patches liegen

Seit 27.09.2026 sind die Patches nach Nutzen für Dritte getrennt:

| Repo | Inhalt |
| --- | --- |
| [Neanderfunk/gluon-patches-hardware](https://github.com/Neanderfunk/gluon-patches-hardware) | zusätzliche Geräte und Targets, Geräte-Korrekturen, Treiber, primäre MACs |
| [Neanderfunk/gluon-patches-fixes](https://github.com/Neanderfunk/gluon-patches-fixes) | lowmem, allgemeine Fehlerbehebungen, Config-Mode-Wizard, Outdoor-Schalter, Paketpatches für Airtime und ffac |
| [Neanderfunk/gluon-patches-packages](https://github.com/Neanderfunk/gluon-patches-packages) | Statusseite und Setup-Mode-Netz; nur mit den Paketen aus [Neanderfunk/packages](https://github.com/Neanderfunk/packages) sinnvoll |
| dieses Verzeichnis | was nur für Neanderfunk Sinn ergibt |

Welche Stände gebaut werden, steht in der Pin-Datei
`templates/common/patchrepos` (REPO, BRANCH und COMMIT je Repo, wie Gluons
`modules`). `templates/common/prepare.sh` holt die Repos in pre-update am
gepinnten Commit nach `patch-repos/<name>` neben dem Gluon-Baum und ruft in
beiden Phasen erst deren `apply.sh` auf, dann die Skripte hier:

- **pre-update**, vor Gluons `make update`: legt Dateien ab, die
  `make update` auf die Module anwendet.
- **post-update**, danach.

Die Reihenfolge steht nur in `prepare.sh`.

## Inhalt

| Skript | Phase | Zweck |
| --- | --- | --- |
| `build/add-gluon-package-patches.sh` | pre-update | Paketpatch für packages/gluon: `/etc/opkg/keys` beim Autoupdater-Upgrade löschen |
| `bugfixes/fix-respondd-rsk.sh` | post-update | respondd-Listener auf den Gluon-2016.x-Wert; Begründung im Skriptkopf |
| `build/patch-gluon-makefiles.sh` | post-update | Gluon-Makefile: `GLUON_TARGETS` per override |

## Abhängigkeiten

* pre-update-Skripte wirken nur, wenn danach `make update` läuft.
