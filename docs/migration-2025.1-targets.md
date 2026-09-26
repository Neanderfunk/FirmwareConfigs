# Targets und Geräte beim Umstieg 2023.2.x → 2025.1.x

Bestandsaufnahme, Stand 2026-09-05. **Nur Analyse, nichts umgesetzt.**

> **Lies zuerst Kapitel 0.** Der maßgebliche Vergleich sind die Modellnamen im
> Autoupdater-Manifest, nicht die Target- oder Boardnamen. Ändert sich der Name,
> findet ein Bestandsknoten sein Update nicht mehr.

## Umfang

Betrachtet wird, was bei der Migration **Probleme machen kann**. Zwei Gruppen sind
darum ausdrücklich ausgenommen:

* **Geräte, die nicht im Feld sind.** Was nirgends läuft, kann auch keinen Update-Pfad
  verlieren. Solche Geräte tauchen hier nur nachrichtlich auf, damit klar ist, was
  beim Wegfall eines Patches an Baubarkeit verloren ginge.
* **Die Sackgassen-Geräte auf v2021.1.2.** Rund 231 Knoten der 4/32-Klasse
  (TP-Link WR841N/ND v8–v11 und Verwandte) hängen dort fest, weil Gluon diese Hardware
  **schon vor 2023.2** fallen gelassen hat — in 2023.2 existiert nur noch
  `tp-link-tl-wr841n-v13`. Das ist mit einem Versionswechsel nicht lösbar und hat mit
  2025.1 nichts zu tun. Eigenes Thema — untersucht in
  [`4-32-machbarkeit.md`](4-32-machbarkeit.md).

## 0. Manifest-Namen — der entscheidende Vergleich

### Warum dieser Name zählt

`scripts/generate_manifest.lua` schreibt je Sysupgrade-Image die Zeile

```
<model> <release> <sha256> <größe> <dateiname>
```

`model` ist das **erste Argument von `device(image, board, options)`**, also der
Gluon-Imagename — nicht der OpenWrt-Boardname. Zusätzlich entsteht je eine Zeile für
jeden Eintrag in `options.aliases` und `options.manifest_aliases`; letzteres ist genau
der Mechanismus, mit dem Gluon Umbenennungen abfedert.

Der Knoten meldet denselben Namen. Auf dem Testknoten COVR-X1860 live geprüft:

```
image_name: d-link-covr-x1860-a1        (Board wäre: dlink,covr-x1860-a1)
```

Ein Knoten sucht sich also im Manifest über den Namen, der in **sein** Image
einkompiliert wurde. Fehlt dieser Name im neuen Manifest, bekommt er keine Updates
mehr — er fällt still aus dem Autoupdater.

### Datengrundlage

Verglichen wurde das **echte Manifest eures Baus**
(`images-1788320276`, Domain 05_mon, broken, 253 Modellnamen) gegen die vollständige
Namensmenge von Gluon 2025.1 (363 Namen aus 328 Geräten, inklusive aller Aliase).

Nebenbefund: Gluon hat kräftig ausgemistet — 2023.2.x führt 81 Aliase, 2025.1.x nur
noch 35.

### Ergebnis: 61 Namen aus eurem Manifest fehlen in 2025.1

**a) 12 Namen — kommen mit dem Forward-Port zurück**

Eure eigenen Patch-Geräte und die von euch vergebenen Aliase. Da ihr die Namen selbst
bestimmt, sind sie nach dem Nachziehen unverändert wieder da:

`cudy-ap3000-v1`, `cudy-m1800`, `cudy-tr3000-256mb-v1`, `tp-link-eap225-wall-v2`,
`zte-mf286r`, `zyxel-nbg6616`, `mikrotik-routerboard-750gr3`,
`mikrotik-routerboard-mapl-2nd`, `mikrotik-routerboard-wap-g-5hact2hnd`
sowie deren Aliase `mikrotik-routerboard-hex-v3`, `mikrotik-routerboard-map-lite`,
`mikrotik-routerboard-wap-ac-t2`.

**b) 1 Name — echter Konflikt, Handlungsbedarf**

| | |
|---|---|
| euer Name | `cudy-ap3000outdoor-v1` |
| Gluon 2025.1 | `cudy-ap3000-outdoor-v1` |

Gleiches Board (`cudy_ap3000outdoor-v1`), abweichender Imagename, **kein Alias**.
Übernehmt ihr die Upstream-Definition, verlieren bereits ausgelieferte Cudy AP3000
Outdoor ihren Update-Pfad.

Abhilfe: `manifest_aliases = {'cudy-ap3000outdoor-v1'}` an der Upstream-Definition
ergänzen. Besser upstream einreichen als lokal patchen — andere Communities mit
demselben Gerät haben dasselbe Problem.

**c) 48 Namen — von Gluon aufgegebene Legacy-Aliase**

Alte Schreibweisen, die Gluon 2023.2 noch als `manifest_aliases` mitgeschleppt hat und
2025.1 nicht mehr führt: die ganze `openmesh-*`-Familie, `tp-link-cpe210-v1.0` und
Verwandte, `tp-link-tl-wr1043n-nd-v*`, `ubnt-erx`, `ubnt-erx-sfp`, `x86-kvm`,
`x86-xen_domu`, `zbt-wg3526*`, `netgear-wndr3700v2`, `d-link-dir-505-rev-a*` und
weitere.

**Diese Namen betreffen nur Knoten, die noch mit sehr alter Firmware laufen.** Ein
Knoten, der seit 2023.2 mindestens einmal aktualisiert wurde, meldet den heutigen
Primärnamen — und der existiert in 2025.1 weiterhin. Geprüft: es gibt **keine einzige**
Upstream-Umbenennung zwischen 2023.2 und 2025.1, bei der der Primärname wechselt, ohne
dass ein Alias den alten abfängt.

