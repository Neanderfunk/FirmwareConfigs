#!/bin/bash
#
# Passt das Gluon-Makefile an (GLUON_TARGETS per override, .config-mtime).
#
# Wird aus dem Gluon-Verzeichnis heraus aufgerufen, so wie prepare.sh es tut:
#   pushd ../gluon ; ../patches/build/patch-gluon-makefiles.sh ; popd

. "$(dirname "${BASH_SOURCE[0]}")/../lib-patch.sh"


echo "Gluon-Makefiles"

echo "- Makefile"
apply_patch "$PATCH_DIR/gluon-makefile.patch" \
  "Makefile" \
  'override GLUON_TARGETS'

# .config bei gleichem Inhalt mit alter mtime, sonst linkt jeder weitere
# Site-Bau desselben Targets den Kernel neu (Begruendung im Patch).
echo "- Makefile: .config-mtime"
apply_patch "$PATCH_DIR/gluon-makefile-config-mtime.patch" \
  "Makefile" \
  'config.gluon-prev'

# Der Paketpatch fuer packages/gluon steht nicht mehr hier, sondern in
# add-gluon-package-patches.sh: "make update" spielt ihn ein, er muss also
# vorher abgelegt sein.

