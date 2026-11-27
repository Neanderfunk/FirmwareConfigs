# Sackgasse auf dem Buildhost bauen (neben 2025.1)

Stand 05.10.2026. Der Sackgassen-Bau (Gluon v2021.1.x, OpenWrt 19.07) läuft in
einem Docker-Container mit Ubuntu 20.04, weil 19.07 mit aktuellen
Host-Compilern nicht baut. Er bekommt ein eigenes Verzeichnis mit eigenem
Gluon-Baum; der 2025.1-Baum (`/home/build/firmware2025.1.x`) und das
ParallelBuildsystem bleiben unberührt, keine gemeinsame Toolchain, kein
Branch-Wechsel.

## Einmalig einrichten

```sh
docker --version          # fehlt Docker: Admin installiert docker.io und nimmt build in die Gruppe docker
df -h /home/build         # Platz: rund 20 GB Baum + rund 100 GB Images (Schätzung, 60 Sites, tiny + generic)
cd /home/build
git clone -b v2021.x https://github.com/Neanderfunk/FirmwareConfigs.git sackgasse2021.x
cd sackgasse2021.x
sg docker -c 'docker build -t nf-gluon2021-build scripts/docker'
```

## Bauen (alle aktiven Domains)

Seit 27.11.2026 mit einem Aufruf aus dem ParallelBuildsystem, als `build`,
im Vordergrund des eigenen Fensters (kein tmux mehr):

```sh
/home/build/ParallelBuildsystem/scripts/bau sackgasse
```

Es bricht ab, wenn schon ein Bau läuft (`build.lock`) oder versionierte
Dateien lokal geändert sind, pullt, prüft gegen `git ls-remote`, setzt
`SBRANCH=<JJMMTTHH>sg` (oder `SBRANCH=<name>` davor) und startet
`sg docker -c '... scripts/build-local.sh --alle 2>&1 | tee build-alle.log'`.
Abbrechen mit Strg-C in diesem Fenster. Von Hand geht es weiter so:

```sh
cd /home/build/sackgasse2021.x
git pull
sg docker -c 'SBRANCH=26MMDDHHsg RELBRANCH=sackgasse scripts/build-local.sh --alle 2>&1 | tee build-alle.log'
```

- `SBRANCH` muss über `24111216sackgasse` sortieren (das Skript prüft das),
  also mit `26` beginnen. Endung frei wählbar (`sg`, `sackgasse`).
- Domains: alle nicht auskommentierten Zeilen in `sites.nefall.sackgasse`
  (Stand 06.10.2026: 30 Domains, je normal und `-key`, 60 Sites).
- Targets: die aktiven aus `targets.conf` (ar71xx-tiny, ar71xx-generic).
- `sg docker` (05.10.2026 auf horst noetig): Trotz Gruppe docker scheiterte
  der Aufruf mit "permission denied ... docker.sock", wenn die Shell per `su`
  kam oder ein aelterer tmux-Server die Sitzung startet; `sg` setzt die Gruppe
  fuer genau diesen Aufruf. Ebenso `sg docker -c 'docker build ...'`.
- Ohne tmux (adorfer 27.11.2026): Mit Sackgasse und Multi gleichzeitig traf
  `tmux kill-session` den falschen Lauf.
- Ein Fehler in einer Domain hält den Lauf nicht an; Zusammenfassung in
  `images/<SBRANCH>/build-summary.txt`, Logs `build-<SBRANCH>-<site>-<target>.log`.
- Einzelne Site nachbauen: `SBRANCH=… RELBRANCH=sackgasse scripts/build-local.sh 13_dusfl-key`.

## Ergebnis

`images/<SBRANCH>/<site>/{sysupgrade,factory,other,site}`, je Site ein
unsigniertes `sackgasse.manifest`. `site/` ist die zusammengebaute Site, mit
der Gluon gebaut hat (seit 27.11.2026; vorher lag sie nur in `assembled/<site>/`,
und das überschreibt jeder Bau). Für einen älteren Lauf nachtragen, mit dem
Checkout auf dem Stand des Laufs:

```sh
[ "$(hostname -s)" = wir-horst ] && cd /home/build/sackgasse2021.x && sg docker -c 'SBRANCH=<lauf> RELBRANCH=sackgasse scripts/build-local.sh --nur-site --alle'
```

Das baut nur die Sites neu zusammen und fasst `gluon/` nicht an. Geprüft am
27.11.2026 für 18_nefuk von 24112323sackgasse: Die nachgetragene `site.conf`
gleicht der `site.json` im Image bis auf das leere `authorized_keys`, das
Gluon weglässt. Beim Einspielen auf den Firmware-Server
heißen die Key-Ordner wie in stable `<domain>.key` (Build: `<domain>-key`).
Danach wie in `docs/ueberarbeitung-2026.md` bzw. router-werkstatt
`werkzeug/firmwareserver/` (unterschreiben, zusammenführen mit stable).

Hochladen auf den Firmware-Server mit `signup-alle` aus dem
ParallelBuildsystem (ab 27.11.2026). Hochladen geht als `adorfer` (SSH-Key für
`firmware6`), die Checkouts pullt `build`; Pull und Upload deshalb getrennt
aufrufen. Es nimmt den jüngsten Lauf mit
`sackgasse.manifest`, unterschreibt je Site und schiebt ein 7z je Site
(`<site>-<zeit>-<SBRANCH>.7z`) ins Home-Verzeichnis auf `firmware6.ffnef.de`:

```sh
[ "$(hostname -s)" = wir-horst ] && cd /home/build/sackgasse2021.x && ../ParallelBuildsystem/scripts/signup-alle --sackgasse
```

Einen bestimmten Lauf mit `--lauf <SBRANCH>`, einzelne Domains durch ihren
Namen dahinter (`02_met` trifft auch `02_met-key`). Was schon oben liegt,
wird übersprungen.

## Vor dem Ausrollen

- DNS: `sinope.eol.ffnef.de`, `lysithea.eol.ffnef.de`, `carme.eol.ffnef.de`
  und `ananke.eol.ffnef.de` als CNAME auf den jeweiligen Namen unter
  `ffnef.de` (Reserve-Broker in der site.conf, carme und ananke seit 14.11.2026).
  Solange die Ziele selbst keinen DNS-Eintrag haben, ist das Vorrat.
  Die vier CNAMEs sind seit 14.11.2026 eingetragen (adorfer).
- Der Knoten `FF-Dresen-MGER-01` (UniFi AP, 13_dusfl) steckt in der Sackgasse,
  obwohl es für ihn 2025.1 gibt: per nodeplacer bzw. Hand auf stable holen.