Diese Kategorie ist damit kein Migrationsblocker, aber ein Restrisiko für
Karteileichen. Gluon 2025.1 unterstützt ohnehin nur Upgrades ab v2022.1.

### Abgleich mit dem Feld — und damit die Entwarnung

Datenquelle: `https://map.eulenfunk.de/data/nodes.json`, 1199 Knoten, davon 1115 online
(Stand 2026-09-05). `https://map.ffdus.de/data/nodes.json` liefert dagegen nur
`{"version":null,"nodes":null}` und ist unbrauchbar.

**835 Knoten melden ein `image_name`** — durchweg die auf v2023.2.5. Sie verteilen sich
auf **67 verschiedene Namen**, und davon fehlt in Gluon 2025.1:

> **kein einziger.**

Sieben der 67 stammen aus euren Patches, und alle sieben sind in 2025.1 bereits
upstream:

| Imagename | Knoten |
|---|---|
| `totolink-x5000r` | 13 |
| `cudy-wr3000e-v1` | 6 |
| `cudy-wr3000h-v1` | 4 |
| `tp-link-archer-ax23-v1` | 2 |
| `cudy-wr3000s-v1` | 1 |
| `mercusys-mr90x-v1` | 1 |
| `cudy-tr3000-v1` | 1 |

**Für ausgeliefertes Gerät ist also kein einziger Forward-Port nötig.** Die 15 Geräte
aus Kapitel 2.2 betreffen ausnahmslos Hardware, die ihr derzeit nicht im Feld habt.

Auch der Namenskonflikt aus (b) entschärft sich: `cudy-ap3000outdoor-v1` kommt im Feld
**nicht** vor. Er ist ein Risiko für die Zukunft — solltet ihr AP3000 Outdoor noch unter
2023.2 ausrollen, entsteht das Problem. Vorher migrieren, oder gleich den
Upstream-Namen verwenden.

### Die restlichen 364 Knoten — außerhalb des Umfangs

Sie melden kein `image_name`. 76 davon sind gar keine Gluon-Knoten (Basis `Ubuntu`,
Modell `KVM VirtualMachine` — Gateways). Die übrigen 279 laufen auf v2021.1.2 oder
älter, davon 231 auf der 4/32-Klasse. Siehe **Umfang** oben: nicht lösbar, nicht Teil
dieser Betrachtung.

Damit erledigt sich auch Kategorie (c): die 48 aufgegebenen Legacy-Aliase betreffen
ausschließlich Knoten aus dieser Gruppe.

## Kurzfassung

| | |
|---|---|
| Targets in `targets.conf` | 31 (8 aktiv, 23 mit `-` deaktiviert) |
| Von euren Patches ergänzte Geräte | **34** |
| davon in Gluon 2025.1 bereits upstream | **19** — Patch entbehrlich |
| davon nachzuziehen | **15** — aber **alle 15 in OpenWrt 24.10 vorhanden**, also je eine `device()`-Zeile |
| **Im Feld tatsächlich betroffen** | **0 Geräte** — alle 67 Imagenamen der 835 Knoten auf v2023.2.5 kennt 2025.1 |
| Targets, die entfallen | **1** (`realtek-rtl838x`) |
| Geräte, die entfallen | **2** |
| Als „deprecated" markierte Geräte | **0** in beiden Zweigen |

Die Sorge „einige Targets fallen weg, weil sie nicht mehr in den Speicher passen"
bestätigt sich für diesen Schritt **nicht**. Gluon kennt zwar `GLUON_DEPRECATED`
(eure `site.mk` setzt `full`), aber weder 2023.2.x noch 2025.1.x markieren auch nur
ein einziges Gerät als deprecated. Der große Flash-Kahlschlag lag vor 2023.2.

Der Aufwand liegt woanders: beim Target-Rename `ipq807x-generic` →
`qualcommax-ipq807x` und bei `mi4ag-migration.patch`. Der zbit-Flash-Patch, zunächst
als größte Baustelle eingeschätzt, ist unter Kernel 6.6 aller Voraussicht nach
entbehrlich — siehe 4.1.

## Methode

Verglichen wurden die Git-Stände `v2023.2.x` (`cd304be`) und `v2025.1.x` (`0ad3ad5`)
von `freifunk-gluon/gluon`, dazu OpenWrt am von Gluon 2025.1 gepinnten Commit
`a1ea57bd` (24.10, Kernel 6.6).

Geräte wurden über die `device('name', 'board')`-Einträge in `targets/*` erfasst und
über den **OpenWrt-Boardnamen** abgeglichen, nicht über den Gluon-Namen — der kann
sich unterscheiden. Vollzähligkeit geprüft: 268 von 268 bzw. 328 von 328
`device(`-Zeilen erfasst.

Für die 15 fehlenden Geräte wurde gegen **alle** Image-Makefiles des jeweiligen
OpenWrt-Targets geprüft, nicht nur gegen `generic.mk`. Das war nötig: TP-Link-Geräte
liegen in `generic-tp-link.mk`, und eine erste, unvollständige Prüfung hätte zwei
Geräte fälschlich als „in OpenWrt nicht vorhanden" gemeldet.

## 1. Target-Ebene

Von euren 31 Targets existieren 29 unverändert in 2025.1. Drei Sonderfälle:

| Target | Befund | Zu tun |
|---|---|---|
| `realtek-rtl838x` | in 2025.1 **entfallen** | Zeile aus `targets.conf` streichen. Bei euch ohnehin deaktiviert; einziges Gerät war die D-Link DGS-1210-10P |
| `ipq40xx-chromium` | von euch gepatcht, jetzt **upstream** | Patch entfernen, Target bleibt in `targets.conf` |
| `ipq807x-generic` | **umbenannt** zu `qualcommax-ipq807x` | In `targets.conf` umbenennen, Patch entfernen |

