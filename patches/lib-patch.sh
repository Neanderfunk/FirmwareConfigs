# shellcheck shell=bash
#
# Gemeinsame Hilfsfunktionen fuer die Patch-Skripte in patches/<gruppe>/.
#
# Eingebunden wird sie ueber den eigenen Skriptpfad, damit sie unabhaengig vom
# Arbeitsverzeichnis gefunden wird:
#
#   . "$(dirname "${BASH_SOURCE[0]}")/../lib-patch.sh"
#
# Die Skripte liegen nach Gruppen in Unterverzeichnissen (devices/, kernel/,
# status-page/ ...), jeweils zusammen mit ihren Patchdateien; diese Datei
# liegt eine Ebene hoeher und wird von allen geteilt.
#
# Zweck ist die Fehlererkennung. Frueher liefen alle Patch-Skripte nach dem
# Muster "wenn der Rueckwaerts-Trockenlauf fehlschlaegt, patche vorwaerts" und
# werteten das Ergebnis nirgends aus; prepare.sh endete zusaetzlich mit
# "exit 0;". Ein scheiternder Patch fiel damit nicht auf - er ergab still eine
# Firmware, in der Geraete fehlen. Jeder Fehler bricht jetzt ab.
#
# Aufrufkontext: die Skripte laufen im Gluon-Verzeichnis (prepare.sh ruft sie
# von dort als ../patches/<gruppe>/<name>.sh auf), einige wechseln danach nach
# openwrt.
# Alle Pfade sind gequotet: ein unquotetes "<$patchfile" ergibt bei einem
# Leerzeichen im Pfad "ambiguous redirect", und das Kommando laeuft dann gar
# nicht erst - genau daran sind hier schon Patches still gescheitert.

set -o nounset
set -o errexit
set -o pipefail

# Absoluter Pfad des Verzeichnisses, in dem das aufrufende Skript liegt (seine
# Gruppe, dort liegen auch seine Patchdateien), damit die Skripte ihre
# Patchdateien auch nach einem "cd openwrt" noch finden.
PATCH_DIR="$( cd "$( dirname "${BASH_SOURCE[1]}" )" && pwd )"

# Strenge fuer alle patch-Aufrufe: kein Fuzz, Leerzeichen zaehlen.
#
# Mit dem Standard-Fuzz 2 und --ignore-whitespace griffen Patches auch dann
# noch, wenn ihr Kontext upstream laengst anders aussah. So legten die
# Target-Patches unter 2025.1 still Geraete ein zweites Mal an, die Gluon
# inzwischen selbst fuehrt (bis gluon-patches-hardware eb6c58f). Ein Patch,
# der nicht mehr exakt passt, soll abbrechen und neu erzeugt werden.
# Versatz (offset) bleibt erlaubt: er verschiebt nur die Zeilennummern.
PATCH_STRICT=(--fuzz=0)

patch_abort ()
{
  echo "  FEHLER: $*" >&2
  exit 1
}

# remove_patch_leftovers <patchdatei>
#
# Loescht .orig- und .rej-Dateien neben den Dateien, die der Patch anfasst.
#
# patch legt bei jedem Hunk-Versatz eine .orig-Kopie an. Die landet in der
# Firmware: Gluon kopiert package/*/files/. und luasrc/. vollstaendig ins Image
# (Gluon/Build/Install in package/gluon.mk). Ausgeliefert wurde dadurch unter
# anderem /lib/gluon/upgrade/020-interfaces.orig - ausfuehrbar, und
# gluon-reconfigure arbeitet das Verzeichnis mit "for script in *" ab. Die
# ungepatchte Fassung lief also direkt nach der gepatchten und ueberschrieb
# deren Schnittstellenzuordnung wieder.
#
# Neue .orig-Dateien verhindert --no-backup-if-mismatch. Die schon
# vorhandenen muessen weg: "git reset --hard" fasst unversionierte Dateien
# nicht an, sie ueberleben also jeden Lauf.
remove_patch_leftovers ()
{
  local patch_file="$1"
  local target

  # Aus den "+++ b/<pfad>"-Zeilen die Zieldateien ziehen (-p1, also b/ weg).
  while read -r target; do
    [ -n "$target" ] || continue
    [ "$target" = "/dev/null" ] && continue
    rm -f "$target.orig" "$target.rej"
  done < <(awk '/^\+\+\+ /{ sub(/^\+\+\+ [ab]\//, "", $0); sub(/[ \t].*$/, "", $0); print }' "$patch_file")
}

