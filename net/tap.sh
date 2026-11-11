#!/usr/bin/env bash
# Create or remove one tap device and attach it to the microVM bridge.
#
#   net/tap.sh add <tap>
#   net/tap.sh del <tap>
#
# The tap is owned by the calling user so Firecracker can open it without root.
source "$(dirname "$0")/../lib/common.sh"

action="${1:?usage: $0 add|del <tap>}"
tap="${2:?usage: $0 add|del <tap>}"
[[ ${#tap} -le 15 ]] || die "tap name '$tap' is longer than 15 characters"

case "$action" in
  add)
    ip link show "$FC_BRIDGE" >/dev/null 2>&1 || die "bridge $FC_BRIDGE missing: make net"
    owner="${SUDO_USER:-$(id -un)}"
    if ! ip link show "$tap" >/dev/null 2>&1; then
      show as_root ip tuntap add dev "$tap" mode tap user "$owner"
    fi
    show as_root ip link set "$tap" master "$FC_BRIDGE"
    show as_root ip link set "$tap" up
    ;;
  del)
    if ip link show "$tap" >/dev/null 2>&1; then
      show as_root ip link del "$tap"
    fi
    ;;
  *) die "unknown action '$action' (add|del)" ;;
esac