Neu in 2025.1 und für euch bisher ohne Bedeutung: `kirkwood-generic`,
`lantiq-xrx200_legacy`, `mvebu-cortexa53`.

## 2. Geräte-Ebene

### 2.1 Bereits upstream — 19 Geräte, Patches entbehrlich

| Target | Gerät |
|---|---|
| ath79-generic | tp-link-eap225-outdoor-v3 |
| ipq40xx-chromium | google-wifi-gale |
| ipq40xx-generic | linksys-mr8300-dallas |
| qualcommax-ipq807x | xiaomi-ax3600 *(Target umbenannt)* |
| lantiq-xrx200 | avm-fritz-box-7430 |
| mediatek-filogic | cudy-ap3000outdoor-v1, cudy-m3000-v1, cudy-re3000-v1, cudy-tr3000-v1, cudy-wr3000e-v1, cudy-wr3000h-v1, cudy-wr3000s-v1, mercusys-mr90x-v1 |
| mediatek-mt7622 | netgear-wax206, ubiquiti-unifi-6-lr-v2, ubiquiti-unifi-6-lr-v3 |
| ramips-mt7621 | totolink-x5000r, tp-link-archer-ax23-v1, ubiquiti-unifi-nanohd |

### 2.2 Nachzuziehen — 15 Geräte, alle in OpenWrt 24.10 vorhanden

| Target | Gerät | OpenWrt-Board |
|---|---|---|
| ath79-generic | tp-link-eap225-wall-v2 | `tplink_eap225-wall-v2` |
| ath79-generic | zyxel-nbg6616 | `zyxel_nbg6616` |
| ath79-mikrotik | mikrotik-routerboard-mapl-2nd | `mikrotik_routerboard-mapl-2nd` |
| ath79-mikrotik | mikrotik-routerboard-wap-g-5hact2hnd | `mikrotik_routerboard-wap-g-5hact2hnd` |
| ath79-nand | zte-mf286r | `zte_mf286r` |
| ipq40xx-generic | avm-fritz-repeater-3000 | `avm_fritzrepeater-3000` |
| ipq40xx-generic | linksys-ea8300-dallas | `linksys_ea8300` |
| ipq40xx-mikrotik | mikrotik-wap-ac | `mikrotik_wap-ac` |
| qualcommax-ipq807x | netgear-wax218 | `netgear_wax218` |
| lantiq-xrx200 | avm-fritz-box-3390 | `avm_fritz3390` |
| mediatek-filogic | cudy-ap3000-v1 | `cudy_ap3000-v1` |
| mediatek-filogic | cudy-tr3000-256mb-v1 | `cudy_tr3000-256mb-v1` |
| ramips-mt7621 | cudy-m1800 | `cudy_m1800` |
| ramips-mt7621 | mikrotik-routerboard-750gr3 | `mikrotik_routerboard-750gr3` |
| rockchip-armv8 | friendlyelec-nanopi-r2c | `friendlyarm_nanopi-r2c` |

Weil alle Boards in OpenWrt existieren, ist der Forward-Port jeweils **eine Zeile**
in der Gluon-Target-Datei. Kein Bedarf an DTS-Dateien oder Kernel-Arbeit.

Auffällig: Gluon 2025.1 kennt `cudy-ap3000outdoor-v1`, aber nicht `cudy-ap3000-v1`,
obwohl beide DTS in OpenWrt liegen. Sieht nach Versehen upstream aus — wäre ein
Kandidat für einen Beitrag zurück an Gluon statt für einen lokalen Patch.

### 2.3 Was entfällt

Nur zwei Geräte verschwinden zwischen 2023.2.x und 2025.1.x:

* `ubiquiti-nanobeam-m5-xw` (ath79-generic)
* `d-link_dgs-1210-10p` (realtek-rtl838x, mit dem ganzen Target)

Beide sind bei euch nicht im Einsatz, soweit aus `targets.conf` ersichtlich —
`realtek-rtl838x` ist deaktiviert.

## 3. Patch für Patch

### Entfallen vollständig

| Patch | Grund |
|---|---|
| `targets-mk.patch` | beide Registrierungen upstream (`ipq40xx-chromium`, `qualcommax-ipq807x`) |
| `targets-ipq40xx-chromium.patch` | Target und Gerät upstream |
| `targets-mediatek-mt7622.patch` | alle drei Geräte upstream |
| `add-cudy-3000-openwrt.patch` | alle neun DTS in OpenWrt 24.10 vorhanden (dort inzwischen 14 Cudy-DTS) |
| `add-cudy-3000-singleeth-openwrt.patch` | alle sieben `cudy,*`-Einträge in `05_set_preinit_iface` upstream |
| `add-mercusys-mr90x-gluon.patch` | Gerät upstream |
| `targets-ipq40xx-mirotik.patch` | ungenutzte Dublette mit Tippfehler im Namen; `additionaltargets.sh` ruft die korrekt geschriebene Datei auf |
| `999-silence-missing-rate.patch` | entspricht Gluons eigenem `0005-mac80211-silence-warning-for-missing-rate-information.patch` (bei euch ohnehin nicht aktiv) |

### Schrumpfen auf die Restgeräte

| Patch | vorher | bleibt |
|---|---|---|
| `targets-ath79-generic.patch` | 3 | 2 (eap225-wall-v2, zyxel-nbg6616) |
| `targets-ipq40xx-generic.patch` | 3 | 2 (fritz-repeater-3000, ea8300-dallas) |
| `targets-ramips-mt7621.patch` | 4 | 2 (cudy-m1800, rb750gr3) |
| `add-cudy-3000-gluon.patch` | 9 | 2 (ap3000-v1, tr3000-256mb-v1) |
| `targets-lantiq-xrx200-devices.patch` | 2 | 1 (fritz-box-3390) |
| `targets-ipq807x-generic.patch` | 2 | 1 (wax218), **auf `qualcommax-ipq807x` umschreiben** |

