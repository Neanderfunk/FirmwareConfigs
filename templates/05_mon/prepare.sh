#!/bin/bash
# Sackgasse 2021.1: wirkungslose Schritte entfernt (Mi 4A Gigabit, Archer A7 v5,
# radiooffcrash, siehe docs/ueberarbeitung-2026.md). scripts/build-local.sh fuehrt
# dieselben Schritte in der richtigen Reihenfolge um make update herum aus.
# git apply $(dirname $0)/keepradiochannel.diff
# echo "CONFIG_PATA_ATIIXP=y" >> openwrt/target/linux/x86/generic/config-default
 
#cp ../patches/sysupgrade ./openwrt/package/base-files/files/sbin/sysupgrade
#chmod +x ./openwrt/package/base-files/files/sbin/sysupgrade

pushd ../gluon ; git am ../patches/0001-*; popd ; # apply 0001-enumerated patches automaticylly
pushd ../gluon ; ../patches/fix-respondd-rsk.sh; popd  # change respondd listener address to gluon 2016.x value
pushd ../gluon ; ../patches/kernelswapon.sh; popd # enable swap for all
pushd ../gluon ; ../patches/ignore-preservechannels-for-outdoormode.sh ; popd # correct handling of outdoor-devices (enable auto-channel)
exit 0;

