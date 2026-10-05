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
df -h /home/build         # Platz: rund 20 GB Baum + rund 100 GB Images (Schätzung, 58 Sites, tiny + generic)
cd /home/build
git clone -b v2021.x https://github.com/Neanderfunk/FirmwareConfigs.git sackgasse2021.x
cd sackgasse2021.x
docker build -t nf-gluon2021-build scripts/docker
```

## Bauen (alle aktiven Domains)

```sh
cd /home/build/sackgasse2021.x
git pull
tmux new -s sackgasse 'SBRANCH=26MMDDHHsg RELBRANCH=sackgasse scripts/build-local.sh --alle 2>&1 | tee build-alle.log'
```

- `SBRANCH` muss über `24111216sackgasse` sortieren (das Skript prüft das),
  also mit `26` beginnen. Endung frei wählbar (`sg`, `sackgasse`).
- Domains: alle nicht auskommentierten Zeilen in `sites.nefall.sackgasse`
  (Stand 05.10.2026: 29 Domains, je normal und `-key`, 58 Sites).
- Targets: die aktiven aus `targets.conf` (ar71xx-tiny, ar71xx-generic).
- Abkoppeln mit Strg-B d, wieder hinein mit `tmux attach -t sackgasse`.
- Ein Fehler in einer Domain hält den Lauf nicht an; Zusammenfassung in
  `images/<SBRANCH>/build-summary.txt`, Logs `build-<SBRANCH>-<site>-<target>.log`.
- Einzelne Site nachbauen: `SBRANCH=… RELBRANCH=sackgasse scripts/build-local.sh 13_dusfl-key`.

## Ergebnis

`images/<SBRANCH>/<site>/{sysupgrade,factory,other}`, je Site ein
unsigniertes `sackgasse.manifest`. Beim Einspielen auf den Firmware-Server
heißen die Key-Ordner wie in stable `<domain>.key` (Build: `<domain>-key`).
Danach wie in `docs/ueberarbeitung-2026.md` bzw. router-werkstatt
`werkzeug/firmwareserver/` (unterschreiben, zusammenführen mit stable).

## Vor dem Ausrollen

- DNS: `sinope.eol.ffnef.de` und `lysithea.eol.ffnef.de` als CNAME auf
  `sinope.ffnef.de` bzw. `lysithea.ffnef.de` (Reserve-Broker in der site.conf).
- Der Knoten `FF-Dresen-MGER-01` (UniFi AP, 13_dusfl) steckt in der Sackgasse,
  obwohl es für ihn 2025.1 gibt: per nodeplacer bzw. Hand auf stable holen.
