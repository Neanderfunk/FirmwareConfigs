#!/usr/bin/env python3
"""Erzeugt templates/common/usb-geraete.lua: die Gluon-Geraete mit USB-Port.

Aufruf mit einem Gluon-Baum, in dem "make update" und alle Patches gelaufen
sind (sonst fehlen unsere zusaetzlichen Geraete):

    scripts/usb-geraete.py <gluon-baum> > templates/common/usb-geraete.lua

Quelle ist OpenWrts eigene Auswertung der Geraeteprofile
(openwrt/tmp/.targetinfo, wird bei Bedarf per "make prepare-tmpinfo"
erzeugt) plus Device-Tree. Ein Geraet gilt als USB-faehig, wenn beides
zutrifft:

1. Nach Target-Standardpaketen und Profilpaketen (samt "-paket"-Abwahl)
   bleibt ein USB-Host-Treiber uebrig. Allein reicht das nicht: gemeinsame
   Geraetevorlagen (etwa Device/ubnt-bz) und ipq40xx/ipq806x ziehen USB auch
   fuer Geraete ohne Port.
2. Der Device-Tree des Geraets schaltet einen USB-Knoten ein (status "okay"
   nach allen lokalen Includes). Allein reicht das auch nicht: mt7621.dtsi
   laesst xhci von Haus aus an, auch beim Mi Router 4A ohne Port.

Findet sich kein Device-Tree im OpenWrt-Baum (DTS nur im Kernel), zaehlt
Bedingung 1 allein; solche Geraete stehen im Kopf der erzeugten Datei.
Gluon kennt diese Information in image-customization.lua nicht.

Targets, deren USB-Host im Kernel steckt und deshalb in keiner Paketliste
auftaucht (x86, bcm27xx, rockchip), entscheidet image-customization.lua
selbst.
"""
import os
import re
import subprocess
import sys

HOST = re.compile(r'^kmod-(usb2|usb2-pci|usb3|usb-ohci|usb-ehci|usb-uhci|usb-dwc2|'
                  r'usb-dwc3|usb-dwc3-qcom|usb-xhci[a-z0-9-]*|usb-chipidea[a-z0-9-]*|'
                  r'usb-fotg210|usb-ledtrig-usbport)$')


USBNAME = re.compile(r'usb|ehci|ohci|xhci|ssusb|dwc3|dwc2|otg', re.I)
NODE = re.compile(r'^\s*(?:([A-Za-z_][\w]*)\s*:\s*)?(&[A-Za-z_][\w]*|/|[A-Za-z_][\w,.+-]*(?:@[\w,.]+)?)\s*\{')

def index_dts(root):
    idx = {}
    for d, _, fs in os.walk(root):
        for f in fs:
            if f.endswith(('.dts', '.dtsi')):
                idx.setdefault(f, []).append(os.path.join(d, f))
    return idx

def by_compat(idx):
    m = {}
    for f, paths in idx.items():
        if not f.endswith('.dts'):
            continue
        for p in paths:
            t = open(p, errors='replace').read()
            mm = re.search(r'^/\s*\{.*?compatible\s*=\s*"([^"]+)"', t, re.S | re.M)
            if mm:
                m.setdefault(mm.group(1), p)
    return m

def usb_enabled(path, idx):
    """Folgt den lokalen #include/'/include/' in Reihenfolge und wertet status aus."""
    state = {}   # key -> enabled bool
    isusb = {}
    seen = set()
    def walk(p):
        if p in seen:
            return
        seen.add(p)
        stack = []
        text = open(p, errors='replace').read()
        text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
        for line in text.splitlines():
            line = re.sub(r'//.*', '', line)
            inc = re.match(r'\s*(?:#include|/include/)\s*[<"]([^>"]+)[>"]', line)
            if inc:
                name = os.path.basename(inc.group(1))
                cand = idx.get(name, [])
                same = [c for c in cand if os.path.dirname(c) == os.path.dirname(p)]
                for c in (same or cand)[:1]:
                    walk(c)
                continue
            m = NODE.match(line)
            if m:
                label, name = m.group(1), m.group(2)
                key = name[1:] if name.startswith('&') else (label or name + '#' + str(len(stack)))
                stack.append(key)
                if not name.startswith('&'):
                    state.setdefault(key, True)
                if USBNAME.search(name) or (label and USBNAME.search(label)):
                    isusb[key] = True
                if label and label != key:
                    pass
                if '};' in line[m.end():]:
                    stack.pop()
                continue
            if stack:
                st = re.search(r'status\s*=\s*"(\w+)"', line)
                if st:
                    state[stack[-1]] = st.group(1) in ('okay', 'ok')
                if re.search(r'compatible\s*=.*"[^"]*(usb|ehci|ohci|xhci|dwc3|dwc2)[^"]*"', line):
                    isusb[stack[-1]] = True
            for _ in range(line.count('};')):
                if stack:
                    stack.pop()
    walk(path)
    return any(state.get(k, False) for k in isusb), [k for k in isusb if state.get(k)]