### Bleiben unverändert nötig

`targets-ath79-mikrotik.patch` (2 Geräte), `targets-ath79-nand.patch` (zte-mf286r),
`targets-ipq40xx-mikrotik.patch` (wap-ac), `add-nanopi-r2c` (nanopi-r2c).

`targets-ipq40xx-mikrotik.patch` ändert zusätzlich `platform.lua`: es trägt
`mikrotik,routerboard-wap-g-5hact2hnd` und `mikrotik,wap-ac` in die Outdoor-Geräteliste
ein. Beide fehlen in 2025.1 weiterhin, der Teil muss also mit. `cudy,ap3000outdoor-v1`
steht dort inzwischen upstream.

## 4. Die eigentlichen Baustellen

### 4.1 zbit-Flash-Patch — mit hoher Wahrscheinlichkeit entbehrlich

`add-totolink-x5000r.sh` legt `412-mtd-spi-nor-add-support-for-zbit-zb25vq128.patch`
in `target/linux/ramips/patches-5.15/` ab. Er stammt von Daniel Palmer, wurde
2021-09-18 an linux-mtd geschickt und ergaenzt die JEDEC-ID des Zbit ZB25VQ128
(`5e 40 18`), den Totolink ab Baujahr 2022 verbaut.

**Recherchiert am 2026-09-05:**

* Der Patch ist **nie in den Linux-Kernel gelangt** — weder in 6.6 noch in der
  aktuellen Mainline gibt es `drivers/mtd/spi-nor/zbit.c`, und weder `core.c` noch
  `core.h` erwaehnen `zbit` oder `zb25`.
* In OpenWrt lief er als PR #12396 („ramips: add linux 5.15 and 5.10 support for Zbits
  ZB25VQ128 SPI-NOR on Totolink X5000R", 2023-04-14). Der PR wurde **nach einem Tag
  ohne Kommentar geschlossen**, nicht gemerged.
* Eine Fassung gegen Kernel 6.6 existiert nirgends.

**Sie wird aller Voraussicht nach auch nicht gebraucht.** Kernel 6.6 hat einen
generischen Rueckfall eingebaut, den 5.15 und 6.1 noch nicht kannten:

```c
/* Fallback to a generic flash described only by its SFDP data. */
if (!info) {
        ret = spi_nor_check_sfdp_signature(nor);
        if (!ret)
                info = &spi_nor_generic_flash;
}
```

Ist die JEDEC-ID unbekannt, aber liefert der Chip gueltige SFDP-Tabellen, laeuft er
ueber `spi-nor-generic`. Die Kernel-Doku sagt dazu: *„For flashes that define SFDP
tables, you likely won't need a flash entry at all."* Genau das Fehlen dieses Rueckfalls
machte den Patch unter 5.15 noetig.

Geprueft: `spi_nor_generic_flash` kommt in Linux 5.15 und 6.1 **nicht** vor, in 6.6
**doch**.

**Restunsicherheit:** Ob der ZB25VQ128ASIG gueltige SFDP-Tabellen liefert, liess sich
nicht belegen — nur Chips ganz ohne SFDP fallen weiterhin durch. Bei einem Baustein
dieser Generation ist SFDP praktisch Standard.

**Billig zu klaeren, noch vor der Migration.** Auf einem der 13 X5000R im Feld:

```
dmesg | grep -i spi-nor
```

Steht dort ein konkreter Chipname, ist die ID bekannt und die Frage erledigt. Steht
dort `spi-nor-generic`, greift bereits heute der SFDP-Weg. Und zeigt der Chip sich als
Winbond oder XMC statt Zbit, betrifft euch die Sache ohnehin nicht — im
OpenWrt-Forum berichtet ein Nutzer genau das fuer seine Geraete.

**Empfehlung:** den Patch beim Umstieg **ersatzlos streichen** und beim ersten Testbau
einen X5000R gegenpruefen. Ein Rebase des 5.15-Patches auf 6.6 waere ohnehin Handarbeit,
weil sich die spi-nor-API dazwischen geaendert hat.

### 4.2 `mi4ag-migration.patch`

Ändert `package/base-files/files/lib/upgrade/fwtool.sh` und
`target/linux/ramips/image/mt7621.mk`. Beide Dateien haben sich zwischen 23.05 und
24.10 bewegt; der Patch ist gegen 24.10 neu zu prüfen. Nicht analysiert, weil er die
Sysupgrade-Logik betrifft und nicht die Target-Auswahl.

### 4.3 Der `patch -R`-Mechanismus — **erledigt**

*Ausgangslage:* Alle Patch-Skripte prüften per Rückwärts-Trockenlauf, ob schon
angewendet, und schwiegen bei Fehlschlag; `prepare.sh` endete mit `exit 0;`. Bei einem
Sprung über eine Hauptversion wären scheiternde Patches damit nicht aufgefallen — es
wäre still eine Firmware entstanden, in der die Hälfte der Geräte fehlt.

*Umgesetzt:* `patches/lib-patch.sh` enthält das Muster aus `statuspage-ssid.sh` jetzt
einmal für alle: gequotete Pfade, Vorabprüfungen, `patch -f`, geprüftes Ergebnis im
Zielbaum, Abbruch mit Exit-Code. Alle vierzehn aktiven Skripte nutzen es. `prepare.sh`
ruft sie über `run_patch` auf, prüft jeden Rückgabewert und bricht beim ersten Fehler
unter Nennung des Skripts ab; das `exit 0;` ist weg. `build.sh` läuft mit `errexit`
und `pipefail`, der Abbruch kommt also auch durch die `tee`-Pipe an.

Drei Nebenbefunde aus der Umstellung:

- `interface-role-migration21.sh` prüfte auf `client or client`. Diesen Text gibt es in
  `021-interface-roles` nicht; der grep schlug seit jeher fehl, nur sah es niemand.