# created_files <patchdatei>
#
# Gibt die Dateien aus, die der Patch neu anlegt. Zwei Schreibweisen kommen
# vor: "--- /dev/null" (git diff) und "--- a/<pfad>\t1970-01-01 ..."
# (diff -ruN gegen eine nicht vorhandene Datei, z. B. sysctl-64m-min-free).
created_files ()
{
  awk '
    /^--- / && ($0 ~ /\/dev\/null/ || $0 ~ /[ \t]1970-01-01/) {
      if ((getline line) > 0 && line ~ /^\+\+\+ /) {
        sub(/^\+\+\+ [ab]\//, "", line)
        sub(/[ \t].*$/, "", line)
        print line
      }
    }' "$1"
}

# created_files_present <patchdatei>
#
# Wahr, wenn mindestens eine der Dateien, die der Patch anlegt, schon im Baum
# liegt.
created_files_present ()
{
  local target

  while read -r target; do
    [ -n "$target" ] || continue
    [ -e "$target" ] && return 0
  done < <(created_files "$1")

  return 1
}

# remove_created_files <patchdatei>
#
# Loescht die Dateien, die der Patch neu anlegen wuerde, sofern sie schon da
# sind.
#
# Aufgerufen nur, wenn der Rueckwaerts-Test fehlgeschlagen ist, der Patch also
# nicht vollstaendig drinsteht. Dann sind vorhandene Neuanlagen Reste eines
# frueheren Laufs, den ein "git reset --hard" nur halb zurueckgenommen hat: es
# stellt versionierte Dateien wieder her, unversionierte laesst es stehen.
# patch scheitert an so einem Halbzustand mit "the next patch would create the
# file ..., which already exists".
remove_created_files ()
{
  local patch_file="$1"
  local target

  while read -r target; do
    [ -n "$target" ] || continue
    [ -e "$target" ] || continue
    echo "  $target: Rest eines frueheren Laufs, wird vor dem Patchen entfernt."
    rm -f "$target"
  done < <(created_files "$patch_file")
}

# do_patch <patchdatei>
#
# Wendet den Patch an und bricht bei Fehlschlag ab.
do_patch ()
{
  local patch_file="$1"

  # -f, damit patch bei unerwartetem Zustand abbricht, statt interaktiv zu
  # fragen und den Build haengen zu lassen.
  # --no-backup-if-mismatch: ohne das legt patch bei jedem Versatz eine
  # .orig-Kopie neben der Zieldatei an. Siehe remove_patch_leftovers.
  patch -p1 -f "${PATCH_STRICT[@]}" --no-backup-if-mismatch <"$patch_file" \
    || patch_abort "$patch_file liess sich nicht anwenden."
  echo "  $patch_file: angewendet."
}

# apply_patch <patchdatei> [pruefdatei] [pruefmuster]
#
# Wendet die Patchdatei relativ zum aktuellen Verzeichnis an (-p1). Ist sie
# bereits angewendet, passiert nichts. Sind Pruefdatei und -muster angegeben,
# wird hinterher geprueft, dass die Aenderung tatsaechlich im Baum steht: ein
# durchgelaufener patch-Aufruf allein ist dafuer noch kein Beleg.
apply_patch ()
{
  local patch_file="$1"
  local check_file="${2-}"
  local check_pattern="${3-}"

  [ -f "$patch_file" ] || patch_abort "$patch_file nicht gefunden (Arbeitsverzeichnis: $PWD)."

  remove_patch_leftovers "$patch_file"

  # Reihenfolge der Pruefungen, jede beantwortet genau eine Frage:
  #
  #   1. Rueckwaerts anwendbar?      -> steht schon vollstaendig drin
  #   2. Vorwaerts anwendbar?        -> normaler Fall, anwenden
  #   3. Legt der Patch Dateien an, die schon dastehen? -> alte Fassung aus
  #                                     einem frueheren Lauf, ersetzen
  #   4. Merkmal schon im Baum?      -> ein spaeterer Patch hat dieselbe Stelle
  #                                     nochmal geaendert (statuspage-ssid und
  #                                     -hwdetails setzen so auf
  #                                     statuspage-moredetails auf)
  #   5. Neuanlagen von einem halben Lauf wegraeumen und nochmal vorwaerts
  #   6. sonst Abbruch
  #
  # Der Vorwaerts-Test steht bewusst VOR der Merkmalspruefung: sonst wuerde ein
  # Merkmal, das es im unveraenderten Baum ohnehin schon gibt, den Patch
  # dauerhaft stillschweigend ueberspringen. Genau das ist mit
  # targets-ath79-generic.patch passiert.
  if patch -R -p1 -s -f --dry-run "${PATCH_STRICT[@]}" <"$patch_file" >/dev/null 2>&1; then
    echo "  $patch_file: bereits angewendet."
  elif patch -p1 -s -f --dry-run "${PATCH_STRICT[@]}" <"$patch_file" >/dev/null 2>&1; then
    do_patch "$patch_file"
  elif created_files_present "$patch_file"; then
    # Der Patch legt Dateien an, die schon im Baum liegen - in einer anderen
    # Fassung, sonst haette der Rueckwaerts-Test gegriffen. build.sh setzt den
    # Gluon-Baum nur zurueck und reinigt ihn absichtlich nicht (siehe dort),
    # also ueberleben solche Dateien jeden Lauf. Dieser Zweig muss VOR der
    # Merkmalspruefung stehen: Das Merkmal steht ja schon da, und der Patch
    # wuerde stillschweigend uebersprungen. Genau so kam 26091521bro mit der
    # alten memory-64m.conf heraus (vm.min_free_kbytes=2048), obwohl der
    # Patch die neue Fassung ohne diese Zeile anlegt.
    remove_created_files "$patch_file"
    do_patch "$patch_file"
  elif [ -n "$check_file" ] && [ -n "$check_pattern" ] && [ -f "$check_file" ] \
       && grep -q "$check_pattern" "$check_file"; then
    echo "  $patch_file: '$check_pattern' steht bereits in $check_file, nichts zu tun."
    return 0
  else
    # Reste eines Laufs, den ein "git reset --hard" nur halb zurueckgenommen
    # hat: die neu angelegten Dateien ueberleben als unversionierte Dateien,
    # die Aenderungen an versionierten Dateien sind weg. patch scheitert dann
    # mit "the next patch would create the file ..., which already exists".
    remove_created_files "$patch_file"
    do_patch "$patch_file"
  fi

  [ -n "$check_file" ] || return 0
  [ -f "$check_file" ] \
    || patch_abort "$patch_file lief durch, aber $check_file fehlt."
  [ -n "$check_pattern" ] || return 0
  grep -q "$check_pattern" "$check_file" \
    || patch_abort "$patch_file lief durch, aber '$check_pattern' fehlt in $check_file."
}

# copy_into_tree <quelldatei> <zieldatei>
#
# Kopiert eine Datei in den Baum, sofern sie dort noch nicht liegt. Fuer die
# Patches, die nicht angewendet, sondern als Datei abgelegt werden (OpenWrt und
# der Kernel wenden sie selbst an).
copy_into_tree ()
{
  local source_file="$1"
  local target_file="$2"

  [ -f "$source_file" ] || patch_abort "$source_file nicht gefunden."

  if [ -f "$target_file" ]; then
    echo "  $target_file: liegt bereits im Baum."
    return 0
  fi

  [ -d "$(dirname "$target_file")" ] \
    || patch_abort "$(dirname "$target_file") gibt es nicht - passt der Pfad noch zum Baum?"
  cp "$source_file" "$target_file" || patch_abort "$source_file liess sich nicht kopieren."
  echo "  $target_file: kopiert."
}

# enter_dir <verzeichnis>
#
# cd mit Abbruch. Ohne die Pruefung laufen die folgenden Patches im falschen
# Baum, wenn das Verzeichnis fehlt.
enter_dir ()
{
  cd "$1" || patch_abort "Wechsel nach $1 nicht moeglich (Arbeitsverzeichnis: $PWD)."
}
