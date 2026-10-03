#!/bin/bash
#
# Wendet die Patches auf den Gluon-Baum an: zuerst die der Patch-Repos aus
# der Pin-Datei patchrepos (neben dieser Datei), dann die aus patches/ in
# diesem Repo.
#
# Aufgerufen wird die Datei von build.sh (prepare_gluon_tree), je Lauf zweimal
# und mit dem Gluon-Verzeichnis als Arbeitsverzeichnis. Sie liegt als Kopie in
# jedem zusammengebauten Site-Verzeichnis, deshalb der Umweg ueber ../gluon.
#
# Zwei Phasen, weil "make update" dazwischen liegt:
#
#   prepare.sh pre-update    vor  "make update"
#   prepare.sh post-update   nach "make update"
#
# In die pre-update-Phase gehoert alles, was eine Datei unter patches/openwrt
# oder patches/packages im Gluon-Baum ablegt: Gluons scripts/patch.sh spielt
# diese Dateien waehrend "make update" per "git am" auf die Module ein. Danach
# abgelegt wuerden sie erst im naechsten Lauf wirken - und nur so lange, wie
# sie einen "git reset --hard" als unversionierte Dateien ueberleben.
#
# Alles andere gehoert in die post-update-Phase, insbesondere jeder Patch am
# OpenWrt-Baum: "make update" setzt den neu auf und wuerde die Aenderungen
# sonst wieder wegnehmen.
#
# Bis hierher endete die Datei mit "exit 0;", und keines der Patch-Skripte gab
# einen Fehler weiter. Ein scheiternder Patch fiel damit nicht auf - er ergab
# still eine Firmware, in der Geraete fehlen. Der Bau bricht jetzt an der
# ersten fehlgeschlagenen Stelle ab. Deshalb steht am Ende kein "exit 0;" mehr:
# der Rueckgabewert soll der der Patches sein.

set -o nounset
set -o errexit
set -o pipefail

# Vom Gluon-Verzeichnis aus gesehen ist das wieder es selbst; der Pfad bleibt
# so, damit die Skripte ihre Patches unveraendert unter ../patches finden.
GLUON_DIR="../gluon"

abort ()
{
  echo "prepare.sh: $*" >&2
  exit 1
}

PHASE="${1-}"
case "$PHASE" in
  pre-update|post-update) ;;
  *) abort "Aufruf: prepare.sh pre-update|post-update" ;;
esac

[ -d "$GLUON_DIR/package/gluon-core" ] \
  || abort "$GLUON_DIR ist kein Gluon-Baum - laeuft prepare.sh im Gluon-Verzeichnis? (Arbeitsverzeichnis: $PWD)"
[ -d "$GLUON_DIR/../patches" ] \
  || abort "$GLUON_DIR/../patches nicht gefunden."

# run_patch <skript> <beschreibung>
#
# Ruft das Skript im Gluon-Verzeichnis auf, in einer Subshell, damit ein cd
# darin (etwa nach openwrt) das naechste Skript nicht betrifft. Frueher stand
# hier pushd/popd; scheiterte das pushd, lief der Patch im falschen
# Verzeichnis, und das popd danach ebenfalls ins Leere.
run_patch ()
{
  local script="$1"
  local description="$2"

  echo
  echo "=== $script: $description"

  [ -x "$GLUON_DIR/../patches/$script" ] \
    || abort "patches/$script fehlt oder ist nicht ausfuehrbar."

  ( cd "$GLUON_DIR" && "../patches/$script" ) \
    || abort "patches/$script fehlgeschlagen ($description)."
}

# --- Patch-Repos --------------------------------------------------------
#
# Die Pin-Datei liegt neben prepare.sh (build.sh kopiert beide aus
# templates/common ins zusammengebaute Site-Verzeichnis). Die Repos liegen
# neben dem Gluon-Baum unter patch-repos/<name>, ausserhalb eines
# Worker-Overlays. In pre-update werden sie geholt und auf den gepinnten
# Commit gesetzt, in post-update nur geprueft: dort braucht es kein Netz.

PIN_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patchrepos"
[ -f "$PIN_FILE" ] || abort "Pin-Datei $PIN_FILE fehlt."
PATCHREPO_ROOT="$(cd "$GLUON_DIR/.." && pwd)/patch-repos"

PATCHREPOS=""
# shellcheck source=/dev/null
. "$PIN_FILE"

# patchrepo_pin <name> <REPO|BRANCH|COMMIT>
patchrepo_pin ()
{
  local var
  var="PATCHREPO_$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')_$2"
  [ -n "${!var-}" ] || abort "$var fehlt in $PIN_FILE."
  printf '%s' "${!var}"
}

