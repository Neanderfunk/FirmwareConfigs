-- images-customization.lua for Freifunk im Neanderland - gluon 2025.1.x

features {
    'autoupdater',
    'ebtables',
    'ebtables-filter-multicast',
    'ebtables-filter-ra-dhcp',
    'ebtables-limit-arp',
    'ebtables-source-filter',
    'mesh-batman-adv-15',
    -- Tunneldigger ist seit Gluon 2025.1 kein Feature mehr (#3109): das Paket
    -- ff-mesh-vpn-tunneldigger (community) unten, dazu die Config-Mode-Seite.
    'config-mode-mesh-vpn',
    'respondd',
    'status-page',
    'web-advanced',
    'web-wizard',
    'config-mode-geo-location-osm',
    'radv-filterd',
    'radvd',
    'authorized-keys',
    'web-private-wifi',
}


-- Herkunft hinter jedem Paket. Die Feeds und ihre Pins stehen nebenan in
-- "modules":
--
--   gluon             Gluon selbst, gluon/package/
--   gluon-packages    Feed "gluon"        freifunk-gluon/packages
--   community         Feed "community"    freifunk-gluon/community-packages
--   neanderfunk       Feed "neanderfunk"  Neanderfunk/packages
--   openwrt           OpenWrt-Basis
--   openwrt-packages  OpenWrt-Feed "packages"
--
-- Vorsicht: der Namensvorsatz sagt nichts ueber den Feed.
-- Die ffac-Pakete liegen unter 2025.1 alle in den community-packages, einen
-- eigenen ffac-Feed gibt es nicht mehr.
packages {
    'ff-mesh-vpn-tunneldigger',           -- community (ersetzt das Feature mesh-vpn-tunneldigger)
    'gluon-ebtables-filter-ra-dhcp',      -- gluon
    'respondd-module-airtime',            -- gluon-packages
    'iwinfo',                             -- openwrt
    -- Bewusst kein haveged mehr: Entropie liefert unter OpenWrt 23.05 urngd,
    -- und der Kernel 5.15 initialisiert seinen CRNG auch ohne Hilfe. haveged
    -- kostete ~1,6 MB RSS (WDR3600), auf 64-MB-Geraeten zu viel.
    'socat',                              -- openwrt-packages
    'wireless-tools', 			  -- openwrt-packages
    'kmod-sched',                         -- openwrt, fuer socat
    'libc',                               -- openwrt, fuer socat
    'libpthread',                         -- openwrt, fuer socat
    'librt',                              -- openwrt, fuer socat
    'neanderfunk-weeklyreboot',           -- neanderfunk
    'neanderfunk-hotfix',                 -- neanderfunk
    'neanderfunk-linkcheck',              -- neanderfunk (wieder aktiv, Bugs 2026-09-06 behoben)
    'neanderfunk-txpowerfix',             -- neanderfunk
    'neanderfunk-preserve-wifichannel',   -- neanderfunk (ohne das Paket wirkt wifi24.preserve_channels der site.conf nicht)
    'neanderfunk-banner',                 -- neanderfunk
    'neanderfunk-migrate-updatebranch',   -- neanderfunk
    'neanderfunk-wifi-blackout',          -- neanderfunk (war eulenfunk-ath9kblackout)
    'neanderfunk-ssid-changer',           -- neanderfunk
    'neanderfunk-nodeplacer',             -- neanderfunk
    'neanderfunk-button-bind',            -- neanderfunk (Fork von ffffm-button-bind, Konflikt deklariert)
    'neanderfunk-node-whisperer',         -- neanderfunk (Fork von ffda-node-whisperer, Konflikt deklariert)
    'neanderfunk-ap-timer',               -- neanderfunk (ff-ap-timer + ff-web-ap-timer, Konflikt deklariert)
    'neanderfunk-respondd',               -- neanderfunk (respondd: Hardware, Radios, Offline-SSID, Ethernet; C)
    -- Config-Mode auf einer Seite, neues Theme. Das Theme-Paket liefert wie
    -- gluon-config-mode-theme view/theme/layout.html (PROVIDES), deshalb muss
    -- Gluons Theme raus, sonst bricht opkg den Image-Bau ab. Zurueck zum
    -- alten Config-Mode: beide Zeilen entfernen.
    '-gluon-config-mode-theme',           -- gluon
    'neanderfunk-setup-mode',             -- neanderfunk (zieht neanderfunk-config-mode-theme)
    'neanderfunk-setup-wifi',             -- neanderfunk (Setup-WLAN, site.conf setup_mode.wifi; ohne Funk wirkungslos)
    'ffac-autoupdater-wifi-fallback',     -- community
    'ffbs-collect-debug-info',            -- community
    'ffbs-debugbathosts',                 -- community
}
-- Bewusst NICHT: ffmuc-ipv6-ra-filter. Beim schnellen Wechsel der Supernodes
-- einer Domain bleibt der Filter lange sticky, die Knoten bekommen keinen
-- Kontakt zum neuen Supernode.

-- "all devices" section finished

-- 64 MB RAM und zwei Radios: RAM-Druck bis zum OOM. Auf dem Archer C25 v1
-- (ath9k + ath10k) bleiben fuer den Datei-Cache rund 3 MB, jeder Cron-Job
-- laedt Lua dann vom Flash (Paketfeed-Session, 12.09.2026). Gluon fuehrt die
-- meisten davon deshalb als broken ("64M ath9k + ath10k", "OOM with 5GHz").
-- Liste aus Gluons Device-Definitionen und der OpenWrt Table of Hardware
-- (RAM, Baender): alle Geraete unserer Targets mit 64 MB und 2 Radios.
-- Archer C60 v1, D50 v1 und WNDR3700 v1/v2 sind bei Gluon nicht 'tiny' und
-- bekaemen sonst tls, wpa3, sqm und usteer.
-- Ausfuehrlich: router-werkstatt docs/ramdruck-64mb.md, oeffentlich
-- freifunk-docs lowmem-dualband-64mb-2023.2.md.
local lowmem_dualradio = device({
    'avm-fritz-wlan-repeater-1750e',   -- ath9k + ath10k
    'tp-link-archer-c2-v3',            -- ath9k + ath10k
    'tp-link-archer-c25-v1',           -- ath9k + ath10k
    'tp-link-archer-c58-v1',           -- ath9k + ath10k
    'tp-link-archer-c60-v1',           -- ath9k + ath10k
    'tp-link-archer-d50-v1',           -- ath9k + ath10k
    'tp-link-tl-wr902ac-v1',           -- ath9k + ath10k
    'd-link-dir825b1',                 -- 2x ath9k
    'netgear-wndr3700',                -- 2x ath9k
    'netgear-wndr3700-v2',             -- 2x ath9k
    'avm-fritz-wlan-repeater-300e',    -- 2x ath9k
    'openmesh-om5p',                   -- 2x ath9k
    'tp-link-cpe510-v2',               -- 2x ath9k
    'ubiquiti-nanobeam-m5-xw',         -- 2x ath9k
    'netgear-r6120',                   -- mt7603 + mt76x2 (ramips-mt76x8, 16 MB Flash)
    'tp-link-archer-c50-v3',           -- mt7603 + mt76x2 (ramips-mt76x8)
    'cudy-wr1000',                     -- mt7603 + mt76x2 (ramips-mt76x8)
    'tp-link-archer-c20i',             -- rt2800soc + mt76x0e (ramips-mt7620)
})

-- Geraete mit 64 MB RAM und nur einem Funkteil. Sie thrashen nicht wie die
-- Dualband-Geraete (77-81 % Speicher, load unter 0,1), sind aber dieselbe
-- Speicherklasse: 134 im Feld, vor allem die 1043-Familie und die CPE210.
-- Quelle der Liste: werkzeug-Erhebung geraete-ram.tsv (RAM je Geraet aus den
-- Gluon-Targets und dem OpenWrt-ToH). Nur ath79 ist darin vollstaendig;
-- Einzelradio-Geraete anderer Targets fehlen also noch.
local lowmem_singleradio = device({
    'alfa-network-ap121f',
    'avm-fritz-wlan-repeater-450e',
    'd-link-dap-1330-a1',
    'd-link-dir-505',
    'gl.inet-gl-ar150',
    'gl.inet-gl-usb150',
    'netgear-wnr2200-16m',
    'netgear-wnr2200-8m',
    'onion-omega',
    'openmesh-om2p-hs-v1',
    'openmesh-om2p-hs-v2',
    'openmesh-om2p-hs-v3',
    'openmesh-om2p-hs-v4',
    'openmesh-om2p-lc',
    'openmesh-om2p-v2',
    'openmesh-om2p-v4',
    'plasma-cloud-pa300',
    'teltonika-rut230-v1',
    'tp-link-cpe210-v1',
    'tp-link-cpe210-v2',
    'tp-link-cpe210-v3',
    'tp-link-cpe220-v3',
    'tp-link-tl-wr1043n-v5',
    'tp-link-tl-wr1043nd-v2',
    'tp-link-tl-wr1043nd-v3',
    'tp-link-tl-wr1043nd-v4',
    'tp-link-wbs210-v1',
    'tp-link-wbs210-v2',
    'ubiquiti-unifi-ap-outdoor+',
})

local lowmem_64m = lowmem_dualradio or lowmem_singleradio

if lowmem_64m then
    packages {
        -- Komprimierter Swap im RAM (Standard: halber RAM, lzo-rle). Selten
        -- genutzte Seiten der Daemons werden komprimiert, das laesst mehr
        -- Platz fuer den Datei-Cache. Zieht kmod-zram und die busybox-Applets
        -- swapon/mkswap (die dann im ganzen Target mitkommen, wenige kB).
        'zram-swap',                   -- openwrt

        -- procd-ujail raus: Die Sandbox kostet einen zusaetzlichen Prozess je
        -- gejailtem Dienst, am TL-WR1043ND v2 gemessen 3,7 MB RSS fuer
        -- dnsmasq, hostapd und ntpd zusammen. procd startet die Dienste ohne
        -- /sbin/ujail einfach ungejailt. Bewusste Abwaegung (adorfer
        -- 16.09.2026): Haertung gegen Speicher, auf genau den Geraeten, die
        -- sonst ins Thrashing laufen oder taub werden.
        '-procd-ujail',                -- openwrt
    }
end

-- Geraete, deren Rootfs unter 2025.1 nicht mehr in die Flash-Partition passt.
-- Sie verzichten nur auf Komfort- und Backend-Funktionen (tls, sftp, sqm);
-- WLAN bleibt voll (wpa3, usteer). Gemessen am ersten Testbau 27.09.2026
-- (xz, wie im squashfs): sqm 146516 Byte (davon tc-tiny 110300), tls 108652
-- (ca-bundle 103552), sftp 46708, zusammen 301876.
-- Archer C6 v2: Rootfs 5390716 Byte, safeloader-Grenze 5215232 (factory),
-- fehlten 175484; danach rund 126 kB Luft. Archer C7 v4: 5207672 Byte, nur
-- 7560 unter der Grenze. Wird es wieder eng: '-opkg' waere der naechste
-- Kandidat (adorfer 27.09.2026).
local lowflash = device({
    'tp-link-archer-c6-v2-eu-ru-jp',   -- ath79, safeloader
    'tp-link-archer-c7-v4',            -- ath79, safeloader
})

if not device_class('tiny') and not lowmem_dualradio then
    features {
        'wireless-encryption-wpa3',
        'web-cellular',
    }
    packages {
        'ffda-gluon-usteer',              -- community
    }
    if not lowflash then
        features {
            'tls',
            'mesh-vpn-sqm',
        }
        packages {
            'openssh-sftp-server',
        }
    end
end

if device({
        'zte-mf281',
        'gl.inet-gl-xe300',
        'gl.inet-gl-ap1300',
        'zte-mf289f',
        'zte-mf286r',
        'wavlink-ws-wn572hp3-4g',
        'tp-link-tl-mr6400-v5',
    }) then
    features {
        'web-cellular',
    }
    packages {
        'ffac-web-private-wan-dhcp',      -- community
    }
end

pkgs_usb = {
    'usbutils',                          -- openwrt-packages
}

pkgs_hid = {
    'kmod-usb-hid',
    'kmod-hid-generic',
}

pkgs_usb_serial = {
    'kmod-usb-serial',
    'kmod-usb-serial-ftdi',
    'kmod-usb-serial-pl2303',
}

pkgs_usb_storage = {
    'block-mount',
    'blkid',
    'kmod-fs-ext4',
    'kmod-fs-ntfs',
    'kmod-fs-vfat',
    'kmod-usb-storage',
    'kmod-usb-storage-extras',-- Card Readers
    'kmod-usb-storage-uas', -- USB Attached SCSI (UAS/UASP)
    'kmod-nls-base',
    'kmod-nls-cp1250',      -- NLS Codepage 1250 (Eastern Europe)
    'kmod-nls-cp437',       -- NLS Codepage 437 (United States, Canada)
    'kmod-nls-cp850',       -- NLS Codepage 850 (Europe)
    'kmod-nls-cp852',       -- NLS Codepage 852 (Europe)
    'kmod-nls-iso8859-1',   -- NLS ISO 8859-1 (Latin 1)
    'kmod-nls-iso8859-13',  -- NLS ISO 8859-13 (Latin 7; Baltic)
    'kmod-nls-iso8859-15',  -- NLS ISO 8859-15 (Latin 9)
    'kmod-nls-iso8859-2',   -- NLS ISO 8859-2 (Latin 2)
    'kmod-nls-utf8',        -- NLS UTF-8
}

pkgs_usb_net = {
    'kmod-mii',
    'kmod-usb-net',
    'kmod-usb-net-asix',
    'kmod-usb-net-asix-ax88179',
    'kmod-usb-net-cdc-eem',
    'kmod-usb-net-cdc-ether',
    'kmod-usb-net-cdc-subset',
    'kmod-usb-net-dm9601-ether',
    'kmod-usb-net-hso',
    'kmod-usb-net-ipheth',
    'kmod-usb-net-mcs7830',
    'kmod-usb-net-pegasus',
    'kmod-usb-net-rndis',
    'kmod-usb-net-rtl8152',
    'kmod-usb-net-smsc95xx',
}

pkgs_pci = {
    'pciutils',                          -- openwrt-packages
    'kmod-bnx2', -- Broadcom NetExtreme BCM5706/5708/5709/5716
}

include_usb = true

-- rtl838x has no USB support as of Gluon v2023.2
if target('realtek', 'rtl838x') or target('ramips', 'mt7620') then
    include_usb = false
end

-- 7M usable firmware space + USB port
if target('ath79', 'generic') and not device({
    'devolo-wifi-pro-1750e',
    'gl.inet-gl-ar150',
    'gl.inet-gl-ar300m-lite',
    'gl.inet-gl-ar750',
    'joy-it-jt-or750i',
    'netgear-wndr3700-v2',
    'tp-link-archer-a7-v5',
    'tp-link-archer-c5-v1',
    'tp-link-archer-c7-v2',
    'tp-link-archer-c7-v5',
    'tp-link-archer-c59-v1',
    'tp-link-tl-wr842n-v3',
    'tp-link-tl-wr1043nd-v4',
    'tp-link-tl-wr1043n-v5',
}) then
    include_usb = false
end

if target('ramips', 'mt76x8') and not device({
    'gl-mt300n-v2',
    'gl.inet-microuter-n300',
    'netgear-r6120',
    'ravpower-rp-wd009',
}) then
    include_usb = false
end


-- 7M usable firmware space + USB port
if device({
    'avm-fritz-box-7412',
    'tp-link-td-w8970',
    'tp-link-td-w8980',
    'gl-mt300n-v2',
    'gl.inet-microuter-n300',
    'netgear-r6120',
    'ravpower-rp-wd009'
}) then
    include_usb = false
end

-- devices without usb ports
if device({
    'ubiquiti-unifi-6-lr-v1',
    'netgear-ex6150',
    'netgear-ex3700',
    'ubiquiti-edgerouter-x',
    'ubiquiti-edgerouter-x-sfp',
    'zyxel-nwa55axe',
}) then
    include_usb = false
end

if include_usb then
    packages(pkgs_usb)
    packages(pkgs_usb_net)
    packages(pkgs_usb_serial)
    packages(pkgs_usb_storage)
    packages {'ffka-gluon-web-usb-wan-hotplug', 'ffac-update-location-gps'}  -- beide community
end

-- VORUEBERGEHEND (14.09.2026): ethtool auf den Geraeten mit Realtek RTL8221B
-- am 2,5G-Port (TR3000 laut DTS; WR3000H v1 und M3000 laut OpenWrt-Forum,
-- neuere Revisionen teils mit Motorcomm YT8821). Nicht noetig bei GL-MT3000,
-- NWA50AX Pro, MR90X, TUF-AX4200: dort MaxLinear GPY211C. Zur Diagnose des Link-Problems
-- (openwrt/openwrt#17505; freifunk-docs rtl8221b-2g5-wan-2023.2.md): Link-Zustand
-- ansehen (ethtool eth0) und Aushandlung ohne Neustart neu anstossen
-- (ethtool -r eth0). Wieder raus, sobald geklaert ist, ob ein Port-Reset statt
-- eines Neustarts hilft.
if device({
    'cudy-tr3000-v1',
    'cudy-tr3000-256mb-v1',
    'cudy-wr3000h-v1',
    'cudy-m3000-v1',
}) then
    packages {'ethtool'}                 -- openwrt
end

-- device has no reset button and requires a special package to go into setup mode
-- https://github.com/freifunk-gluon/community-packages/tree/master/ffda-network-setup-mode
if device({
    'zyxel-nwa55axe',
}) then
    packages {'ffda-network-setup-mode'}  -- community
    broken(false)
end

if target('x86', '64') then
    -- add guest agent for qemu and vmware
    packages {
        'qemu-ga',
        'open-vm-tools',                 -- openwrt-packages
    	'kmod-vmxnet3',
    }
end

if target('x86') and not target('x86', 'legacy') then
    packages(pkgs_pci)
    packages(pkgs_hid)
end

if target('bcm27xx') then
    packages(pkgs_hid)
end

-- mt7915: Unter 2023.2 kamen hier ffac-mt7915-maxinactivity und
-- neanderfunk-mt7915-backlog hinzu (Backlog, openwrt/mt76#1009). Unter 2025.1
-- gibt es ffac-mt7915-maxinactivity nicht mehr, und der Feed hat
-- neanderfunk-mt7915-backlog entfernt (038debe: der Fix steckt in 2025.1 im
-- Treiber, OpenWrt 24.10 bringt mt76 vom 2025-11-06). Grundlage
-- docs/mt7915-analyse.md.

-- EdgeRouter X und X-SFP: bis auf Weiteres keine Images (adorfer 27.09.2026).
-- Der Wechsel auf 2025.1 braucht dort ein neues Flash-Layout
-- (darkxst/erx-migration), die Migration ruht. Ohne Image steht das Geraet
-- nicht im Manifest, der Autoupdater eines ERX auf 2023.2 findet also nichts
-- und laedt nichts; die Knoten bleiben auf 2023.2.6.
if device({
    'ubiquiti-edgerouter-x',
    'ubiquiti-edgerouter-x-sfp',
}) then
    disable()
end