- In `additionaltargets.sh` nehmen die Aufrufe unter „adding RPI4" und „adding AVM
  FB7430" dieselbe Patchdatei wie der jeweils darüber. Beide sind Wiederholungen und
  folgenlos, stehen aber jetzt kommentiert da.
- Der Rückwärts-Trockenlauf schlägt auch dann fehl, wenn ein **späterer** Patch dieselbe
  Stelle noch einmal ändert — `statuspage-ssid` und `-hwdetails` setzen genau so auf
  `statuspage-moredetails` auf. Ein zweiter Lauf von `prepare.sh` hätte deshalb
  abgebrochen. `apply_patch` prüft daher zusätzlich, ob das Merkmal des Patches schon
  im Baum steht.
- **`.orig`-Dateien landeten in der Firmware.** `patch` legt bei jedem Hunk-Versatz eine
  Sicherungskopie neben der Zieldatei an, und `Gluon/Build/Install` kopiert
  `package/*/files/.` und `luasrc/.` vollständig ins Image. Im Sysupgrade-Image vom
  2026-09-04 stecken `/lib/gluon/upgrade/020-interfaces.orig` (ausführbar),
  `/lib/gluon/status-page/view/status-page.html.orig` und
  `/usr/lib/lua/gluon/platform.lua.orig`. Die erste lief mit: `gluon-reconfigure`
  arbeitet das Verzeichnis per `for script in *` ab, `.orig` sortiert hinter das
  Original, und die ungepatchte Fassung setzte `sysconfig.lan_ifname`/`wan_ifname`
  wieder auf die `board.json`-Vorgabe. Betroffen sind die Geräte, für die
  `020-interfaces.patch` überhaupt existiert — im Feld neun Knoten (2× FRITZ!Box 7530,
  3× 7360 V2, 1× 7360 SL, 3× 7362 SL). Behoben mit `--no-backup-if-mismatch` plus
  Aufräumen der Altbestände, die `git reset --hard` als unversionierte Dateien stehen
  lässt.

Für die Migration heißt das: ein Patch, der gegen 2025.1 nicht mehr passt, hält den Bau
an der Stelle an, an der er scheitert, statt ihn stillschweigend weiterlaufen zu lassen.

### 4.4 Der MIPS-TLB-Patch — zu pruefen, nicht blind fallenzulassen

`kernel/999-mips-tlb-r4k-no-uniquify.patch` (Neanderfunk/gluon-patches-hardware) nimmt in 5.15.198 den Aufruf von
`r4k_tlb_uniquify()` aus `r4k_tlb_configure()` heraus. Ohne ihn bleibt der
Kernel auf MIPS 74Kc beim **Kaltstart** in `tlb_init()` stehen — Warmstarts und
sysupgrades ueberstehen die Geraete, der erste Stromausfall nicht. Belegt an
serieller Konsole auf TL-WR1043ND v2 (QCA9558) und Archer C25 v1 (QCA956X),
Begruendung und Messwerte stehen im Kopf der Patchdatei.

**Recherchiert am 2026-09-08.** Der 6.6-Zweig hat nach dem Ausloeser fuenf
Nacharbeiten bekommen, 5.15 nur die erste:

```
d98b34c40dc7  2025-06-07  Uniquify TLB entries on init                    Ausloeser
135713cd0751  2025-11-13  Prevent a TLB shutdown on initial uniquification  auch in 5.15
231ac951faba  2025-11-28  kmalloc tlb_vpn array to avoid stack overflow     nur 6.6
43fa022b56dc  2026-03-10  Allocate tlb_vpn array atomically                 nur 6.6
591f030449ad  2026-04-10  Suppress TLB uniquification on EHINV hardware     nur 6.6
811b3dccfb0a  2026-04-10  Rewrite TLB uniquification for the hidden bit …   nur 6.6
```

Genau deshalb haengt 5.15.198 trotz des enthaltenen "Fix" weiter.

**Innerhalb der 2025.1-Serie unterscheiden sich die Kernel erheblich:**

| Gluon | OpenWrt-Pin | Kernel | Shutdown-Fix | kmalloc | EHINV | Neufassung |
| --- | --- | --- | --- | --- | --- | --- |
| v2025.1 | `b023a06cfb88` | 6.6.119 | ja | ja | **nein** | **nein** |
| v2025.1.1 | `14a27ac99d62` | 6.6.137 | ja | ja | ja | ja |
| v2025.1.2 / .3 | `5204715d1420` | 6.6.144 | ja | ja | ja | ja |

**Ziel ist damit 2025.1.1 oder neuer.** v2025.1 selbst traegt dieselbe
Generation wie unser 5.15.198 plus die kmalloc-Korrektur — also gerade die
Fassung, die bei uns nachweislich haengt.

**Die EHINV-Abkuerzung rettet uns nicht.** `591f030449ad` ueberspringt die
Uniquifizierung auf Hardware mit EHINV. Aus dem Quelltext von 6.6.144:

> "This size might not be supported with R6, but EHINV is mandatory for R6, so
> we won't ever be called in that case."

EHINV ist ein R6-Merkmal, unsere 74Kc sind MIPS32r2. Auf 2025.1 laufen unsere
Geraete also **weiterhin durch den Uniquify-Pfad**, nur durch eine reifere
Fassung — nicht daran vorbei.

**Kein Backport nach 5.15.** Geprueft und verworfen: die Neufassung stuetzt
sich auf `current_cpu_data.vmbits` (5.15 hat `cpu_vmbits`), `VPN2_SHIFT`,
einen eigenen `struct tlbent`, `memblock_alloc_raw` und `slab_is_available` —
nichts davon steht in der 5.15-Fassung der Datei. Aus 64 Zeilen in einer
Funktion sind drei Funktionen geworden. Fuenf Commits samt fehlender
Hilfsmittel mitten in die TLB-Initialisierung zu portieren, testbar auf drei
Geraeten, bei einem Nutzen von null — der Codepfad behebt einen Startfehler
auf microAptiv/M5150, Kerne, die wir nicht einsetzen. Ein an einer Stelle
falsch portierter Backport scheitert genau wie der Fehler selbst: tot beim
Kaltstart, aus der Ferne nicht einzufangen.

