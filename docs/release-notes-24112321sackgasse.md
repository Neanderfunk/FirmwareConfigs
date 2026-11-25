# Release Notes 24112321sackgasse

**Neanderfunk-Firmware "Sackgasse" auf Basis von Gluon 2021.1**

Version `24112321sackgasse`, gebaut für 30 Domains.

Die Sackgasse ist die Firmware für Router, die unsere aktuelle Firmware nicht
mehr vertragen. Welche Geräte das sind, steht in den
[Release Notes 24112319sackgasse](release-notes-24112319sackgasse.md).

**Wo es die Firmware gibt:** auf dem
[Firmware-Server](https://firmware.ffnef.de/firmware/sackgasse/), nach Domain
sortiert.

**Auto-Update:** Router im Zweig `sackgasse` mit eingeschaltetem Auto-Update
holen sich diese Version von selbst. Die Einstellungen bleiben erhalten.

Diese Release Notes beschreiben, was sich seit `24112319sackgasse` geändert
hat. Gluon, OpenWrt, Paketfeed und Patches sind unverändert.

Rückmeldungen bitte an:

- E-Mail: [projekt@neanderfunk.de](mailto:projekt@neanderfunk.de)
- Mastodon: [@neanderfunk@nrw.social](https://nrw.social/@neanderfunk)
- Telegram: [Neanderfunk-Gruppe](https://t.me/+_rWKhNAJyvg5MWY0)

## Basis

| | |
|---|---|
| Gluon | [`3181e496`](https://github.com/freifunk-gluon/gluon/commit/3181e496f4b79234beec1a90ed9fca206a6708c7) (Zweig v2021.1.x), wie 24112319sackgasse |
| Site und Build | [FirmwareConfigs `bc98a58`](https://github.com/Neanderfunk/FirmwareConfigs/tree/bc98a58) |
| Paketfeed | [Neanderfunk/packages `6e6fa53`](https://github.com/Neanderfunk/packages/tree/6e6fa53), wie 24112319sackgasse |
| Targets | `ar71xx-tiny`, `ar71xx-generic` |

## Adressplan der Supernodes

- **IPv4 je Domain:** Das Client-Netz ist jetzt `10.NN.0.0/16`, `NN` ist die
  Domainnummer ohne führende Null (Velbert `10.1.0.0/16`, Mettmann
  `10.2.0.0/16` usw.). Bisher galt für alle `10.0.0.0/8`.
- **next_node:** Die IPv4-Adresse, unter der jeder Router seine eigene
  Statusseite zeigt, ist jetzt `10.NN.0.1`. Name (`nextnode`, `nn`) und
  IPv6-Adresse bleiben.

## Reserve-Supernodes

- **`carme` und `ananke`** stehen jetzt als weitere Reserve hinter `lysithea`
  in der Firmware, zusammen zehn Supernodes. Ein Router verbindet sich nur mit
  Supernodes, die in seiner Firmware stehen. So können später Supernodes dazu
  kommen, ohne dass die Sackgasse neu gebaut werden muss.

## Key-Firmware

- **SSH-Schlüssel und Signierschlüssel** sind jetzt in allen Domains dieselben
  wie in unserer aktuellen Firmware. Die bisherigen domain-eigenen Schlüssel
  entfallen. Ein ed25519-Schlüssel der aktuellen Firmware fehlt, weil dropbear
  2019.78 kein ed25519 kennt.
- Das gilt erst für Router, die diese Version installiert haben. Für das
  Update selbst prüft ein Router die Schlüssel seiner bisherigen Firmware.

## respondd

- **respondd lauscht wieder auf Gluons Standard-Multicastgruppen**
  (`ff02::2:1001` und `ff05::2:1001` auf den Client-Schnittstellen). Die
  Sonderregel aus früheren Versionen entfällt, die Karte fragt diese Gruppen ab.
