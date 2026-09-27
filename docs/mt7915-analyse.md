# mt7915 / filogic: Stand der Ermittlungen und was wir tun sollten

Untersuchung, Stand 2026-09-07. Die Kapitel 1 bis 6 waren reine Analyse; was
daraus umgesetzt wurde, steht in Kapitel 4 jeweils dabei. **Kapitel 7 kam
danach dazu** und haelt die Feldmessung an den Testknoten fest.

> **Kurzfassung.** Zwei Dinge sind zu tun, beide klein:
>
> 1. **`patches/0013-wifi-mt76-mt7915-sync-power-save-state-with-WA.patch` löschen.**
>    Er liegt deaktiviert im Repo. Upstream wurde derselbe Ansatz aufgenommen und
>    vier Wochen später **wieder zurückgenommen**, weil er schlafende Clients nicht
>    mehr aufweckt. Einschalten wäre ein Rückschritt.
> 2. **Gluons Puffer-Deckel `8f38662f` nachziehen** — 13 Zeilen Shell, kein Treiber.
>    Wirkt allerdings nur auf unsere Geräte bis 128 MB RAM; für die filogic-Klasse
>    müsste man die Grenze selbst weiterziehen.
>
> Auf Treiberebene ist bei uns **nichts zu holen**: OpenWrt 23.05 ist auf mt76
> vom 2024-04-03 eingefroren, wir fahren bereits diesen Stand. Alles Weitere hängt
> am Sprung auf 2025.1.

## 1. Unser Ausgangspunkt

| | |
|---|---|
| OpenWrt | Zweig `openwrt-23.05`, Commit `7f61f962` |
| Kernel | 5.15.198 |
| mt76 | `PKG_SOURCE_DATE 2024-04-03`, `1e336a8582dce2ef` |
| betroffene Targets | `mediatek-filogic`, `mediatek-mt7622`, `ramips-mt7621` (mt7915e-Karten) |

Aktive Gegenmaßnahmen bei uns:

* `neanderfunk-mt7915-backlog` — liest alle zwei Minuten `iw phy <phy> get txq`,
  startet WLAN neu, wenn der Backlog über dem Schwellwert liegt. Vorgaben:
  Schwelle 50, erst ab 5 min Laufzeit prüfen, erst ab 60 min handeln,
  30 min Sperre nach einem Neustart.
* `neanderfunk-hotfix`, Check `wifi_firmware` — rebootet beim bekannten
  Firmware-Fehlerbild (seit Feed-Commit `c15c83e0`, löste `ffac-mt7915-hotfix` ab).
* Gluons eigener Patch `0007-mac80211-silence-warning-for-missing-rate-information`
  — kosmetisch, hält das Log frei.

Deaktiviert im Repo liegen:

* `mt7915-filogic-syncpowersave-patch.sh` samt Patchdatei — siehe Kapitel 3.
* `airtime-logsilience.sh` — überflüssig, Gluon liefert `0007-...` selbst.
* `add-mt7915e-try.sh` — die Patchdatei war nie im Repo.

## 2. Der Stand upstream

### 2.1 Der Power-Save-/AQL-Strang — der für uns entscheidende

Die Hardware puffert Frames für schlafende Stationen **unbegrenzt**. Bleibt eine
Station im Power-Save und bekommt weiter Daten, füllt sich die TX-Queue, AQL
gerät durcheinander, der Backlog wächst. Das ist genau das Bild, auf das unser
`neanderfunk-mt7915-backlog` reagiert.

Die Aufarbeitung in `openwrt/mt76`:

| Commit | Datum | Was |
|---|---|---|
| `be3aad4c2e10` | 2026-02-21 | David Bauer: *sync station power save state* — der Ansatz, den wir als Patchdatei liegen haben |
| `ca81c5c18ec8` | 2026-03-19 | **Revert** durch Felix Fietkau |
| `9a46d8d21d2a` | 2026-05-07 | *add PS buffering support for HW-managed TIM drivers* — neue Kerninfrastruktur |
| `9e613fb007f5` | 2026-05-07 | *mt7915: handle MCU PS sync events* — der Nachfolger, setzt auf obiger auf |
| `b0af99f238f7` | 2026-05-07 | dasselbe für mt7996 |
| `f8b59ca3be7b` | 2026-06-23 | *don't pin undrainable PS stations in the tx scheduler* — Nachbesserung |

