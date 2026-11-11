#!/usr/bin/env bash
# Undo net/setup.sh: remove taps, the bridge, the nftables table and the DOCKER-USER rules.
# IP forwarding is left on because libvirt and Docker rely on it too.
source "$(dirname "$0")/../lib/common.sh"

require_linux

for tap in $(ip -o link show | awk -F': ' '{print $2}' | cut -d@ -f1 | grep "^${FC_TAP_PREFIX}" || true); do
  show as_root ip link del "$tap"
done

if ip link show "$FC_BRIDGE" >/dev/null 2>&1; then
  show as_root ip link del "$FC_BRIDGE"
fi

if as_root nft list table ip "$FC_NFT_TABLE" >/dev/null 2>&1; then
  show as_root nft delete table ip "$FC_NFT_TABLE"
fi

if command -v iptables >/dev/null && as_root iptables -nL DOCKER-USER >/dev/null 2>&1; then
  while as_root iptables -D DOCKER-USER -i "$FC_BRIDGE" -j ACCEPT 2>/dev/null; do :; done
  while as_root iptables -D DOCKER-USER -o "$FC_BRIDGE" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do :; done
  for iface in ${FC_TRUSTED_IFACES:-}; do
    while as_root iptables -D DOCKER-USER -i "$iface" -o "$FC_BRIDGE" -j ACCEPT 2>/dev/null; do :; done
  done
fi

log "network removed"
