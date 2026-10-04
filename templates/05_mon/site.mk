# site.mk for Freifunk im Neanderland - gluon 2018.1.x

# for feature packs see https://github.com/freifunk-gluon/gluon/blob/v2018.2.x/package/features
GLUON_FEATURES := \
	mesh-batman-adv-15 \
	respondd \
 	autoupdater \
	ebtables \
	ebtables-limit-arp \
	radv-filterd \
	ebtables-filter-multicast \
	ebtables-filter-ra-dhcp \
	ebtables-source-filter \
        mesh-vpn-tunneldigger \
	status-page\

# neanderfunk (Feed Neanderfunk/packages v2021.1.x):
GLUON_SITE_PACKAGES := \
        respondd-module-airtime \
        neanderfunk-weeklyreboot \
        neanderfunk-common \
        neanderfunk-hotfix \
        neanderfunk-txpowerfix \
        neanderfunk-banner \
        neanderfunk-linkcheck \
        gluon-authorized-keys \
        neanderfunk-migrate-updatebranch \
        neanderfunk-legacy-migrate \
        neanderfunk-wifi-blackout \
        neanderfunk-respondd \
        neanderfunk-preserve-wifichannel \
        neanderfunk-button-bind \
        neanderfunk-ssid-changer \
        ffac-autoupdater-wifi-fallback \
        neanderfunk-nodeplacer


# openwrt:
# haveged und socat raus (adorfer 04.10.2026): urngd liefert die Entropie, socat
# nutzte nichts im Image; zusammen rund 75 KiB Flash.
GLUON_SITE_PACKAGES += \
	iptables \
	iwinfo \
        kmod-sched \
        libc \
        libpthread \
        librt

ifeq ($(GLUON_TARGET),ar71xx-tiny)
GLUON_SITE_PACKAGES += zram-swap
endif

ifeq ($(GLUON_TARGET),ar71xx-generic)
GLUON_SITE_PACKAGES += zram-swap
endif


ifeq ($(GLUON_TARGET),x86-generic)
	GLUON_SITE_PACKAGES += \
		$(USB_BASIC) \
		kmod-usb-ohci-pci \
		$(USB_NIC)
endif

ifeq ($(GLUON_TARGET),x86-64)
	GLUON_SITE_PACKAGES += \
		$(USB_BASIC) \
		$(USB_NIC) \
		qemu-ga #VMs
endif

DEFAULT_GLUON_RELEASE := SBRANCH

# Allow overriding the release number from the command line
GLUON_RELEASE ?= $(DEFAULT_GLUON_RELEASE)

GLUON_PRIORITY ?= 0
GLUON_LANGS ?= en
GLUON_REGION ?= eu
GLUON_ATH10K_MESH ?= 11s
GLUON_WLAN_MESH ?= 11s
GLUON_DEPRECATED ?= full
