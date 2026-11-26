# MLD querier on br-wan: tried, does not help

Lab test of 2026-11-26. Result: no firmware change. This note records what
was tried so the idea is not picked up again without new evidence.

## The question

Bridges and switches with multicast snooping drop Neighbor Solicitations to a
solicited-node group once its membership has expired. Without a querier in
the segment, nobody asks hosts to renew their memberships, so after about
260 s the WAN address of a node can become unreachable over IPv6. This
matters once nodes tunnel over IPv6 on their WAN side.

The idea: if the node itself is MLD querier on `br-wan`, all hosts in the
segment, the node included, keep renewing their memberships, and the WAN
address stays reachable.

In Gluon, `br-wan` has `igmp_snooping` on and `multicast_querier` off
(`package/gluon-core/luasrc/lib/gluon/upgrade/110-network`). The change under
test was `uci set network.wan.multicast_querier=1` by hand, no image patch.

## Setup

- Gluon x86 VM, v2025.1.x multidomain image, WAN untagged in one VLAN of a
  Linux bridge with `multicast_snooping 1` and `mcast_vlan_snooping 0`
  (the Proxmox default). The bridge sees a querier only in another VLAN.
- A router in the WAN VLAN flushes its neighbour entry and pings the global
  WAN address of the node.
- Field timings: membership interval 260 s on the bridge, Gluon defaults on
  the node (query interval 125 s, MLDv1, IGMPv2,
  `multicast_query_use_ifaddr 0`).
- Captures on the WAN tap. MLD packets carry a Hop-by-Hop header, so the
  filter is `ip6[6]==0`; `icmp6` alone misses them.

## Result

| Step | Node querier | Pings after membership expiry |
|------|--------------|-------------------------------|
| 1/2  | off          | 0/2 after 256 s (failure reproduced) |
| 3    | on           | 0/2 after 260 s, 19 probes over 14 min |

Why it does not help:

1. **The node does not answer its own queries.** It sends MLDv1 general
   queries to `ff02::1` every 125 s, but no report from the node follows
   them. Reports do appear when the WAN address is set again, so the capture
   works. The membership of the node's own WAN address therefore still
   expires, which removes the core of the idea.
2. **Querier election.** The bridge keeps the querier with the lower
   link-local address (here the one in the other VLAN) and does not treat the
   node's port as a router port. The node would only take effect by winning
   the election, and then it would displace the querier of the home network.
   This case was not tested.

Side effect: the same switch makes the node an IGMPv2 querier too, sending
from `0.0.0.0` about every 128 s. `0.0.0.0` is the lowest possible address
and wins the IPv4 election, which is a risk for home networks with IPTV over
IGMP.

Steps 4 to 6 of the test plan (a second querier in the WAN VLAN, IGMP with
and without an IPv4 querier, mesh and client side unchanged) were not run:
the test stopped once step 3 showed that the change does not help and has a
real downside.

## Consequence

- No firmware patch, `multicast_querier` on `br-wan` stays off.
- Do not offer it as a milder alternative to switching off snooping on
  bridges in front of nodes.
- The risk itself remains: a snooping switch or bridge without a querier in
  the WAN segment of a node. It has to be covered in the tests for tunnels
  over IPv6.
