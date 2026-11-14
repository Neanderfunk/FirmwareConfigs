#!/usr/bin/env python3
"""Multi-Domain-Vorlage templates/multidomain/ aus den Stammdaten erzeugen.

Aufruf im Konfigurationsverzeichnis (dort, wo domains.conf liegt):

  scripts/multidomain-aus-stammdaten.py              erzeugen und vergleichen
  scripts/multidomain-aus-stammdaten.py --schreiben  erzeugen und ueberschreiben
  scripts/multidomain-aus-stammdaten.py --stammdaten <dir>  vorhandenen Klon

Quelle ist erzeugt/firmware-multidomain.json am STAMMDATEN_COMMIT aus
sites-aus-stammdaten.conf (derselbe Pin wie fuer die sites-Dateien).

Vorgehen:
1. templates/common/site.conf wird fuer jede Domaene so ausgefuellt, wie es
   das ParallelBuildsystem fuer eine Single-Domain-Site taete (dieselben
   Platzhalter, Werte aus "tsv"). SBRANCH, RELBRANCH und GLUONBRANCH bleiben
   stehen, KEYFILESIGN, KEYFILESSH und SETUPSKIP auch: die setzt der Bau je
   Zeile von sites.nefall.multi (mit und ohne SSH-Schluessel).
2. Jeder Pfad landet entweder in site.conf oder in domains/<code>.conf, nie
   in beiden (Gluon fuehrt Listen elementweise zusammen):
   - Pfade, die Gluon nur in der Domain erlaubt (in_domain), und unsere
     eigenen Domain-Schluessel: Domain.
   - Pfade, die in allen Domaenen gleich sind: Site.
   - verschiedene Werte unter einem Pfad, den Gluon nur in der Site erlaubt
     (in_site): Site, mit dem Wert aus SITE_WEIT unten, bei Listen sonst den
     Eintraegen, die in allen Domaenen stehen, sonst dem Wert der
     default_domain; die Liste steht am Ende der Ausgabe.
   - sonst: Domain.
3. Dazu kommen aus dem Export domain_names (anzeigename), hide_domain,
   domain_seed, neanderfunk_hostname_prefix, neanderfunk_legacy (mesh_id,
   next_node_ip4, next_node_ip4_fest) und ddhcpd (nur bei an = true).
4. Probe: Site und Domain nach Gluons Regel zusammengefuehrt muessen fuer
   jede Domaene wieder die ausgefuellte Single-Domain-Fassung ergeben, bis
   auf die Schluessel aus 3. und die in_site-Pfade aus 2.

Ohne --schreiben entsteht templates/multidomain.neu/, und das Skript
vergleicht dateiweise mit templates/multidomain/.
Rueckgabe: 0 gleich (bzw. geschrieben), 1 Unterschiede, 2 Fehler.

SPDX-License-Identifier: BSD-3-Clause
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys

HIER = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "sites_aus_stammdaten", os.path.join(HIER, "sites-aus-stammdaten.py"))
sas = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sas)

EXPORT = "erzeugt/firmware-multidomain.json"
SCHEMA = 1
VORLAGE = "templates/common"
ZIEL = "templates/multidomain"
SITES = "sites.nefall.multi"
# Dateien der Vorlage, die unveraendert gelten (Symlink nach common)
GLEICH = ["image-customization.lua", "modules", "patchrepos", "prepare.sh",
          "usb-geraete.lua"]

# Platzhalter wie im ParallelBuildsystem (generate_site_config), in dieser
# Reihenfolge; True = "_" wird zu Leerzeichen.
PLATZHALTER = [
    ("SITECODE", "SITE_CODE", False), ("DOMAINNR", "DOMAIN_NR", False),
    ("SITESMALL", "SITE_SMALL", False), ("SITEBIG", "SITE_BIG", False),
    ("FFPREFIX", "FF_PREFIX", False), ("METAPREFIX", "META_PREFIX", False),
    ("MESHSSID", "MESH_SID", False), ("DOMAINNAME", "DOMAIN_NAME", True),
    ("SUPERNODEDEFAULT", "SUPERNODE_DEFAULT", False),
    ("V4PREFIX", "V4_PREFIX", False), ("V6PREFIX", "V6_PREFIX", False),
    ("WIFICH24", "WIFICH_24", False), ("WIFICH5", "WIFICH_5", False),
    ("MAPLAT", "MAP_LAT", False), ("MAPLON", "MAP_LON", False),
    ("MAPZOOM", "MAP_ZOOM", False), ("DOMAINHASH", "DOMAIN_HASH", False),
    ("METANAME", "META_NAME", True), ("METAWEBSITE", "META_WEBSITE", False),
    ("MAPWEBSITE", "MAP_WEBSITE", False),
    ("FWWEBSITEHOST", "FWWEBSITE_HOST", False),
    ("FWWEBSITETLD", "FWWEBSITE_TLD", False), ("OPKGFQDN", "OPKG_FQDN", False),
    ("SUPERNODETLD", "SUPERNODE_TLD", False),
    ("DOMAINREGIONDE", "DOMAIN_REGION_DE", True),
    ("DOMAINREGIONEN", "DOMAIN_REGION_EN", True),
    ("DOMAINLONGNAME", "DOMAIN_LONGNAME", True),
]
# setzt der Bau je Zeile von sites.nefall.multi; roh in Lua, deshalb hier als
# Merker-String durch den Lua-Lauf getragen und danach zurueckgetauscht
ROH = {"KEYFILESIGN": "'@@KEYFILESIGN@@',", "KEYFILESSH": "'@@KEYFILESSH@@',",
       "SETUPSKIP": "'@@SETUPSKIP@@'"}

# Gluon (v2025.1) erlaubt diese Pfade nur in der Domain-Datei; dazu unsere.
NUR_DOMAIN = [
    ("domain_names",), ("domain_seed",), ("hide_domain",), ("domain_switch",),
    ("prefix4",), ("prefix6",), ("extra_prefixes6",), ("node_prefix6",),
    ("next_node",), ("mesh", "vxlan"), ("hoodselector",),
    ("wifi24", "ap", "ssid"), ("wifi24", "ap", "owe_ssid"), ("wifi24", "mesh", "id"),
    ("wifi5", "ap", "ssid"), ("wifi5", "ap", "owe_ssid"), ("wifi5", "mesh", "id"),
    ("ddhcpd",), ("neanderfunk_hostname_prefix",), ("neanderfunk_legacy",),
]
# ... und diese nur in der site.conf ("*" = beliebiger Schluessel).
NUR_SITE = [
    ("site_code",), ("site_name",), ("default_domain",), ("hostname_prefix",),
    ("timezone",), ("regdom",), ("poe_passthrough",), ("authorized_keys",),
    ("autoupdater", "branch"), ("autoupdater", "branches", "*", "name"),
    ("autoupdater", "branches", "*", "pubkeys"),
    ("autoupdater", "branches", "*", "good_signatures"),
    ("config_mode", "geo_location"), ("config_mode", "hostname"),
    ("config_mode", "remote_login"), ("interfaces", "*", "default_roles"),
    ("mesh_vpn", "enabled"), ("mesh_vpn", "bandwidth_limit"),
    ("mesh_vpn", "fastd", "configurable"), ("mesh_vpn", "fastd", "syslog_level"),
    ("nodeplacer",), ("roles",), ("setup_mode",), ("wifi_blackout",),
]

# Site-weite Werte, wo die Domaenen verschieden sind und Gluon nur die Site
# erlaubt. ENTWURF (14.11.2026), Wortlaut fuer Nutzer gehoert Content.
SITE_WEIT = {
    ("site_name",): "Freifunk im Neanderland",
}
# Platzhalter der i18n-Dateien im Multi-Domain-Image. ENTWURF (14.11.2026),
# Wortlaut gehoert Content; ersetzt die domain-eigenen Texte.
I18N = {
    "de.po": {"DOMAINNAME": "die unten gewählte Domain",
              "DOMAINREGIONDE": "im Neanderland und in den Nachbar-Communities"},
    "en.po": {"DOMAINNAME": "the domain selected below",
              "DOMAINREGIONEN": "in the Neanderland and its neighbouring communities"},
    "fr.po": {"DOMAINNAME": "le domaine choisi ci-dessous"},
}
# im i18n ausserdem aus der default_domain: METANAME, METAWEBSITE, MAPWEBSITE


def fehler(text):
    print("Fehler: " + text, file=sys.stderr)
    sys.exit(2)


def passt(pfad, muster):
    return len(pfad) >= len(muster) and all(
        m == "*" or m == p for m, p in zip(muster, pfad))


def unter(pfad, liste):
    return any(passt(pfad, m) for m in liste)


def ausfuellen(text, tsv):
    for token, spalte, leer in PLATZHALTER:
        wert = str(tsv[spalte])
        text = text.replace(token, wert.replace("_", " ") if leer else wert)
    return text


def lua_laden(text, arbeit):
    pfad = os.path.join(arbeit, "probe.conf")
    with open(pfad, "w", encoding="utf-8") as f:
        f.write(text)
    r = subprocess.run(["lua5.1", os.path.join(HIER, "lua-nach-json.lua"), pfad],
                       capture_output=True, text=True)
    if r.returncode:
        fehler("site.conf laesst sich nicht laden: " + r.stderr.strip())
    return json.loads(r.stdout)


def teilen(werte, pfad, site, domains, abweichend, default):
    """werte: {code: wert oder FEHLT}; schreibt nach site / domains[code]."""
    def setzen(ziel, wert):
        knoten = ziel
        for k in pfad[:-1]:
            knoten = knoten.setdefault(k, {})
        knoten[pfad[-1]] = wert

    vorhanden = {c: w for c, w in werte.items() if w is not FEHLT}
    if unter(pfad, NUR_DOMAIN):
        for c, w in vorhanden.items():
            setzen(domains[c], w)
        return
    if vorhanden and all(isinstance(w, dict) and w for w in vorhanden.values()):
        schluessel = sorted({k for w in vorhanden.values() for k in w})
        for k in schluessel:
            teilen({c: (w.get(k, FEHLT) if w is not FEHLT else FEHLT)
                    for c, w in werte.items()}, pfad + (k,), site, domains,
                   abweichend, default)
        return
    verschieden = len({json.dumps(w, sort_keys=True) for w in vorhanden.values()}) > 1
    if not verschieden and len(vorhanden) == len(werte):
        setzen(site, next(iter(vorhanden.values())))
    elif unter(pfad, NUR_SITE):
        wert = SITE_WEIT.get(pfad, FEHLT)
        listen = list(vorhanden.values())
        if wert is FEHLT and len(vorhanden) == len(werte) and all(isinstance(w, list) for w in listen):
            # Listen (z. B. nodeplacer.mirrors): nur, was in allen Domaenen steht
            gemeinsam = [x for x in listen[0] if all(x in w for w in listen[1:])]
            if gemeinsam:
                wert = gemeinsam
        if wert is FEHLT:
            wert = werte.get(default, FEHLT)
        if wert is FEHLT:
            fehler(f"{'.'.join(pfad)}: nur in der Site erlaubt, fehlt in der default_domain")
        setzen(site, wert)
        abweichend.append(pfad)
    else:
        for c, w in vorhanden.items():
            setzen(domains[c], w)


class _Fehlt:
    def __repr__(self):
        return "FEHLT"


FEHLT = _Fehlt()


def lua_wert(v, tiefe):
    ein = "  " * (tiefe + 1)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        if v.startswith("@@") and v.endswith("@@"):
            return v  # Merker, wird danach zurueckgetauscht
        return "'" + v.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n") + "'"
    if isinstance(v, list):
        if not v:
            return "{}"
        return "{\n" + "".join(f"{ein}{lua_wert(x, tiefe + 1)},\n" for x in v) + "  " * tiefe + "}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        teile = []
        for k in sorted(v):
            schl = k if k.isidentifier() and k not in LUA_WOERTER else f"['{k}']"
            teile.append(f"{ein}{schl} = {lua_wert(v[k], tiefe + 1)},\n")
        return "{\n" + "".join(teile) + "  " * tiefe + "}"
    raise TypeError(type(v))


LUA_WOERTER = {"and", "break", "do", "else", "elseif", "end", "false", "for",
               "function", "if", "in", "local", "nil", "not", "or", "repeat",
               "return", "then", "true", "until", "while"}


def roh_zurueck(text):
    # Merker als Listenelement ("'@@X@@'," steht nach lua_wert als "@@X@@,")
    for token in ROH:
        if ROH[token].endswith(","):  # Listenelement: die Rohzeilen bringen ihr Komma mit
            text = text.replace(f"@@{token}@@,", token)
        text = text.replace(f"@@{token}@@", token)
    return text


def zusammenfuehren(a, b):
    """Gluons merge (check-site.lua): tief, Listen elementweise."""
    if b is FEHLT or b is None:
        return a
    if type(a) is not type(b) or not isinstance(b, (dict, list)):
        return b
    if not b:
        return a
    if isinstance(b, list):
        m = list(a)
        for i, v in enumerate(b):
            if i < len(m):
                m[i] = zusammenfuehren(m[i], v)
            else:
                m.append(v)
        return m
    m = dict(a)
    for k, v in b.items():
        m[k] = zusammenfuehren(m.get(k, FEHLT), v) if k in m else v
    return m


def ohne(d, pfade):
    d = json.loads(json.dumps(d))
    for p in pfade:
        k = d
        for s in p[:-1]:
            k = k.get(s, {}) if isinstance(k, dict) else {}
        if isinstance(k, dict):
            k.pop(p[-1], None)
    return d


def main():
    args = sys.argv[1:]
    schreiben = "--schreiben" in args
    verzeichnis = None
    if "--stammdaten" in args:
        i = args.index("--stammdaten")
        verzeichnis = args[i + 1]
        del args[i:i + 2]
    args = [a for a in args if a != "--schreiben"]
    if args:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    if not os.path.isfile(sas.KONF) or not os.path.isdir(VORLAGE):
        fehler(f"im Konfigurationsverzeichnis starten ({sas.KONF} und {VORLAGE} fehlen hier)")
    konf, _ = sas.konf_lesen(sas.KONF)
    commit = konf["STAMMDATEN_COMMIT"][0]
    verzeichnis = sas.stammdaten_holen(konf["STAMMDATEN_URL"][0], commit, verzeichnis)
    if sas.git("status", "--porcelain", "--", EXPORT, cwd=verzeichnis):
        fehler(f"{verzeichnis}/{EXPORT} ist lokal veraendert")
    export = json.load(open(os.path.join(verzeichnis, EXPORT), encoding="utf-8"))
    if export.get("schema") != SCHEMA:
        fehler(f"{EXPORT}: schema {export.get('schema')}, erwartet {SCHEMA}")
    domaenen = {d["domain_code"]: d for d in export["domains"]}
    for d in domaenen.values():
        d["tsv"] = {k: str(v) for k, v in d["tsv"].items()}
    # dieselben Werte wie in der Single-Domain-Tabelle (sites.nefall.*)
    tabelle = sas.tsv_lesen(os.path.join(verzeichnis, sas.TSV))
    for d in domaenen.values():
        t = tabelle.get(d["tsv"]["DOMAIN_NR"])
        if t:
            anders = [k for k in t if k in d["tsv"] and t[k] != d["tsv"][k]]
            if anders:
                fehler(f"{d['domain_code']}: {EXPORT} und {sas.TSV} verschieden in {anders}")
    default = export["default_domain"]
    if default not in domaenen:
        fehler(f"default_domain {default} fehlt in den Domaenen")

    vorlage = open(os.path.join(VORLAGE, "site.conf"), encoding="utf-8").read()
    for token, ersatz in ROH.items():
        if token not in vorlage:
            fehler(f"{VORLAGE}/site.conf: Platzhalter {token} fehlt")
        vorlage = vorlage.replace(token, ersatz)

    arbeit = os.path.join(ZIEL + ".arbeit")
    shutil.rmtree(arbeit, ignore_errors=True)
    os.makedirs(arbeit)
    einzeln = {c: lua_laden(ausfuellen(vorlage, d["tsv"]), arbeit) for c, d in domaenen.items()}

    site, dom, abweichend = {}, {c: {} for c in domaenen}, []
    teilen(einzeln, (), site, dom, abweichend, default)

    # Werte aus dem Export
    site["site_code"] = export["site_code"]
    site["default_domain"] = default
    for c, d in domaenen.items():
        dd = dom[c]
        dd["domain_names"] = {c: d["anzeigename"]}
        dd["hide_domain"] = bool(d["hide"])
        dd["domain_seed"] = d["domain_seed"]
        if dd.get("next_node", {}).get("ip4") != d["ip4"] or dd.get("prefix4") != d["prefix4"]:
            fehler(f"{c}: next_node.ip4/prefix4 aus der Vorlage passen nicht zum Export")
        dd["neanderfunk_hostname_prefix"] = d["hostname_prefix"]
        legacy = {k: v for k, v in (("mesh_id", d["mesh_sid_alt"]),
                                     ("next_node_ip4", d["next_node4_alt"]),
                                     ("next_node_ip4_fest", d.get("next_node4_fest", [])))
                  if v}
        if legacy:
            dd["neanderfunk_legacy"] = legacy
        dh = d["ddhcpd"]
        if dh.get("an"):
            dd["ddhcpd"] = {"enabled": True, "range": dh["range"],
                            "client_prefix4": d["prefix4"], "router": dh["router"],
                            "dns": dh["dns"]}

    # Probe nach Gluons Regel
    eigene = [("domain_names",), ("hide_domain",), ("domain_seed",), ("site_code",),
              ("default_domain",), ("neanderfunk_hostname_prefix",),
              ("neanderfunk_legacy",), ("ddhcpd",)] + abweichend
    for c in domaenen:
        zusammen = zusammenfuehren(json.loads(json.dumps(site)), dom[c])
        if ohne(zusammen, eigene) != ohne(einzeln[c], eigene):
            fehler(f"{c}: Site + Domain ergibt nicht die Single-Domain-Fassung")
    # keine Domain-Datei darf einen nur-Site-Pfad tragen und umgekehrt
    def pfade(d, p=()):
        for k, v in d.items():
            if isinstance(v, dict) and v and not unter(p + (k,), NUR_DOMAIN + NUR_SITE):
                yield from pfade(v, p + (k,))
            else:
                yield p + (k,)
    for c in domaenen:
        for p in pfade(dom[c]):
            if unter(p, NUR_SITE):
                fehler(f"{c}: {'.'.join(p)} ist nur in der Site erlaubt")
    for p in pfade(site):
        if unter(p, NUR_DOMAIN):
            fehler(f"site.conf: {'.'.join(p)} ist nur in der Domain erlaubt")

    kopf = ("-- Erzeugt von scripts/multidomain-aus-stammdaten.py, nicht von Hand aendern.\n"
            f"-- Stammdaten {commit}, {export['quelle']}\n"
            f"-- Quelle der Werte: {VORLAGE}/site.conf (Kommentare und Begruendungen dort).\n")
    raus = ZIEL + ".neu"
    shutil.rmtree(raus, ignore_errors=True)
    os.makedirs(os.path.join(raus, "domains"))
    os.makedirs(os.path.join(raus, "i18n"))
    with open(os.path.join(raus, "site.conf"), "w", encoding="utf-8") as f:
        f.write(kopf + roh_zurueck(lua_wert(site, 0)) + "\n")
    for c in sorted(domaenen):
        with open(os.path.join(raus, "domains", c + ".conf"), "w", encoding="utf-8") as f:
            f.write(kopf + lua_wert(dom[c], 0) + "\n")
    sitemk = open(os.path.join(VORLAGE, "site.mk"), encoding="utf-8").read()
    with open(os.path.join(raus, "site.mk"), "w", encoding="utf-8") as f:
        f.write("# Erzeugt von scripts/multidomain-aus-stammdaten.py aus "
                f"{VORLAGE}/site.mk\n" + sitemk.rstrip("\n")
                + "\n\nGLUON_MULTIDOMAIN := 1\n")
    dt = domaenen[default]["tsv"]
    for name, ersatz in I18N.items():
        text = open(os.path.join(VORLAGE, "i18n", name), encoding="utf-8").read()
        for token, wert in ersatz.items():
            text = text.replace(token, wert)
        for token, spalte, leer in PLATZHALTER:
            if token in ("METANAME", "METAWEBSITE", "MAPWEBSITE"):
                text = text.replace(token, dt[spalte].replace("_", " ") if leer else dt[spalte])
        rest = [t for t, _, _ in PLATZHALTER if t in text]
        if rest:
            fehler(f"i18n/{name}: Platzhalter ohne Wert: {rest}")
        with open(os.path.join(raus, "i18n", name), "w", encoding="utf-8") as f:
            f.write(text)
    for name in GLEICH:
        os.symlink(os.path.join("..", "common", name), os.path.join(raus, name))
    # Platzhalter, die im erzeugten Baum noch stehen duerfen (setzt der Bau)
    erlaubt = {"SBRANCH", "RELBRANCH", "GLUONBRANCH"} | set(ROH)
    for wurzel, _, dateien in os.walk(raus):
        for n in dateien:
            p = os.path.join(wurzel, n)
            if os.path.islink(p):
                continue
            t = open(p, encoding="utf-8").read()
            rest = [tok for tok, _, _ in PLATZHALTER if tok in t]
            if rest:
                fehler(f"{p}: Platzhalter stehen noch: {rest}")
    for c in domaenen:
        lua_laden(open(os.path.join(raus, "domains", c + ".conf"), encoding="utf-8").read(), arbeit)
    probe = open(os.path.join(raus, "site.conf"), encoding="utf-8").read()
    for token, ersatz in ROH.items():
        probe = probe.replace(token, ersatz)
    lua_laden(probe, arbeit)
    shutil.rmtree(arbeit)

    # sites.nefall.multi: eine Zeile ohne, eine mit SSH-Schluessel (Monheim)
    zeilen = []
    for variante, code, skip, ssh in (("ohne", "ffnef-multi", "false", "ffnef.nokeys"),
                                      ("key", "ffnef-multi-key", "true", "ffmon.sshkeys")):
        z = dict(dt)
        z.update(RELBRANCH="stable", GLUONBRANCH=konf["GLUONBRANCH"][0],
                 TEMPLATE_NAME="multidomain", SITE_CODE=code, SETUP_SKIP=skip,
                 KEY_FILE_SIGN="ffnef.signkeys", KEY_FILE_SSH=ssh)
        for k in ("KEY_FILE_SIGN", "KEY_FILE_SSH"):
            if not os.path.isfile(os.path.join("buildkeys", z[k])):
                fehler(f"buildkeys/{z[k]} gibt es nicht")
        zeilen.append([z[k] for k in sas.SPALTEN])
    with open(os.path.join(raus, SITES), "w", encoding="utf-8") as f:
        f.write("# Erzeugt von scripts/multidomain-aus-stammdaten.py, nicht von Hand aendern.\n"
                f"# Stammdaten {commit}. Schluessel site-weit wie Monheim (adorfer 14.11.2026).\n"
                "# Nur RELBRANCH, GLUONBRANCH, TEMPLATE_NAME, SITE_CODE, SETUP_SKIP und\n"
                "# KEY_FILE_* wirken; die Domain-Werte stehen in templates/multidomain/.\n"
                + sas.tabelle(zeilen, ["#" + sas.SPALTEN[0]] + sas.SPALTEN[1:]))

    print(f"{len(domaenen)} Domaenen, default_domain {default}")
    print("Site-weit trotz verschiedener Werte (nur in der Site erlaubt): "
          + (", ".join(".".join(p) + (" [SITE_WEIT]" if p in SITE_WEIT else " [gemeinsam/default_domain]")
                       for p in abweichend) or "-"))
    print("Domain-eigene Pfade: " + ", ".join(sorted({".".join(p[:2]) for c in dom for p in pfade(dom[c])})))

    if schreiben:
        if os.path.exists(ZIEL):
            shutil.rmtree(ZIEL)
        shutil.move(os.path.join(raus, SITES), SITES)
        shutil.move(raus, ZIEL)
        print(f"{ZIEL}/ und {SITES}: geschrieben")
        return 0
    r = subprocess.run(["diff", "-r", "--no-dereference", ZIEL, raus], capture_output=True, text=True)
    r2 = subprocess.run(["diff", SITES, os.path.join(raus, SITES)], capture_output=True, text=True)
    if r.returncode == 0 and r2.returncode == 0:
        print(f"{ZIEL}/: gleich")
        shutil.rmtree(raus)
        return 0
    print((r.stdout + r2.stdout)[:4000] or (r.stderr + r2.stderr))
    print(f"Unterschiede, neue Fassung in {raus}/")
    return 1


if __name__ == "__main__":
    sys.exit(main())
