#!/usr/bin/env bash
# Host networking for microVMs: one bridge, IP forwarding, NAT with nftables.
#
#   microVM eth0 ── tap (fctapN) ── bridge fcbr0 (172.30.0.1) ── NAT ── uplink
#
# Idempotent: safe to run again. Undo with net/teardown.sh.
source "$(dirname "$0")/../lib/common.sh"

require_linux
need ip nft sysctl

uplink="$(uplink_iface)"
[[ -n "$uplink" ]] || die "no default route; set FC_UPLINK in config/network.env"

log "bridge $FC_BRIDGE ($FC_GATEWAY/$FC_PREFIX_LEN)"
if ! ip link show "$FC_BRIDGE" >/dev/null 2>&1; then
  show as_root ip link add "$FC_BRIDGE" type bridge
fi
if ! ip -o addr show dev "$FC_BRIDGE" | grep -q "inet $FC_GATEWAY/"; then
  show as_root ip addr add "$FC_GATEWAY/$FC_PREFIX_LEN" dev "$FC_BRIDGE"
fi
show as_root ip link set "$FC_BRIDGE" up

log "IP forwarding"
show as_root sysctl -q -w net.ipv4.ip_forward=1

log "nftables table ip $FC_NFT_TABLE (uplink: $uplink)"
# 'add' then 'delete' makes the reload idempotent without failing on first run.
as_root nft -f - <<EOF
add table ip $FC_NFT_TABLE
delete table ip $FC_NFT_TABLE
table ip $FC_NFT_TABLE {
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    ip saddr $FC_SUBNET oifname "$uplink" masquerade
  }
  chain forward {
    type filter hook forward priority filter; policy accept;
    iifname "$FC_BRIDGE" accept
    oifname "$FC_BRIDGE" ct state established,related accept
  }
}
EOF
as_root nft list table ip "$FC_NFT_TABLE" | sed 's/^/    /' >&2

# Docker sets the iptables FORWARD policy to DROP. A packet must be accepted by
# every base chain on the hook, so our nft accept alone isn't enough. Docker
# leaves the DOCKER-USER chain for exactly this.
if command -v iptables >/dev/null && as_root iptables -nL DOCKER-USER >/dev/null 2>&1; then
  log "Docker detected: allowing $FC_BRIDGE in DOCKER-USER"
  as_root iptables -C DOCKER-USER -i "$FC_BRIDGE" -j ACCEPT 2>/dev/null \
    || show as_root iptables -I DOCKER-USER -i "$FC_BRIDGE" -j ACCEPT
  as_root iptables -C DOCKER-USER -o "$FC_BRIDGE" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null \
    || show as_root iptables -I DOCKER-USER -o "$FC_BRIDGE" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
fi

log "network ready"
