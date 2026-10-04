#!/bin/bash
#
# Lokaler Bau der Sackgasse (Gluon 2021.1 / OpenWrt 19.07) im Docker-Container.
# Uebergangsloesung, bis das ParallelBuildsystem 2021.1 kann
# (docs/ueberarbeitung-2026.md).
#
#   scripts/build-local.sh <template> [target ...]
#
# Beispiel: SBRANCH=24100416bro RELBRANCH=broken \
#           EXTRA_SSH_KEY=~/.ssh/id_rsa_sackgasse.pub \
#           scripts/build-local.sh 21_dias-key ar71xx-tiny
#
# Umgebung:
#   SBRANCH        Release-Name (Vorgabe: 24<MMDDHH>bro, Jahr "verschoben", damit
#                  kein Feldknoten es als neuer ansieht als 24111216sackgasse)
#   RELBRANCH      Autoupdater-Branch und Spalte 1 der sites-Zeile (Vorgabe broken)
#   EXTRA_SSH_KEY  weitere Public-Key-Datei, wird nur lokal eingebacken
#   JOBS           make -j (Vorgabe: Kerne)
#
# Ablauf (cwd im Container = gluon/):
#   1. Gluon am Pin aus build.conf klonen, Patch-Repos aus patchrepos klonen
#   2. Site aus templates/<template> + Zeile in sites.nefall.sackgasse bauen
#   3. git am patches/0001 (WR841 8M/16M, legt einen OpenWrt-Patch an)
#   4. apply.sh pre-update je Patch-Repo, make update
#   5. alte Patches aus patches/ (respondd-rsk, DIR-615 C1, kernelswapon,
#      preservechannels), apply.sh post-update je Patch-Repo
#   6. make je Target (BROKEN=1, V=s), make manifest

