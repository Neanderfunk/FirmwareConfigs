#!/usr/bin/env python3
"""sites.nefall.sta und sites.nefall.bro aus den Stammdaten erzeugen.

Aufruf im Konfigurationsverzeichnis (dort, wo domains.conf liegt):

  scripts/sites-aus-stammdaten.py              erzeugen und vergleichen
  scripts/sites-aus-stammdaten.py --schreiben  erzeugen und ueberschreiben
  scripts/sites-aus-stammdaten.py --stammdaten <dir>  vorhandenen Klon nehmen

Ohne --stammdaten klont das Skript STAMMDATEN_URL nach .stammdaten/ und
nimmt genau STAMMDATEN_COMMIT aus sites-aus-stammdaten.conf. Ein anderer Klon
muss auf diesem Commit stehen.

Ohne --schreiben entstehen sites.nefall.sta.neu und sites.nefall.bro.neu, und
das Skript vergleicht sie feldweise mit den vorhandenen Dateien.
Rueckgabe: 0 gleich (bzw. geschrieben), 1 Unterschiede, 2 Fehler.

Domaenen mit firmware_art nur multi (z. B. 25 bis 29) stehen nicht in der
Firmware-Tabelle der Stammdaten und damit auch nicht in den sites-Dateien.
"""
import os
import subprocess
import sys

KONF = "sites-aus-stammdaten.conf"
TSV = "erzeugt/firmware-domaenen.tsv"
SCHEMA = "1"

SPALTEN = (
    "RELBRANCH GLUONBRANCH TEMPLATE_NAME SITE_CODE DOMAIN_NR SITE_SMALL "
    "SITE_BIG FF_PREFIX META_PREFIX MESH_SID DOMAIN_NAME SUPERNODE_DEFAULT "
    "V4_PREFIX V6_PREFIX WIFICH_24 WIFICH_5 MAP_LAT MAP_LON MAP_ZOOM "
    "DOMAIN_HASH META_NAME META_WEBSITE MAP_WEBSITE FWWEBSITE_HOST "
    "FWWEBSITE_TLD OPKG_FQDN SUPERNODE_TLD DOMAIN_REGION_DE DOMAIN_REGION_EN "
    "SETUP_SKIP KEY_FILE_SIGN KEY_FILE_SSH DOMAIN_LONGNAME"
).split()

DATEIEN = {"STA": ("sites.nefall.sta", "stable"),
           "BRO": ("sites.nefall.bro", "broken")}


def fehler(text):
    print("Fehler: " + text, file=sys.stderr)
    sys.exit(2)


def konf_lesen(pfad):
    konf, ausnahmen = {}, []
    for nr, zeile in enumerate(open(pfad, encoding="utf-8"), 1):
        teile = zeile.split("#", 1)[0].split()
        if not teile:
            continue
        if teile[0] == "AUSNAHME":
            if len(teile) != 5 or teile[2] not in ("key", "ohne") \
                    or teile[3] not in SPALTEN:
                fehler(f"{pfad}:{nr}: AUSNAHME <nr> <key|ohne> <SPALTE> <Wert>")
            ausnahmen.append((teile[1].zfill(2), teile[2], teile[3], teile[4]))
        else:
            konf[teile[0]] = teile[1:]
    for k in ("STAMMDATEN_URL", "STAMMDATEN_COMMIT", "GLUONBRANCH",
              "REIHENFOLGE_STA", "VARIANTEN_STA",
              "REIHENFOLGE_BRO", "VARIANTEN_BRO"):
        if not konf.get(k):
            fehler(f"{pfad}: {k} fehlt")
    return konf, ausnahmen


def git(*args, cwd=None):
    return subprocess.run(["git", *args], cwd=cwd, check=True,
                          capture_output=True, text=True).stdout.strip()


def stammdaten_holen(url, commit, verzeichnis):
    if verzeichnis is None:
        verzeichnis = ".stammdaten"
        if not os.path.isdir(os.path.join(verzeichnis, ".git")):
            git("clone", "-q", url, verzeichnis)
        try:
            git("cat-file", "-e", commit + "^{commit}", cwd=verzeichnis)
        except subprocess.CalledProcessError:
            git("fetch", "-q", "origin", cwd=verzeichnis)
        git("-c", "advice.detachedHead=false", "checkout", "-q", commit,
            cwd=verzeichnis)
    try:
        kopf = git("rev-parse", "HEAD", cwd=verzeichnis)
    except subprocess.CalledProcessError:
        fehler(f"{verzeichnis} ist kein Git-Klon")
    if kopf != commit:
        fehler(f"{verzeichnis} steht auf {kopf}, gepinnt ist {commit}")
    if git("status", "--porcelain", "--", TSV, cwd=verzeichnis):
        fehler(f"{verzeichnis}/{TSV} ist lokal veraendert")
    return verzeichnis


