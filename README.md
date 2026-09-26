# Firmware-Repository Eulenfunk / Neanderfunk

Freifunk-Firmware für Freifunk Düsseldorf-Flingern und Freifunk im Neanderland
(Neanderfunk), gebaut mit Gluon. Wie `build.sh` arbeitet, steht ausführlich in
[`docs/build-sh.md`](docs/build-sh.md).

Bis September 2026 hieß dieses Repository `Neanderfunk/firmware`. Alte Links und
Git-Remotes leitet GitHub auf `Neanderfunk/FirmwareConfigs` weiter.

In English: a measurement report on build times and the parallel build mode
(golden tree, rootless overlayfs workers), with raw data, is in
[`docs/parallel-builds/`](docs/parallel-builds/).

## Bauen

### Voraussetzungen

- Die Abhängigkeiten von Gluon 2023.2 (siehe Gluons „Getting Started“), dazu
  `ecdsautils` (signiert die Manifeste), `lua5.1`, `python3` (Collector,
  optional) und `rsync`.
- **Ein Host-Compiler bis GCC 13**, etwa Debian Bookworm. OpenWrt 23.05 baut
  mit GCC ab 14 nicht; auf einem Host mit neuerem GCC (z. B. Ubuntu 26.04) im
  Bookworm-Container bauen, derselbe absolute Pfad innen wie außen.
- Parallelbetrieb (`WORKERS` > 1) braucht zusätzlich rootless overlayfs, siehe
  `docs/build-sh.md`, Kapitel 7.9. Fehlt es, baut `build.sh` seriell und sagt
  das laut.
- `build.sh` prüft das alles vorab und nennt fehlende Teile auf einmal.

### Einrichten

```
git clone https://github.com/Neanderfunk/FirmwareConfigs -b v2023.2.x
cd FirmwareConfigs
```

Den Gluon-Baum (`gluon/`) legt `build.sh` beim ersten Lauf selbst an: ein
voller `git clone` des Branches aus Spalte 2 der Sites-Datei. Eine andere
Quelle, etwa ein lokaler Spiegel, geht über `GLUON_REPO` (Umgebung oder
`build.local.conf`).

### Aufruf

```
./build.sh build.conf targets.conf domains.conf [target ...] [--resume | --restart]
```

| Datei | sagt |
|---|---|
| `build.conf` | *wie* gebaut wird: Version, Aufräumen, `WORKERS`, Baureihenfolge |
| `build.local.conf` | optional, hostspezifisch, nicht im Repo (etwa `WORKERS=6`) |
| `targets.conf` | welche Hardware (`GLUON_TARGETS`, `-` davor schaltet aus) |
| `domains.conf` | welche Domains: `SITES_FILE`, `DOMAINS_INCLUDE`/`EXCLUDE` |
| `sites.*` | die Domains, je Zeile eine, erzeugt aus `templates/` |

Targets auf der Kommandozeile ersetzen die aus `targets.conf`. Ein
abgebrochener Lauf wird mit `--resume` fortgesetzt oder mit `--restart`
verworfen. Die Images landen in `images/images-<epoch>/`, dazu die
Laufdaten in `buildinfo/`.

Sites-Dateien: **Zeilenumbrüche im UNIX-Format**, jede Zeile mit `LF`
abgeschlossen.

## Branches
experimental und stable 

- **experimental** der Kanal `experimental` und **stable* ist Kanal `stable`

- es gibt noch den zusätzlichen _Bau-Stand_ **key** (z.B. **stable/stablekey**) in der "bypassconfigmode" und mehrere ssh-keys der Admins gesetzt sind. Diese Firmware wird auschließlich für Administratoren gebaut und ist ohne Rücksprache nicht zu verwenden!

## Signaturen
Der Buildbot unterschreibt die Firmware mit einem private-key, der öffentlich ist. Dieses ist nur eine Absicherung des Downoad-Transportweges, keine für Firmware-Integrität. 
Auf den Releasechannels "experimental" ist die Minimum-Valid-Signatures auf 2 gesetzt (d.h. mindestens eine "reale" Maintainer-Signature), für "stable" steht sie auf 3, d.h. 2 trusted Signaturen notwendig.

## Development

Syntax von `site.conf` und `image-customization.lua` der Templates in
Sekunden prüfen, ohne Bau (die semantische Prüfung macht Gluon beim `make`):

    tests/check-site-conf.sh

`build.sh` ruft sie vor jedem Lauf selbst auf.