# fetch_patchrepo <name>: holen und auf den gepinnten Commit setzen.
fetch_patchrepo ()
{
  local name="$1" repo branch commit dir try
  repo="$(patchrepo_pin "$name" REPO)"
  branch="$(patchrepo_pin "$name" BRANCH)"
  commit="$(patchrepo_pin "$name" COMMIT)"
  dir="$PATCHREPO_ROOT/$name"

  echo
  echo "=== Patch-Repo $name: $repo $branch @ $commit"

  if [ ! -d "$dir/.git" ]; then
    rm -rf -- "$dir"
    mkdir -p -- "$PATCHREPO_ROOT"
    git init -q -- "$dir" || abort "git init $dir fehlgeschlagen."
  fi
  git -C "$dir" remote remove origin 2>/dev/null || true
  git -C "$dir" remote add origin "$repo"

  # Drei Versuche mit Pause: ein kurzer Netzaussetzer soll den Lauf nicht
  # beenden.
  for try in 1 2 3; do
    git -C "$dir" fetch -q origin "+refs/heads/$branch:refs/remotes/origin/$branch" && break
    [ "$try" -lt 3 ] || abort "Patch-Repo $name: fetch von $repo ($branch) fehlgeschlagen."
    echo "  fetch fehlgeschlagen, neuer Versuch in 30 s ..."
    sleep 30
  done

  git -C "$dir" cat-file -e "$commit^{commit}" 2>/dev/null \
    || abort "Patch-Repo $name: Commit $commit gibt es in $repo nicht."
  git -C "$dir" merge-base --is-ancestor "$commit" "refs/remotes/origin/$branch" \
    || abort "Patch-Repo $name: Commit $commit liegt nicht auf $branch."
  git -C "$dir" checkout -q --force --detach "$commit" \
    || abort "Patch-Repo $name: checkout $commit fehlgeschlagen."
  git -C "$dir" clean -q -f -d -x
}

# check_patchrepo <name>: steht das Repo sauber auf dem gepinnten Commit?
check_patchrepo ()
{
  local name="$1" commit dir head
  commit="$(patchrepo_pin "$name" COMMIT)"
  dir="$PATCHREPO_ROOT/$name"
  head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" \
    || abort "Patch-Repo $name fehlt unter $dir - lief pre-update?"
  [ "$head" = "$commit" ] \
    || abort "Patch-Repo $name steht auf $head statt auf $commit."
  [ -z "$(git -C "$dir" status --porcelain)" ] \
    || abort "Patch-Repo $name hat lokale Aenderungen."
}

# apply_patchrepo <name>: dessen apply.sh fuer die aktuelle Phase aufrufen.
apply_patchrepo ()
{
  local name="$1"
  echo
  echo "=== Patch-Repo $name: apply.sh $PHASE"
  ( cd "$GLUON_DIR" && "$PATCHREPO_ROOT/$name/apply.sh" "$PHASE" ) \
    || abort "Patch-Repo $name: apply.sh $PHASE fehlgeschlagen."
}

[ -n "$PATCHREPOS" ] || abort "PATCHREPOS ist leer in $PIN_FILE."

echo "Patches anwenden (Patch-Repos, dann patches/), Phase $PHASE ..."

if [ "$PHASE" = "pre-update" ]; then

  for repo in $PATCHREPOS; do fetch_patchrepo "$repo"; done
  for repo in $PATCHREPOS; do apply_patchrepo "$repo"; done

  # Legt eine Datei im Gluon-Baum ab, die "make update" gleich darauf auf ein
  # Modul anwendet. Sie muss deshalb hier stehen und nicht unten.
  run_patch build/add-gluon-package-patches.sh  "Paketpatch fuer packages/gluon bereitlegen (opkg-Keys)"

  echo
  echo "Phase pre-update abgeschlossen."
  exit 0
fi

for repo in $PATCHREPOS; do check_patchrepo "$repo"; done
for repo in $PATCHREPOS; do apply_patchrepo "$repo"; done

run_patch bugfixes/fix-respondd-rsk.sh          "respondd-Listener auf den Gluon-2016.x-Wert"
# network/interface-role-migration21 entfaellt unter 2025.1: Gluon hat die
# 2021-Migration selbst entfernt; ein 2021er Knoten geht ueber 2023.2.
run_patch build/patch-gluon-makefiles.sh     "Gluon-Makefile und Paketliste"