Die Begründung des Reverts im Wortlaut:

> This causes a regression by preventing queueing of frames that would otherwise
> lead to a PS station being woken up.
> Fixes: https://github.com/openwrt/mt76/issues/1068

Issue #1068 beschreibt die Folge: Geräte im Power-Save wachen nicht mehr auf,
die Verbindung wirkt abgerissen. Gemeldet auf OpenWrt 25.12.

**Für uns heißt das: den Patch nicht einschalten.** Er ist kein "noch nicht
getesteter Kandidat", sondern ein upstream verworfener Ansatz mit bekannter
Regression.

Der Nachfolger ist nicht backportierbar. Geprüft am entpackten Quelltext unseres
mt76-Stands:

```
MT_DRV_HW_PS_BUFFERING    FEHLT
mt76_connac_ps_sync       FEHLT
MCU_EXT_EVENT_PS_SYNC     vorhanden (mt76_connac_mcu.h)
```

`9e613fb0` braucht die Kerninfrastruktur aus `9a46d8d2`, und die kam 13 Monate
nach unserem Stand. Es wären vier Commits, davon zwei im gemeinsamen Treiberkern.

### 2.2 Der MCU-Timeout-Strang — ohne Abschluss

`mt7915e: Message timeout while waiting for mcu response`
([Issue #690](https://github.com/openwrt/mt76/issues/690), offen seit 2022-08,
210 Kommentare) ist der Sammelthread für das harte Fehlerbild: WLAN unbrauchbar
bis zum Reboot, gehäuft bei 40+ Clients und langer Laufzeit. Die Diskussion
verläuft 2023 im Sand; der zuletzt vorgeschlagene SER-Recovery-Patch half dem
Melder nicht.

Das ist der Fehler, den unser `wifi_firmware`-Check per Reboot auffängt.

### 2.3 filogic im Besonderen

[Issue #922](https://github.com/openwrt/mt76/issues/922) (MT7981, seit 2024-10)
beschreibt genau unsere Chipklasse. Stand der letzten Wortmeldung (2025-09-27):

> There is no more freezing of the 5GHz WiFi. […] Sometimes the transmission
> speed is reduced, e.g. from 600 Mbit to 200 Mbit but it can be restored by
> reconnecting.

Das Einfrieren ist also behoben, der Durchsatzeinbruch nicht — und er tritt noch
im SNAPSHOT auf. In der Diskussion taucht mehrfach das Energiesparen **der
Clients** als Auslöser auf, was zum PS-Strang aus 2.1 passt.

### 2.4 Die Grenze

Ein Teil bleibt unlösbar: die WLAN-Firmware der Chips ist verschlüsselt.
Treiberseitige Patches können das Verhalten abfedern, nicht beheben.

## 3. Betrifft uns das, und gibt es Bewegung in 23.05?

Nein, und das ist die wichtigste Zahl dieser Untersuchung:

```
openwrt-23.05 (Zweigspitze heute):  mt76 2024-04-03  1e336a8582dce2ef
unser gepinnter Stand:              mt76 2024-04-03  1e336a8582dce2ef
openwrt-24.10:                      mt76 2025-11-06  eb567bc7f9b692bb
```

**OpenWrt 23.05 ist auf mt76 vom April 2024 eingefroren.** Wir fahren bereits den
letzten Stand, den diese Release-Linie hergibt. Ein Bump von OpenWrt innerhalb
23.05 bringt am Treiber nichts. Die 19 Monate Treiberarbeit stecken in 24.10 —
und damit in Gluon 2025.1.

Das schließt auch die Suche nach halbprivaten Test-Forks aus: was gebraucht wird,
ist keine verschollene Einzeländerung, sondern eine Treibergeneration.

## 4. Was zu tun ist

### 4.1 Den zurückgenommenen Patch löschen

`patches/0013-wifi-mt76-mt7915-sync-power-save-state-with-WA.patch` und
`patches/mt7915-filogic-syncpowersave-patch.sh`. Beide sind inaktiv, aber sie
laden zum Einschalten ein — und das wäre schädlich (2.1). Wer den Vorgang später
nachlesen will, findet ihn in diesem Dokument und in der Git-Historie.

### 4.2 Gluons Puffer-Deckel nachziehen — mit einer Einschränkung

Gluon-Commit `8f38662f` (David Bauer, 2025-11-26, *gluon-core: limit size of
wireless buffers*) begrenzt die WLAN-Puffer:

> By default, the kernel configures the buffers for wireless PHYs to 4MB for 11n
> radios and 16MB for 11ac and above. For our RAM constrained devices, this has
> the effect of the buffers potentially filling up to cause a OOM oops.

Der Commit liegt **nicht** in `v2023.2.x`. Unsere Fassung von
`01-gluon-core-codel-memusage` greift nur bei Geräten mit **≤ 32 MB RAM** — die
Gluon 2023.2 gar nicht mehr unterstützt. Bei uns ist also auf **keinem** Knoten
ein Limit gesetzt, es gilt die Kernelvorgabe von 16 MB je 11ac+-PHY.

Der Backport ist 13 Zeilen Shell, kein Kernel, kein Treiber. Aber die neue Fassung
staffelt nur bis 128 MB RAM:

| Gerät | MemTotal | `8f38662f` setzt |
|---|---|---|
| ZyXEL NWA50AX Pro, MERCUSYS MR90X | ~487 MiB | **kein Limit** |
| Cudy WR3000S | ~236 MiB | **kein Limit** |
| ramips-mt7621 mit 128 MB | ~123 MiB | 2 MB |

Für die filogic-Geräte — genau die mit dem Symptom — ändert der Commit also
nichts. Zwei Möglichkeiten:

* **nur backportieren:** hilft der 128-MB-Klasse, ist unstrittig, weil es
  Gluon-Upstream ist.
* **backportieren und die Staffel weiterziehen**, etwa 4 MB ab 256 MB RAM. Das
  ist dann unsere eigene Entscheidung und sollte gemessen werden: Ziel ist,
  dass der Backlog gar nicht erst in die Höhe läuft, auf die
  `neanderfunk-mt7915-backlog` reagiert. Gegen Durchsatzverlust spricht Bauers
  eigene Zahl: 512 kB reichten auf einem stärkeren Board für ~100 Mbit/s an drei
  Clients.

### 4.3 Was **nicht** abgeschaltet gehört

Beide laufenden Gegenmaßnahmen behandeln reale, upstream unerledigte Fehlerbilder:

* der `wifi_firmware`-Reboot deckt 2.2 ab — Issue #690 ist offen,
* der Backlog-Neustart deckt 2.1 ab — der Fix dafür ist in unserer
  Treiberversion nicht verfügbar.

Kontraproduktiv ist keines von beidem. Sinnvoll wäre nur, sie nach 4.2 noch
einmal gegen die Logs zu halten: greift der Backlog-Watchdog mit gedeckelten
Puffern seltener, war der Deckel die bessere Behandlung.

Eine Frage an die Paketfeed-Seite: `backlog.sh` nimmt aus
`iw phy <phy> get txq` das zweite Feld der `Backlog`-Zeile und vergleicht es mit
50. Ob das Bytes oder Pakete sind, entscheidet, ob die Schwelle sinnvoll liegt —
das wäre einmal an einem Knoten zu bestätigen.

## 5. Reihenfolge

1. Patch und Skript aus 4.1 löschen — kostet nichts, verhindert einen Fehlgriff.
2. `8f38662f` backportieren (4.2, erste Variante).
3. Auf einem filogic-Knoten messen, ob eine weitergezogene Staffel den Backlog
   drückt. Erst dann 4.2, zweite Variante.
4. Alles Weitere mit 2025.1 — dort kommt mt76 vom 2025-11-06 (`eb567bc7`) mit,
   dazu Gluons eigener Patch 0012 (PLE-Queues leeren). **Der PS-Strang aus 2.1
   ist darin nicht enthalten**, er ist jünger als dieser mt76-Stand
   (`9a46d8d2`/`9e613fb0` vom 2026-05-07, `f8b59ca3` vom 2026-06-23).
   Korrigiert am 27.09.2026 nach der Neubewertung der Paketverwaltung; vorher
   stand hier, der Strang komme mit 2025.1.

## 6. Quellen

* [openwrt/mt76 #1068](https://github.com/openwrt/mt76/issues/1068) — die Regression, die zum Revert führte
* [openwrt/mt76 #690](https://github.com/openwrt/mt76/issues/690) — MCU-Timeout, offen seit 2022
* [openwrt/mt76 #922](https://github.com/openwrt/mt76/issues/922) — MT7981/filogic, Durchsatzeinbruch
* Gluon-Commit `8f38662f44f5df69357ced93f166000716f018b3`
* mt76-Commits `be3aad4c2e10`, `ca81c5c18ec8`, `9a46d8d21d2a`, `9e613fb007f5`, `f8b59ca3be7b`

## 7. Feldmessung an den Testknoten, 2026-09-07

Nach dem Backport aus 4.2 und dem Ausbau des alten Patches aus 4.1 an sieben
Testknoten nachgemessen. Alles rein lesend, per `ssh … 'sh -s' < skript`, ohne
Ablage auf den Geraeten.

### 7.1 Der Puffer-Deckel greift, und die Staffel trifft

Auf allen fuenf Funkknoten steht der Wert, den `01-gluon-core-codel-memusage`
setzt — und zwar ueber beide Wege des Patches: `aqm` im debugfs und
`iw phy … get txq` melden dasselbe.

| Knoten | MemTotal | fq_memory_limit | Treiber |
| --- | ---: | ---: | --- |
| TL-WR1043ND v2 | 57 112 kB | **524 288** | ath9k |
| Xiaomi 4A Gigabit | 120 536 kB | 2 097 152 | mt7603e + mt76x2e |
| COVR-X1860 | 250 476 kB | 2 097 152 | mt7915e (PCIe) |
| Cudy WR3000S v1 | 241 448 kB | 2 097 152 | mt7915e (mt798x-wmac) |
| MERCUSYS MR90X v1 | 498 232 kB | 2 097 152 | mt7915e (mt798x-wmac) |
| ZyXEL NWA50AX Pro | 498 608 kB | 2 097 152 | mt7915e (mt798x-wmac) |

Der 1043er ist der einzige unterhalb der 64-MB-Grenze und bekommt korrekt die
512 kB. Vorher galt auf all diesen Geraeten die Kernelvorgabe von 16 MB je
11ac+-PHY.

**Was die Messung nicht zeigt:** ob der Deckel gegen den Backlog hilft. Die
Knoten liefen 18 bis 58 Minuten mit hoechstens einem Client. Backlog und
Overflow-Zaehler standen ueberall auf 0, der Cudy hatte nach 58 Minuten
13 bzw. 4 Hash-Kollisionen — das ist normales fq_codel-Verhalten und kein
Symptom. Aussagekraeftig wird das erst nach Tagen unter Last.

### 7.2 max_inactivity stand auf Geraeten ohne mt7915

`ffac-mt7915-maxinactivity` setzt `max_inactivity` auf **jeder**
`client_*`-Schnittstelle, sobald es installiert ist, und installiert wird es
nach Build-Target. Auf dem Xiaomi 4A Gigabit — mt7621, aber mt7603e und
mt76x2e, kein mt7915 — stand deshalb:

```
/var/run/hostapd-phy0.conf:ap_max_inactivity=10    phy0 = mt7603e
/var/run/hostapd-phy1.conf:ap_max_inactivity=10    phy1 = mt76x2e
```

Keiner der beiden Chips ist von openwrt/mt76#1009 betroffen. Die kurze Leine
bringt dort nichts und kostet einen Null-Data-Poll je untaetiger Station alle
zehn Sekunden.

Behoben mit `package-fixes/ffac-packages.patch` (seit 27.09.2026 in Neanderfunk/gluon-patches-fixes, vorher `patches/build/`): der Gate prueft jetzt zur Laufzeit
je Radio das Kernelmodul hinter dem Phy — dieselbe Pruefung wie in
`neanderfunk-mt7915-backlog`, und aus demselben Grund das Modul statt des
Treibernamens (SoC-integrierter mt7915 meldet sich als `mt798x-wmac`, das
Modul heisst weiter `mt7915e`). Radios ohne mt7915 bekommen den Wert **aktiv
entfernt**, nicht nur uebersprungen: `/etc/config/wireless` ueberlebt das
sysupgrade.

Die Abbildung wifi-device -> Phy macht `iwinfo nl80211 phyname`, nicht eigener
Code: das zweite Radio eines Dualband-SoC wird ueber ein `+1` adressiert, das
in sysfs keine Entsprechung hat (`platform/soc/18000000.wifi+1`), und auf dem
Xiaomi fehlt dem uci-Pfad das `platform/`, das der sysfs-Pfad traegt.

Am echten Skriptkoerper mit uci-Attrappe auf allen fuenf Funkknoten geprueft:
setzen auf den vier mt7915-Boards, entfernen auf Xiaomi und WR1043.

Beobachtet wurde die Regel auch scharf — auf dem COVR-X1860, 36 Sekunden nach
dem Verbinden:

```
13:37:52 client0: AP-STA-CONNECTED 8e:45:36:c5:5b:c3
13:38:28 client0: STA … disassociated due to inactivity
13:38:29 client0: STA … deauthenticated due to inactivity (timer DEAUTH/REMOVE)
```

### 7.3 Welche Gluon-Hardware ueberhaupt mt7915 faehrt

Belegkette: `gluon/targets/<target>` -> Profilname -> OpenWrt
`target/linux/*/image/*.mk` (`DEVICE_PACKAGES`, ueber `$(Device/…)` aufgeloest)
bzw. `*/target.mk` (`DEFAULT_PACKAGES`). Als "zieht mt7915e" gelten laut
`package/kernel/mt76/Makefile`: `kmod-mt7915e`, `kmod-mt7915-firmware`
(`DEPENDS +kmod-mt7915e`) und `kmod-mt7916-firmware` (ebenso). **Nicht** dazu
zaehlt `kmod-mt7622-firmware` — das haengt an `kmod-mt7615e`.

| Target | mit mt7915 | ohne | woher |
| --- | ---: | ---: | --- |
| mediatek-filogic | 16 / 16 | – | `filogic/target.mk:5`, `DEFAULT_PACKAGES` |
| mediatek-mt7622 | 6 / 6 | – | je Geraet `kmod-mt7915-firmware` |
| ramips-mt7621 | 15 / 40 | 25 | je Geraet `kmod-mt7915-firmware` |
| die uebrigen 29 Targets | 0 | 240 | — |

**37 von 301** Geraeten haben mt7915; unser Target-Gate in der
`image-customization.lua` deckt 62 ab. Die 25 zuviel liegen alle auf
ramips-mt7621, darunter beide Xiaomi 4A Gigabit, EdgeRouter X, RB750Gr3,
Netgear R6220/WAC104.

Eine Falle beim Nachvollziehen: auf **filogic steht `kmod-mt7915e` im
Subtarget**, nicht im Device-Block. Wer nur `DEVICE_PACKAGES` durchsucht,
findet dort null Treffer und uebersieht ausgerechnet MR90X, Cudy WR3000S und
ZyXEL NWA50AX Pro.

**Entscheidung: das Target-Gate bleibt.** Eine Geraeteliste waere machbar — die
15 Namen sind bekannt —, aber sie muesste OpenWrt hinterherlaufen, und eine
veraltete Liste heisst, dass ein Geraet, das den Workaround *braucht*, ihn
nicht bekommt. Das Target-Gate irrt in die harmlose Richtung. Der Preis ist
gemessen, mipsel_24kc: `ffac-mt7915-maxinactivity` 1 717 Bytes plus
`neanderfunk-mt7915-backlog` 2 764 Bytes, zusammen **4 481 Bytes** auf 25
Geraeten mit 16 MB Flash. `iwinfo` kommt nicht dazu, das steht ohnehin fuer
alle Geraete in unserer Paketliste.

### 7.4 MR90X: "eeprom load fail" — nachgegangen, nicht behebbar

Der MR90X meldet beim Start:

```
mt798x-wmac 18000000.wifi: eeprom load fail, use default bin
… Direct firmware load for mediatek/mt7986_eeprom_mt7975_dual.bin failed with error -2
```

Die beiden anderen Filogic-Boards nicht. Der Unterschied ist der SoC, nicht
Gluon:

| Knoten | SoC | `eeprom load fail` |
| --- | --- | ---: |
| Cudy WR3000S | mediatek,**mt7981** | 0 |
| ZyXEL NWA50AX Pro | mediatek,**mt7981** | 0 |
| MR90X | mediatek,**mt7986b** | 1 |

Ursache ist, dass `&wifi` in `mt7986b-mercusys-mr90x-v1.dts` keine
EEPROM-Referenz hat. Andere MT7986-Boards haben dort
`mediatek,mtd-eeprom = <&factory 0x0>;` (Netgear WAX220, Netcore N60) oder
`nvmem-cells = <&eeprom>;`. Der MR90X kann das nicht: er hat **keine
`factory`-Partition**. Sein Flash-Layout ist das von TP-Link/Mercusys, in
Frage kaemen `tp_data` (4 MB ab `0x6f00000`) und `userconfig` (8 MB).

Beide Partitionen ausgelesen und untersucht. Ergebnis in drei Schritten:

**1. `tp_data` ist kein Rohspeicher.** Es ist ein UBI-Container (`UBI#` je
Eraseblock, Volume 0 mit 8 von 18 gemappten LEBs, Datenbereich ab +0x1000 je
128-KiB-PEB). Darin liegt ein TP-Link-Journalformat mit dem Satz-Magic
`31 18 10 06` — 163 Saetze in `tp_data`, 977 in `userconfig`. Damit ist der
Weg ueber die DTS **prinzipiell** versperrt: `nvmem-cells` braucht einen festen
Offset in der MTD-Partition, hier liegen die Daten hinter der UBI-Blockzuordnung.

**2. Es steht ohnehin nichts Gerätespezifisches drin.** Jede Fundstelle der
MT7986-Signatur (erste zwei Bytes `0x7986` little-endian, siehe
`mt7915/eeprom.c:mt7915_check_eeprom`; Groesse 4096, MT7986 nutzt
`MT7916_EEPROM_SIZE`) als EEPROM-Kopf gelesen:

```
tp_data     0x2c1831 … 0x2c4031   MAC-Feld = 00:0c:43:26:60:00   (6x)
userconfig  0x3e4830, 0x3ea030    MAC-Feld = 00:0c:43:26:60:00
```

`00:0c:43:26:60:00` ist die MediaTek-Referenz-MAC. Das sind Kopien des
**generischen** EEPROMs — genau der Datensatz, auf den der Treiber ohnehin
zurueckfaellt. Die uebrigen Treffer haben keine gueltigen OUIs, das sind
Zufallstreffer in gepackten Daten.

**3. Die eigene MAC ist nicht dort.** `30:16:9d:…` kommt in 4 MiB `tp_data`
genau einmal vor und in 8 MiB `userconfig` ebenfalls einmal, beide Male nicht
in EEPROM-Kontext.

**Schluss: hier ist nichts zu holen.** Dass OpenWrts MR90X-DTS keine
EEPROM-Referenz hat, ist kein Versaeumnis, sondern die richtige Konsequenz —
es gibt nichts, worauf man zeigen koennte. Ein Patch wuerde denselben Zustand
herstellen, den der Fallback schon liefert. Die Meldung bleibt kosmetisch.

Das erklaert nebenbei, warum `neanderfunk-txpowerfix` auf genau diesem Geraet
`TW` ableitet und 20 dBm setzt: er misst mit `iwinfo txpowerlist`, was
verfuegbar ist, und das kommt aus dem generischen Datensatz.

**Fuer das naechste MT7986-Board:** zuerst pruefen, ob eine `factory`-Partition
existiert. Wenn nicht, ist der DTS-Weg tot, und bevor man in Vendor-Partitionen
sucht, lohnt der Test auf die Referenz-MAC `00:0c:43:26:60:00` — findet man
die, ist der Blob generisch und die Suche kann aufhoeren.