def tsv_lesen(pfad):
    spalten, domaenen, schema = None, {}, None
    for zeile in open(pfad, encoding="utf-8"):
        zeile = zeile.rstrip("\n")
        if zeile.startswith("# schema "):
            schema = zeile.split()[2].rstrip(",")
        elif zeile.startswith("#DOMAIN_NR"):
            spalten = zeile[1:].split("\t")
        elif zeile.strip() and not zeile.startswith("#"):
            if spalten is None:
                fehler(f"{pfad}: Daten vor der Kopfzeile")
            werte = zeile.split("\t")
            if len(werte) != len(spalten):
                fehler(f"{pfad}: {len(werte)} statt {len(spalten)} Felder: {zeile[:40]}")
            for w in werte:
                if not w or any(c.isspace() for c in w):
                    fehler(f"{pfad}: leeres Feld oder Leerraum in Domaene {werte[0]}")
            d = dict(zip(spalten, werte))
            domaenen[d["DOMAIN_NR"]] = d
    if schema != SCHEMA:
        fehler(f"{pfad}: schema {schema}, erwartet {SCHEMA}")
    return domaenen


def zeile_bauen(d, relbranch, gluonbranch, variante, ausnahmen):
    z = {k: d[k] for k in SPALTEN if k in d}
    z["RELBRANCH"] = relbranch
    z["GLUONBRANCH"] = gluonbranch
    if variante == "key":
        z["TEMPLATE_NAME"] = d["SITE_CODE"] + "-key"
        z["SETUP_SKIP"] = "true"
        z["KEY_FILE_SIGN"] = d["KEY_FILE_SIGN_KEY"]
        endung = "sshkeys"
    else:
        z["TEMPLATE_NAME"] = d["SITE_CODE"]
        z["SETUP_SKIP"] = "false"
        endung = "nokeys"
    if not z["KEY_FILE_SIGN"].endswith(".signkeys"):
        fehler(f"Domaene {d['DOMAIN_NR']}: KEY_FILE_SIGN {z['KEY_FILE_SIGN']}")
    z["KEY_FILE_SSH"] = z["KEY_FILE_SIGN"][:-len("signkeys")] + endung
    for nr, var, spalte, wert in ausnahmen:
        if nr == d["DOMAIN_NR"] and var == variante:
            z[spalte] = wert
    fehlend = [k for k in SPALTEN if k not in z]
    if fehlend:
        fehler(f"Domaene {d['DOMAIN_NR']}: Spalten fehlen in den Stammdaten: {fehlend}")
    for k in ("KEY_FILE_SIGN", "KEY_FILE_SSH"):
        if not os.path.isfile(os.path.join("buildkeys", z[k])):
            fehler(f"{z['TEMPLATE_NAME']}: buildkeys/{z[k]} gibt es nicht")
    return [z[k] for k in SPALTEN]


def tabelle(zeilen, kopf):
    """Mit Leerzeichen ausgerichtet, zwei Leerzeichen zwischen den Spalten."""
    alle = [kopf] + zeilen
    breite = [max(len(z[i]) for z in alle) for i in range(len(SPALTEN))]
    return "".join(
        "  ".join(w.ljust(breite[i]) for i, w in enumerate(z)).rstrip() + "\n"
        for z in alle)