**Am Geraet gemessen, 2026-09-08.** Der Kaltstarttest wurde vorgezogen, weil
der Archer C25 v1 ohnehin an der seriellen Konsole hing. Getestet mit dem
offiziellen OpenWrt-24.10.8-initramfs-Image (`sha256` gegen `sha256sums`
geprueft), also **Kernel 6.6.144 - demselben wie Gluon v2025.1.2/.3**. Per TFTP
nach `0x82000000` ins RAM geladen und mit `bootm` gestartet, der Flash blieb
unberuehrt. Echter Kaltstart, also zufaelliger TLB-Inhalt:

```
[    0.000000] Inode-cache hash table entries: 4096 ...      <- hier hing 5.15.198
[    0.000000] Writing ErrCtl register=00000000
[    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 16240
[    0.000000] Memory: 38992K/65536K available ...
...
[   12.686428] procd: - init -
              Please press Enter to activate this console.
[   21.673257] kmodloader: done loading kernel modules from /etc/modules.d/*
```

Vollstaendig durchgebootet.

**Danach als Messreihe wiederholt**, mit fernschaltbarem Netzteil, 63 gueltige
Kaltstarts am selben Geraet, drei Varianten im Wechsel:

| Variante | durchgebootet | haengt | n |
| --- | ---: | ---: | ---: |
| 5.15.198 ohne Patch | 0 | 21 | 21 |
| 5.15.198 mit Patch | 21 | 0 | 21 |
| 6.6.144 (OpenWrt 24.10.8) | 21 | 0 | 21 |

Die beiden 5.15.198-Varianten stammen aus demselben Build-Baum und
unterscheiden sich nur durch den Patch. **6.6.144 ist auf 74Kc nicht
betroffen**, und der Fehler in 5.15.198 ist **deterministisch** - nicht
sporadisch, wie der urspruengliche Upstream-Fehler auf microAptiv/M5150 mit
7 von 1000 Starts. Dass die 57 Knoten im Maerz 2026 ueber Tage verteilt
ausfielen, lag also allein daran, wann sie Strom verloren.

**Beim Umstieg zu tun:**

1. Auf 2025.1.1 oder neuer gehen, nicht auf v2025.1.
2. Den Kaltstarttest mit dem **tatsaechlichen** Gluon-Image wiederholen,
   sobald es gebaut ist - gemessen wurde der Kernel aus OpenWrt 24.10.8, nicht
   ein fertiges Gluon-2025.1-Image. Ein einzelner Durchgang genuegt dafuer:
   bei einem deterministischen Fehler zeigt sich das Ergebnis sofort.
3. Erst danach unseren Patch streichen. Er ist an 5.15 gebunden und wuerde
   gegen die Neufassung ohnehin nicht mehr greifen.

**Achtung beim Feldtest:** die Pruefung

```sh
grep -q r4k_tlb_uniquify /proc/kallsyms && echo ungeschuetzt || echo "Fix drin"
```

gilt **nur fuer unseren 5.15-Rueckbau**. Dort verschwindet das Symbol, weil die
Funktion unbenutzt wird. Auf 2025.1 bleibt der Aufruf bestehen, das Symbol ist
also vorhanden — ein Knoten dort meldet faelschlich "ungeschuetzt". Auf 2025.1
zaehlt allein der Kaltstarttest.

## 5. Vorschlag zur Reihenfolge

Der Feldabgleich in Kapitel 0 hat den Pflichtteil klein gemacht.

**Pflicht**

1. ~~`prepare.sh` laut Kapitel 4.3 laut machen~~ — **erledigt**, siehe 4.3.
2. Die acht entfallenden Patches entfernen, die sechs schrumpfenden kürzen.
3. `targets.conf`: `realtek-rtl838x` streichen, `ipq807x-generic` in
   `qualcommax-ipq807x` umbenennen.
4. zbit-Patch ersatzlos streichen (4.1) und beim ersten Testbau einen der 13 X5000R
   gegenprüfen. `mi4ag-migration.patch` prüfen (4.2).
5. Bauen. Danach das erzeugte Manifest gegen das alte diffen: jeder Name, der
   verschwindet, ist ein Gerät ohne Update-Pfad.
6. **Kaltstarttest auf einem 74Kc-Gerät mit serieller Konsole, bevor irgendetwas
   ausgerollt wird** (4.4). Und auf 2025.1.1 oder neuer zielen, nicht auf v2025.1.

**Nach Bedarf, kein Migrationsblocker**

6. Von den 15 Geräten aus Kapitel 2.2 nur das nachziehen, was ihr tatsächlich ausrollen
   wollt — im Feld ist derzeit keines davon. Dann aber **mit den bisherigen Imagenamen
   und Aliasen**.
7. `manifest_aliases = {'cudy-ap3000outdoor-v1'}` nur nötig, falls vor der Migration
   noch AP3000 Outdoor unter 2023.2 ausgerollt werden. Sonst gleich den
   Upstream-Namen `cudy-ap3000-outdoor-v1` übernehmen.

Die 4/32-Sackgasse taucht hier bewusst nicht auf — siehe **Umfang**.

