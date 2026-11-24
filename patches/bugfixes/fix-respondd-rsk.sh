#!/bin/bash
#
# Setzt die respondd-Listener-Adresse auf den Wert von Gluon 2016.x zurueck.
#
# Was sich aendert: respondd lauscht auf ff02::1 und ff02::2:1001, jeweils auf
# den Mesh- und den Client-Schnittstellen. Gluon selbst sieht seit 2021.x
# ff02::2:1001 auf den Mesh-Schnittstellen und ff05::2:1001 auf den
# Client-Schnittstellen vor.
#
# Warum: Die Karte fragt respondd auf ff02::1. Auf Gluons ff05::2:1001
# antworten in unserem Netz gemessen nur die Supernodes, nicht die Knoten.
# Ueber batman ist ff02::1 kein Nachteil, weil das ganze Mesh eine
# Broadcast-Domain ist. Erst mit den Adressen von Gluon 2016.x beantworten die
# Knoten diese Abfrage.
#
# Der Patch ist damit Voraussetzung fuer die Karte: Ohne ihn zeigt sie nur die
# Supernodes. Er darf nicht entfallen, solange die Karte so abfragt.
#
# Wird aus dem Gluon-Verzeichnis heraus aufgerufen, so wie prepare.sh es tut:
#   pushd ../gluon ; ../patches/bugfixes/fix-respondd-rsk.sh ; popd

. "$(dirname "${BASH_SOURCE[0]}")/../lib-patch.sh"

echo "respondd: Listener-Adresse auf den Gluon-2016.x-Wert"

apply_patch "$PATCH_DIR/fix-respondd-rsk.patch" \
  "package/gluon-respondd/files/etc/init.d/gluon-respondd" \
  'ff02::1'