def git_head(path):
    r = subprocess.run(['git', '-C', path, 'rev-parse', '--short=12', 'HEAD'],
                       capture_output=True, text=True)
    return r.stdout.strip() or '?'


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    gluon = sys.argv[1]
    openwrt = os.path.join(gluon, 'openwrt')
    info = os.path.join(openwrt, 'tmp', '.targetinfo')
    if not os.path.exists(info):
        subprocess.run(['make', '-C', openwrt, 'prepare-tmpinfo'], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Target "t/sub" -> (Standardpakete, {Profil: Paketliste})
    targets = {}
    compat = {}
    cur = None
    for line in open(info, encoding='utf-8', errors='replace'):
        if line.startswith('Target: '):
            cur = line.split()[1]
            targets.setdefault(cur, [set(), {}])
            prof = None
        elif line.startswith('Default-Packages:') and cur:
            targets[cur][0] = set(line.split()[1:])
        elif line.startswith('Target-Profile: DEVICE_') and cur:
            prof = line.split()[1][len('DEVICE_'):]
            targets[cur][1][prof] = []
            compat[(cur, prof)] = []
        elif line.startswith('Target-Profile-Packages:') and cur and prof:
            targets[cur][1][prof] = line.split()[1:]
        elif line.startswith('Target-Profile-SupportedDevices:') and cur and prof:
            compat[(cur, prof)] = [c for c in line.split()[1:] if ',' in c]

    def has_usb(target, profile):
        default, profiles = targets.get(target, (set(), {}))
        if profile not in profiles:
            return None
        pkgs = set(default)
        for p in profiles[profile]:
            if p.startswith('-'):
                pkgs.discard(p[1:])
            else:
                pkgs.add(p)
        return any(HOST.match(p) for p in pkgs)

    dts_cache = {}

    def dts_usb(target, profile):
        t = target.split('/')[0]
        if t not in dts_cache:
            idx = index_dts(os.path.join(openwrt, 'target', 'linux', t))
            dts_cache[t] = (idx, by_compat(idx))
        idx, bc = dts_cache[t]
        for c in compat.get((target, profile), []):
            if c in bc:
                return usb_enabled(bc[c], idx)[0]
        return None

    dev_re = re.compile(r"^device\('([^']+)',\s*'([^']+)'", re.M)
    mit, unbekannt, ohne_dts = [], [], []
    tdir = os.path.join(gluon, 'targets')
    for name in sorted(os.listdir(tdir)):
        if '-' not in name or name.endswith('.inc') or name.endswith('.mk'):
            continue
        target = name.replace('-', '/', 1)
        text = open(os.path.join(tdir, name), encoding='utf-8').read()
        for image, profile in dev_re.findall(text):
            r = has_usb(target, profile)
            if r is None:
                unbekannt.append(f'{name}: {image} ({profile})')
                continue
            if not r:
                continue
            d = dts_usb(target, profile)
            if d is None:
                ohne_dts.append(f'{name}: {image}')
                mit.append((name, image))
            elif d:
                mit.append((name, image))

    print('-- ERZEUGT von scripts/usb-geraete.py, nicht von Hand aendern.')
    pin = '?'
    for line in open(os.path.join(gluon, 'modules'), encoding='utf-8'):
        if line.startswith('OPENWRT_COMMIT='):
            pin = line.split('=', 1)[1].strip()[:12]
    print(f'-- Gluon {git_head(gluon)}, OpenWrt-Pin {pin} samt Gluon- und eigenen Patches.')
    print('-- Gluon-Geraete mit USB-Port: OpenWrt-Profil bringt einen USB-Host-Treiber')
    print('-- mit UND der Device-Tree schaltet einen USB-Knoten ein.')
    print('-- Eingebunden von image-customization.lua per include().')
    for u in ohne_dts:
        print(f'-- ohne Device-Tree im OpenWrt-Baum, nur nach Paketen: {u}')
    for u in unbekannt:
        print(f'-- ohne OpenWrt-Profil, nicht bewertet: {u}')
    print('return device({')
    last = None
    for target, image in mit:
        if target != last:
            print(f'    -- {target}')
            last = target
        print(f"    '{image}',")
    print('})')


if __name__ == '__main__':
    main()