**Beim Umstieg neu zu bewerten: die mt7915-Lage.** 2025.1 bringt OpenWrt 24.10
und damit mt76 vom 2025-11-06 statt vom 2024-04-03 — 19 Monate Treiberarbeit,
darunter der komplette Power-Save-Strang (`9a46d8d2`, `9e613fb0`, `f8b59ca3`),
der bei uns nicht backportierbar war. Danach ist zu prüfen, ob unsere
Gegenmaßnahmen noch gebraucht werden: der Backlog-Watchdog
`neanderfunk-mt7915-backlog`, der `wifi_firmware`-Reboot in
`neanderfunk-hotfix` und die selbst weitergezogene Pufferstaffel in
`lowmem/limit-wireless-buffers.patch` in Neanderfunk/gluon-patches-fixes (Gluon 2025.1 bringt `8f38662f` selbst
mit, aber nur bis 128 MB). Grundlage: `mt7915-analyse.md`.

## 5. Die Site-Konfiguration

Nachgetragen am 2026-09-08, erarbeitet am geklonten `v2025.1.3`.

**Es ist genau ein Release-Sprung.** Zwischen 2023.2 und 2025.1 liegt kein
2024er Zweig — `docs/releases/` springt von `v2023.2.5` direkt auf `v2025.1`.
Die Release Notes zu 2025.1 sind damit die vollstaendige Migrationsanleitung,
und es gibt keine Zwischenstation, an der man haette anhalten koennen.

Gluon sagt dort ausserdem: *"Updates are only supported from v2022.1 and
later."* Von 2023.2 aus ist der Weg also vorgesehen.

### 5.1 Tunneldigger ist kein Kernbestandteil mehr

Der schwerwiegendste Punkt fuer uns:

> Tunneldigger Mesh VPN support has been dropped (#3109)

Angekuendigt war es schon in 2023.2; jetzt ist es vollzogen. Der Ersatz liegt
als `ff-mesh-vpn-tunneldigger` in den community-packages und ist dort
vorhanden (Makefile, `check_site.lua`, `files`, `luasrc`).

Betroffen sind drei Stellen bei uns:

* `image-customization.lua` — das Feature heisst nicht mehr
  `mesh-vpn-tunneldigger`, das Paket muss aus dem Community-Feed kommen.
* `site.conf` — die Sektion `mesh_vpn.tunneldigger` mit MTU 1364 und den sechs
  Brokern (`ganymed`, `kallisto`, `amalthea`, `himalia`, `elara`, `pasophae`)
  wird dann vom `check_site.lua` des Community-Pakets geprueft statt von Gluon.
* `templates/common/modules` — der Community-Feed steht auf
  `PACKAGES_COMMUNITY_BRANCH=v2023.2.x`. Fuer 2025.1 ist der passende Zweig ein
  anderer; das Repo fuehrt `main`, `master`, `v2023.1.x` und `v2023.2.x`.

Das ist keine Formalie: es ist unser gesamter VPN-Transport.

**Am 2026-09-09 live geprueft, und es laeuft.** Testimage fuer den EdgeRouter X
mit `ff-mesh-vpn-tunneldigger` aus den community-packages (`61eb952a`), gegen
unsere sechs echten Broker auf Port 20021:

* `tunneldigger` und `simple-tc` uebersetzen unter OpenWrt 24.10 ohne Aenderung.
* Der Tunnel geht auf: Interface `mesh-vpn` mit MTU 1364, in `bat0` eingehaengt,
  `batctl if` meldet ihn als *active*.
* Der Knoten mesht: 70 Originatoren, Gateway ueber `mesh-vpn` mit 1024 MBit,
  Nexthop ein Supernode.
* Mesh-Adresse erreichbar, und zwar **dieselbe wie vor der Migration**
  (`2a03:2260:122:315:f29f:c2ff:fe0c:3ddd`, 18 ms) - der Knoten behaelt seine
  Identitaet, nicht bloss irgendeine Konfiguration.

Getestet mit Kernel 6.6.144 und batman-adv 2024.3, also genau der Kombination,
bei der man es haette klemmen sehen koennen.

Die drei Schritte aus der README des Pakets genuegen: Feature
`mesh-vpn-tunneldigger` weg, dafuer Feature `config-mode-mesh-vpn` und das Paket
`ff-mesh-vpn-tunneldigger`. Die `mesh_vpn`-Sektion der `site.conf` bleibt
unveraendert.

**Damit ist der VPN-Transport kein Blocker mehr fuer den 2025.1-Umstieg.**
Ungeprueft bleibt, wie unsere eigenen Pakete mit ihm zusammenspielen - der
`tunneldigger-watchdog` etwa lag als eigener micrond-Eintrag auf dem alten
System. Das Testimage hatte keine neanderfunk-Pakete.

Ebenfalls entfallen, fuer uns aber ohne Folgen: die Unterstuetzung fuer das
Babel-Routingprotokoll.

### 5.2 Der ERX steht in Gluons eigenen Release Notes

> The following devices can't be updated automatically due to breaking changes
> in OpenWrt, requiring manual steps to adjust the flash layout:
> Ubiquiti EdgeRouter-X (upgrade instructions: darkxst/erx-migration)

Unsere ERX-Arbeit ist damit nicht Eigenbau, sondern der vorgesehene Weg — mit
demselben Skript, das auch Freifunk Lippe und 4830.org verwenden. Einzelheiten
in den Werkstattnotizen.

### 5.3 Neues, das wir uns ansehen sollten

* **Autoupdater ueber HTTPS**, wenn das Feature `tls` im Image aktiv ist. Wir
  haben `tls` bereits fuer alles ausser `device_class('tiny')`.
* **`include()` in `image-customization.lua`** — erlaubt es, unsere inzwischen
  lange Datei aufzuteilen.
* **`gluon-radvd`**: Prefix-Lifetime jetzt in der `site.conf` einstellbar.
* Alte opkg-Schluessel werden beim Upgrade geloescht.

### 5.5 Gebaut — und der Grund fuer die ERX-Migration sind 27 Kilobyte

Am 2026-09-08 abends gebaut: Gluon v2025.1.3, `ramips-mt7621`,
`GLUON_DEVICES=ubiquiti-edgerouter-x`, mit unserer `21_dias`-`site.conf`
unveraendert. Der Bau laeuft durch.

Gemessen am fertigen Sysupgrade-Archiv:

| | Bytes | |
| --- | ---: | --- |
| Kernel 6.6 | **3 173 556** | 3,03 MB |
| alter Slot (`kernel1`/`kernel2` je) | 3 145 728 | 3 MB |
| **Ueberschuss** | **27 828** | **27 KB, 0,9 %** |
| neuer Slot (`kernel`) | 6 291 456 | 6 MB, davon 2,97 MB frei |
| Rootfs | 3 206 144 | 3,06 MB |

**Die gesamte Migration existiert wegen 27 Kilobyte.** Dafuer muss ein Byte im
Flash umgesetzt, ein Kernel ueber eine Slotgrenze geschrieben und jedes Geraet
einzeln angefasst werden. Im neuen Slot bleiben danach 50 % frei, fuer kommende
Kernel ist also reichlich Luft.

Einschraenkung: unser Testimage hat eine schlanke Paketauswahl (kein mesh-vpn).
Auf die Kernelgroesse wirkt sich das kaum aus — Module liegen im Rootfs, nicht
im Kernelabbild —, aber die Zahl ist eine Untergrenze, keine Obergrenze.

### 5.6 Der Build-Host braucht mehr als fuer 2023.2

OpenWrt 24.10 uebersetzt BPF-Programme und verlangt dafuer clang und die
LLVM-Werkzeuge auf dem Host; 23.05 tat das nicht. Ohne sie bricht der Bau ab:

```
bash: clang-not-found: command not found
include/bpf.mk:82: *** ERROR: LLVM/clang version too old. Minimum required: 12, found: .
```

Der Baum setzt `CONFIG_BPF_TOOLCHAIN_HOST=y` und `CONFIG_USE_LLVM_HOST=y`.
`CONFIG_BPF_TOOLCHAIN_NONE` ist **kein** Ausweg, weil zugleich
`CONFIG_NEED_BPF_TOOLCHAIN=y` gesetzt ist; und
`CONFIG_BPF_TOOLCHAIN_BUILD_LLVM` uebersetzte LLVM im Baum, was deutlich
langsamer ist als die Systempakete.

Gluon nennt die vollstaendige Liste in `docs/user/getting_started.rst`. Auf
unserem Arbeitsplatz fehlten davon acht:

```sh
apt install clang llvm libelf-dev libssl-dev zlib1g-dev libncurses5-dev \
            python3-dev python3-pyelftools
```

Fuer den Build-Host gehoert das vor den ersten 2025.1-Lauf, sonst scheitert er
nach ueber hundert uebersetzten Paketen an einer Kleinigkeit.

### 5.4 check_site ist gelaufen — die site.conf passt unveraendert

Nachgetragen am selben Abend. `tests/check-site-gluon2025.sh` fuehrt Gluons
eigene `check-site.lua` aus einem 2025.1-Baum gegen unsere assemblierte
`site.conf` aus, ohne dafuer zu bauen: Lua 5.1 genuegt (`site_config.lua`
braucht `setfenv`), das fehlende `jsonc` aus libubox liegt als reine
Lua-Fassung in `tests/lib/`.

Ergebnis gegen `21_dias`, Gluon v2025.1.3 plus die Feeds community,
neanderfunk und ffac:

```
  ohne Beanstandung: 34    mit Meldung: 12
```

**Alle zwoelf Meldungen betreffen Pakete, die wir nicht auswaehlen** — fastd,
Wireguard, Hoodselector, Layer3, Logging, Node-Role, Parker, OpenVPN,
ffgraz-*, ffmuc-Wireguard-VXLAN. Sie sagen nur, was diese Pakete braeuchten,
wenn man sie einschaltete.

Unsere eigenen Pakete aus `neanderfunk` und `ffac` melden nichts. Und der
Ersatz fuer Tunneldigger, `ff-mesh-vpn-tunneldigger` aus den
community-packages, ist mit unserer Konfiguration zufrieden: er verlangt
`mesh_vpn.tunneldigger.brokers` als String-Array und `.mtu` als Zahl, genau
das haben wir.

**Damit ist die site.conf kein Migrationsaufwand.** Der Aufwand liegt beim
Feed-Pin und bei der Frage, ob die Pakete unter 2025.1 *laufen* — was
check_site ausdruecklich nicht prueft.

Grenzen des Befunds, damit er nicht ueberdehnt wird:

* Geprueft ist die **Konfiguration**, nicht das Verhalten. Dass
  `ff-mesh-vpn-tunneldigger` unsere Broker akzeptiert, heisst nicht, dass der
  Tunnel steht.
* Die Pruefdateien der Feeds stammen aus unseren **2023.2-Auschecks**; fuer
  2025.1 gehoert der Community-Feed auf einen anderen Zweig, und dessen
  Pruefdateien koennen abweichen. Allein `ff-mesh-vpn-tunneldigger` wurde aus
  `main` geholt.
* Einzeldomain-Betrieb (kein `/lib/gluon/domains/`), so wie wir bauen.

Das Skript enthaelt einen Selbsttest: es entfernt vorab `site_code` und bricht
ab, wenn das *nicht* beanstandet wird. Ein Pruefstand, der nicht fehlschlagen
kann, beweist nichts.

---

Nicht Teil dieser Aufstellung, aber ebenfalls offen: Tunneldigger aus
`community-packages`, die Site-Feeds ohne 2025.1-Branch, die opkg-URLs auf `23.05.5`
in der `site.conf` sowie die Verhaltens-Patches (`010-primary-mac`, `020-interfaces`,
`interface-role-migration21`, `fix-respondd-rsk`, `gluon-makefile`, `gluon-packages`).