def datei_bauen(art, konf, ausnahmen, domaenen, quelle):
    relbranch = DATEIEN[art][1]
    reihenfolge = [n.zfill(2) for n in konf["REIHENFOLGE_" + art]]
    varianten = konf["VARIANTEN_" + art]
    if sorted(varianten) != ["key", "ohne"]:
        fehler(f"VARIANTEN_{art}: genau key und ohne")
    hinweise = []
    for nr in reihenfolge:
        if nr not in domaenen:
            hinweise.append(f"{art}: Domaene {nr} steht in REIHENFOLGE_{art}, "
                            "aber nicht in den Stammdaten; entfaellt")
    neu = sorted(set(domaenen) - set(reihenfolge), key=int)
    for nr in neu:
        hinweise.append(f"{art}: Domaene {nr} fehlt in REIHENFOLGE_{art}; "
                        "am Ende angehaengt")
    zeilen = [zeile_bauen(domaenen[nr], relbranch, konf["GLUONBRANCH"][0],
                          v, ausnahmen)
              for nr in [n for n in reihenfolge if n in domaenen] + neu
              for v in varianten]
    kopf = ["#" + SPALTEN[0]] + SPALTEN[1:]
    text = ("# Erzeugt von scripts/sites-aus-stammdaten.py, nicht von Hand aendern.\n"
            f"# Stammdaten {konf['STAMMDATEN_COMMIT'][0]}, {quelle}\n"
            + tabelle(zeilen, kopf))
    return text, hinweise


def felder(pfad):
    zeilen = []
    for zeile in open(pfad, encoding="utf-8"):
        if zeile.strip() and not zeile.lstrip().startswith("#"):
            zeilen.append(zeile.split())
    return zeilen


def vergleichen(alt_pfad, neu_pfad):
    if not os.path.isfile(alt_pfad):
        print(f"{alt_pfad}: gibt es noch nicht")
        return False
    alt, neu = felder(alt_pfad), felder(neu_pfad)
    alt_n = {z[2]: z for z in alt}
    neu_n = {z[2]: z for z in neu}
    gleich = True
    for name in alt_n.keys() - neu_n.keys():
        print(f"{alt_pfad}: {name} faellt weg")
        gleich = False
    for name in neu_n.keys() - alt_n.keys():
        print(f"{alt_pfad}: {name} kommt neu dazu")
        gleich = False
    for name in alt_n.keys() & neu_n.keys():
        a, n = alt_n[name], neu_n[name]
        if len(a) != len(SPALTEN):
            print(f"{alt_pfad}: {name} hat bisher {len(a)} Felder")
            gleich = False
            continue
        for i, k in enumerate(SPALTEN):
            if a[i] != n[i]:
                print(f"{alt_pfad}: {name} {k}: {a[i]} -> {n[i]}")
                gleich = False
    if [z[2] for z in alt] != [z[2] for z in neu] \
            and alt_n.keys() == neu_n.keys():
        print(f"{alt_pfad}: Reihenfolge der Zeilen anders")
        gleich = False
    return gleich


def main():
    args = sys.argv[1:]
    schreiben = "--schreiben" in args
    verzeichnis = None
    if "--stammdaten" in args:
        i = args.index("--stammdaten")
        if i + 1 >= len(args):
            fehler("--stammdaten braucht ein Verzeichnis")
        verzeichnis = args[i + 1]
        del args[i:i + 2]
    args = [a for a in args if a != "--schreiben"]
    if args:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    if not os.path.isfile(KONF) or not os.path.isdir("buildkeys"):
        fehler(f"im Konfigurationsverzeichnis starten ({KONF} und buildkeys/ fehlen hier)")

    konf, ausnahmen = konf_lesen(KONF)
    verzeichnis = stammdaten_holen(konf["STAMMDATEN_URL"][0],
                                   konf["STAMMDATEN_COMMIT"][0], verzeichnis)
    tsv = os.path.join(verzeichnis, TSV)
    quelle = next(z for z in open(tsv, encoding="utf-8")
                  if z.startswith("# schema ")).strip("# \n")
    domaenen = tsv_lesen(tsv)

    alles_gleich = True
    for art in ("STA", "BRO"):
        text, hinweise = datei_bauen(art, konf, ausnahmen, domaenen, quelle)
        for h in hinweise:
            print("Hinweis: " + h)
        ziel = DATEIEN[art][0]
        if schreiben:
            with open(ziel, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"{ziel}: geschrieben")
            continue
        with open(ziel + ".neu", "w", encoding="utf-8") as f:
            f.write(text)
        if vergleichen(ziel, ziel + ".neu"):
            print(f"{ziel}: feldweise gleich, {ziel}.neu nur anders formatiert")
        else:
            alles_gleich = False
    sys.exit(0 if alles_gleich else 1)


if __name__ == "__main__":
    main()