set -o errexit -o nounset -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${IN_CONTAINER:-}" != 1 ]; then
  [ $# -ge 1 ] || { echo "Aufruf: $0 <template> [target ...]" >&2; exit 2; }
  EXTRA=()
  if [ -n "${EXTRA_SSH_KEY:-}" ]; then
    EXTRA_SSH_KEY="$(readlink -f "$EXTRA_SSH_KEY")"
    EXTRA=(-v "$EXTRA_SSH_KEY:/extra-ssh-key.pub:ro" -e EXTRA_SSH_KEY=/extra-ssh-key.pub)
  fi
  exec docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e IN_CONTAINER=1 \
    -e SBRANCH="${SBRANCH:-24$(date +%m%d%H)bro}" -e RELBRANCH="${RELBRANCH:-broken}" \
    -e JOBS="${JOBS:-$(nproc)}" "${EXTRA[@]}" \
    -v "$ROOT:$ROOT" -w "$ROOT" nf-gluon2021-build "$ROOT/scripts/build-local.sh" "$@"
fi

TEMPLATE="$1"; shift
TARGETS=("$@"); [ ${#TARGETS[@]} -gt 0 ] || TARGETS=(ar71xx-tiny)
. "$ROOT/build.conf"
SITEDIR="$ROOT/assembled/$TEMPLATE"
IMAGEDIR="$ROOT/images/$SBRANCH/$TEMPLATE"
echo "== Sackgasse lokal: $TEMPLATE, ${TARGETS[*]}, Release $SBRANCH, Branch $RELBRANCH"

# 1. Gluon und Patch-Repos
if [ ! -d "$ROOT/gluon/.git" ]; then
  git clone -q "$GLUON_REPO" "$ROOT/gluon"
fi
git -C "$ROOT/gluon" fetch -q origin
git -C "$ROOT/gluon" checkout -q -f "$GLUON_COMMIT"
git -C "$ROOT/gluon" clean -q -fd -e openwrt -e packages -e output -e tmp -e lede
PR="$ROOT/templates/$TEMPLATE/patchrepos"
. "$PR"
for r in $PATCHREPOS; do
  R=${r^^}; repo_var="PATCHREPO_${R}_REPO"; commit_var="PATCHREPO_${R}_COMMIT"
  d="$ROOT/patch-repos/$r"
  [ -d "$d/.git" ] || git clone -q "${!repo_var}" "$d"
  git -C "$d" fetch -q origin
  git -C "$d" checkout -q -f "${!commit_var}"
done

# 2. Site zusammenbauen
LINE="$(awk -v t="$TEMPLATE" -F'\t+' '$1 !~ /^#/ && $3 ~ "^"t"[ ]*$" {print; exit}' "$ROOT/sites.nefall.sackgasse")"
[ -n "$LINE" ] || { echo "Keine Zeile fuer $TEMPLATE in sites.nefall.sackgasse" >&2; exit 1; }
IFS=$'\t' read -r -a C <<< "$(echo "$LINE" | tr -s '\t ' '\t')"
rm -rf "$SITEDIR"; mkdir -p "$(dirname "$SITEDIR")"
cp -r -L "$ROOT/templates/$TEMPLATE" "$SITEDIR"
rep() { find "$SITEDIR" -type f -print0 | xargs -0 sed -i "s;$1;$2;g"; }
us() { echo "$1" | sed -e 's/_/ /g'; }
SSHKEYS="$(cat "$ROOT/buildkeys/${C[31]}")"
if [ -n "${EXTRA_SSH_KEY:-}" ]; then
  SSHKEYS="$SSHKEYS
	  '$(cat "$EXTRA_SSH_KEY")',"
fi
rep SBRANCH "$SBRANCH"; rep RELBRANCH "$RELBRANCH"; rep GLUONBRANCH "${C[1]}"
rep SITECODE "${C[3]}"; rep DOMAINNR "${C[4]}"; rep SITESMALL "${C[5]}"; rep SITEBIG "${C[6]}"
rep FFPREFIX "${C[7]}"; rep METAPREFIX "${C[8]}"; rep MESHSSID "${C[9]}"
rep DOMAINNAME "$(us "${C[10]}")"; rep SUPERNODEDEFAULT "${C[11]}"; rep V4PREFIX "${C[12]}"
rep V6PREFIX "${C[13]}"; rep WIFICH24 "${C[14]}"; rep WIFICH5 "${C[15]}"; rep MAPLAT "${C[16]}"
rep MAPLON "${C[17]}"; rep MAPZOOM "${C[18]}"; rep DOMAINHASH "${C[19]}"
rep METANAME "$(us "${C[20]}")"; rep METAWEBSITE "${C[21]}"; rep MAPWEBSITE "${C[22]}"
rep FWWEBSITEHOST "${C[23]}"; rep FWWEBSITETLD "${C[24]}"; rep OPKGFQDN "${C[25]}"
rep SUPERNODETLD "${C[26]}"; rep DOMAINREGIONDE "$(us "${C[27]}")"; rep DOMAINREGIONEN "$(us "${C[28]}")"
rep SETUPSKIP "${C[29]}"
rep KEYFILESIGN "$(sed ':a;N;$!ba;s/\n/\\n/g' "$ROOT/buildkeys/${C[30]}")"
rep KEYFILESSH "$(printf '%s' "$SSHKEYS" | sed ':a;N;$!ba;s/\n/\\n/g')"
rep DOMAINLONGNAME "$(us "${C[32]}")"
if grep -rq "SITECODE\|KEYFILESSH\|SBRANCH" "$SITEDIR"/site.conf "$SITEDIR"/site.mk; then
  echo "Platzhalter nicht ersetzt:" >&2; grep -rn "SITECODE\|KEYFILESSH\|SBRANCH" "$SITEDIR"/site.* >&2; exit 1
fi
lua5.1 -e "assert(loadstring('return ' .. io.open('$SITEDIR/site.conf'):read('*a')))" \
  || { echo "site.conf ist kein gueltiger Lua-Ausdruck" >&2; exit 1; }

cd "$ROOT/gluon"
ARGS=(GLUON_SITEDIR="$SITEDIR" GLUON_IMAGEDIR="$IMAGEDIR" GLUON_RELEASE="$SBRANCH"
      GLUON_AUTOUPDATER_BRANCH="$RELBRANCH" GLUON_AUTOUPDATER_ENABLED=1 BROKEN=1)

# 3. WR841 8M/16M (Gluon-Commit, legt patches/openwrt/0022-... an)
if ! grep -q "TL-WR841ND-N-Devices-for-8M-and-16M" <(ls patches/openwrt/); then
  git -c user.name=build -c user.email=build@localhost am -q "$ROOT/patches/0001-added-TP-Link-TL-WR841ND-N-Devices-for-8M-and-16M.patch"
fi

# 4. pre-update, make update
for r in $PATCHREPOS; do "$ROOT/patch-repos/$r/apply.sh" pre-update; done
make update "${ARGS[@]}"

# 5. alte Patches aus patches/ (erwarten cwd = gluon, patches unter ../patches)
for p in fix-respondd-rsk.sh fix-DIR615c1-imagetoobig.sh kernelswapon.sh ignore-preservechannels-for-outdoormode.sh; do
  echo "== patches/$p"; ( "$ROOT/patches/$p" )
done
for r in $PATCHREPOS; do "$ROOT/patch-repos/$r/apply.sh" post-update; done

# 6. bauen
for t in "${TARGETS[@]}"; do
  echo "== make GLUON_TARGET=$t"
  rc=0
  make GLUON_TARGET="$t" "${ARGS[@]}" -j "$JOBS" V=s > "$ROOT/build-$SBRANCH-$t.log" 2>&1 || rc=$?
  grep -E "^(ERROR|make\[[0-9]\]: \*\*\*)|too big" "$ROOT/build-$SBRANCH-$t.log" | tail -20 || true
  [ "$rc" -eq 0 ] || { echo "Bau $t gescheitert (rc=$rc), Log: build-$SBRANCH-$t.log" >&2; exit 1; }
done
make manifest "${ARGS[@]}"
echo "== fertig: $IMAGEDIR"