# --- USB-Geraeteliste ---------------------------------------------------
#
# usb-geraete.lua (eingebunden von image-customization.lua) haengt an drei
# Staenden: Gluon-Commit, OpenWrt-Pin und gluon-patches-hardware (neue
# Geraete ohne OpenWrt-Sprung). Zeile 2 der Liste traegt sie als Stempel.
# Passt er nicht zum Bau, wird die Liste hier aus dem fertig gepatchten Baum
# neu erzeugt (scripts/usb-geraete.py, etwa eine Minute) und ersetzt die
# Fassung im Site-Verzeichnis; sie landet mit der Site im Image-Verzeichnis.
# Die Fassung in FirmwareConfigs nachzuziehen bleibt ein eigener Commit, damit
# man im Diff sieht, welche Geraete USB gewinnen oder verlieren. Neu erzeugte
# Listen liegen je Stempel im Cache neben dem Gluon-Baum, damit sie nicht in
# jeder Domain erneut entstehen.
usb_list_refresh ()
{
  local site_dir list want have cache tmp openwrt_pin
  site_dir="$(dirname "$PIN_FILE")"
  list="$site_dir/usb-geraete.lua"
  [ -f "$list" ] || abort "usb-geraete.lua fehlt in $site_dir."

  openwrt_pin="$(sed -n 's/^OPENWRT_COMMIT=//p' "$GLUON_DIR/modules" | cut -c1-12)"
  want="-- Stand: gluon=$(git -C "$GLUON_DIR" rev-parse --short=12 HEAD) openwrt=$openwrt_pin hardware=$(patchrepo_pin hardware COMMIT | cut -c1-12)"
  have="$(sed -n 2p "$list")"

  echo
  echo "=== USB-Geraeteliste"
  if [ "$have" = "$want" ]; then
    echo "  passt zum Bau: ${want#-- Stand: }"
    return 0
  fi
  echo "  Liste: ${have#-- }"
  echo "  Bau:   ${want#-- }"

  cache="$(cd "$GLUON_DIR/.." && pwd)/usb-geraete-cache/$(printf '%s' "$want" | md5sum | cut -c1-16).lua"
  if [ ! -f "$cache" ]; then
    mkdir -p -- "$(dirname "$cache")"
    tmp="$cache.tmp.$$"
    "$GLUON_DIR/../scripts/usb-geraete.py" "$GLUON_DIR" "$(patchrepo_pin hardware COMMIT)" > "$tmp" \
      || { rm -f -- "$tmp"; abort "scripts/usb-geraete.py fehlgeschlagen."; }
    [ "$(sed -n 2p "$tmp")" = "$want" ] \
      || { rm -f -- "$tmp"; abort "Neu erzeugte USB-Liste traegt einen anderen Stempel als der Bau."; }
    mv -f -- "$tmp" "$cache"
    echo "  neu erzeugt: $cache"
  else
    echo "  aus dem Cache: $cache"
  fi
  cp -- "$cache" "$list"
  local unterschied
  unterschied="$(diff -u "$GLUON_DIR/../templates/common/usb-geraete.lua" "$list" | sed -n '3,$p' | grep -E "^[-+] " || true)"
  if [ -z "$unterschied" ]; then
    echo "  Geraete unveraendert, nur der Stempel ist neu; templates/common/usb-geraete.lua"
    echo "  in FirmwareConfigs bei Gelegenheit nachziehen."
  else
    echo "  ACHTUNG: templates/common/usb-geraete.lua in FirmwareConfigs ist veraltet."
    echo "  Unterschied zur neuen Liste (die Images nutzen die neue):"
    printf '%s\n' "$unterschied" | sed 's/^/    /'
  fi
}
usb_list_refresh

# Seit 27.09.2026 in eigenen Repos (Pin-Datei patchrepos): Geraete, Targets,
# Geraete-Korrekturen, Kernel und primaere MACs in
# Neanderfunk/gluon-patches-hardware; lowmem, allgemeine Fehlerbehebungen,
# Config-Mode-Wizard, Outdoor-Schalter und die Paketpatches fuer Airtime und
# ffac in Neanderfunk/gluon-patches-fixes; Statusseite und Setup-Mode-Netz,
# die an Neanderfunk-Paketen haengen, in Neanderfunk/gluon-patches-packages
# (gepflegt von der Paketverwaltung).

# Entfernt am 11.09.2026, weil sie nicht mehr aufgerufen wurden (die
# Geschichte steht in git):
#
# add-mt7915e-try.sh                   mt76-Korrekturen fuer MT7603/MT7612;
#                                      patches/mt7915e-try.patch war nie im Repo
# airtime-logsilience.sh               hielt den Airtime-Monitor aus dem Log,
#   + 999-silence-missing-rate.patch   Gluon bringt das inzwischen selbst mit
# ignore-preservechannels-for-outdoormode.sh (+ .patch.old)
#                                      Vorgaenger von outdoor-schalter.sh
#                                      (2020-2022, baute dazu 200-wireless um)
# tunneldiggergit.sh/.patch            git:// -> https:// fuer tunneldigger,
#                                      das Makefile im Feed hat laengst https
# targets-ipq40xx-mirotik.patch        Dublette mit Tippfehler zu -mikrotik
#
# git am ../patches/0001-*             frueher: durchnummerierte Patches
#                                      automatisch anwenden

echo
echo "Phase post-update abgeschlossen, alle Patches angewendet."
