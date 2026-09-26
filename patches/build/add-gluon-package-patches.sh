#!/bin/bash
#
# Legt den Paketpatch ab, den Gluon selbst auf das Modul packages/gluon
# anwendet:
#   0001  loescht /etc/opkg/keys beim Autoupdater-Upgrade
#
# 0100 (respondd-module-airtime) liegt seit 27.09.2026 in
# Neanderfunk/gluon-patches-fixes, package-fixes/add-gluon-airtime-plausible.sh.
#
# Laeuft in der Phase pre-update: die Datei landet unter patches/packages/gluon
# im Gluon-Baum, und "make update" spielt sie ueber scripts/patch.sh per
# "git am" auf das Modul ein. Nach "make update" abgelegt wuerde sie erst im
# naechsten Lauf wirken.
#
# Wird aus dem Gluon-Verzeichnis heraus aufgerufen, so wie prepare.sh es tut:
#   pushd ../gluon ; ../patches/build/add-gluon-package-patches.sh ; popd

. "$(dirname "${BASH_SOURCE[0]}")/../lib-patch.sh"

echo "Gluon-Paketpatches fuer make update bereitlegen"

apply_patch "$PATCH_DIR/gluon-packages.patch" \
  "patches/packages/gluon/0001-delete-etc-opkg-keys-on-autoupdater-upgrade-does-trigger-on-autoupdate-after-checking-that-the-image-is-correct.patch"
