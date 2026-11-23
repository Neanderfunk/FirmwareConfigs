#!/bin/bash
#
# Passt das Gluon-Makefile an (GLUON_TARGETS per override, .config-mtime),
# clean_output.lua (Paketausgabe bei weiteren Sites behalten) und OpenWrts
# include/image.mk (Initramfs-Kernel nur fuer Geraete, die ihn brauchen).
#
# Wird aus dem Gluon-Verzeichnis heraus aufgerufen, so wie prepare.sh es tut:
#   pushd ../gluon ; ../patches/build/patch-gluon-makefiles.sh ; popd

. "$(dirname "${BASH_SOURCE[0]}")/../lib-patch.sh"


echo "Gluon-Makefiles"

echo "- Makefile"
apply_patch "$PATCH_DIR/gluon-makefile.patch" \
  "Makefile" \
  'override GLUON_TARGETS'

# .config bei gleichem Inhalt mit alter mtime (Begruendung im Patch).
# Befund 23.11.2026 aus 26112017sta bis 26112222bro: einmal je Site-Bau linkt
# der Kernel trotzdem neu, weil Gluons "make config" prepare-tmpinfo aufruft,
# das tmp/.build jedes Mal neu setzt; target/linux laeuft dann, und
# Kernel/CompileModules loescht vmlinux. Das kostet 10 s bis 3 min je Target.
# Teuer war das Neupacken aller kmods, das behebt der Patch darunter.
echo "- Makefile: .config-mtime"
apply_patch "$PATCH_DIR/gluon-makefile-config-mtime.patch" \
  "Makefile" \
  'config.gluon-cmp'

# Weitere Site-Bauten desselben Targets behalten die Paketausgabe, sonst
# packt OpenWrt jedes Mal alle kmods neu (Begruendung im Patch).
echo "- scripts/clean_output.lua: Paketausgabe behalten"
apply_patch "$PATCH_DIR/gluon-clean-output-keep-packages.patch" \
  "scripts/clean_output.lua" \
  'NF_KEEP_TARGET_PACKAGES'

# Initramfs-Kernel nur fuer Geraete, deren Images ihn nennen (Begruendung im
# Patch). Befund 23.11.2026, 26112304bro: mediatek-filogic baute je Site 30
# Initramfs-Kernel, jeder mit eigener Kopie des Kernel-Baums (174 GB cp, gut
# 30 min). Laeuft nach "make update", das den OpenWrt-Baum neu aufsetzt.
echo "- openwrt/include/image.mk: Initramfs nur, wo ein Image ihn braucht"
(
  enter_dir openwrt
  apply_patch "$PATCH_DIR/openwrt-initramfs-only-where-used.patch" \
    "include/image.mk" \
    'Device/UsesInitramfs'
)

# Der Paketpatch fuer packages/gluon steht nicht mehr hier, sondern in
# add-gluon-package-patches.sh: "make update" spielt ihn ein, er muss also
# vorher abgelegt sein.

