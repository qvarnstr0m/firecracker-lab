#!/usr/bin/env bash
# Start a microVM through Firecracker's REST API on a Unix socket.
#
#   vm/run.sh <name> <rootfs> [vcpus] [mem_mib]
#
# <rootfs> is a name under build/rootfs/ (without .ext4) or a path to an ext4 file.
# Optional environment:
#   MMDS_JSON=<file>   enable the metadata service on eth0 and load this JSON (lab 05)
#   BOOT_ARGS_EXTRA    appended to the kernel command line
#
# Every API call is printed so you can replay it by hand with curl.
source "$(dirname "$0")/../lib/common.sh"

name="${1:?usage: $0 <name> <rootfs> [vcpus] [mem_mib]}"
rootfs="${2:?usage: $0 <name> <rootfs> [vcpus] [mem_mib]}"
vcpus="${3:-$VM_VCPUS}"
mem="${4:-$VM_MEM_MIB}"
valid_name "$name"

require_linux
need firecracker curl jq ip

[[ -f "$KERNEL_PATH" ]] || die "no guest kernel at $KERNEL_PATH: make kernel"
[[ -f "$rootfs" ]] || rootfs="$ROOTFS_DIR/$rootfs.ext4"
[[ -f "$rootfs" ]] || die "rootfs not found: $rootfs (make rootfs IMAGE=...)"

state="$RUN_DIR/$name"
if [[ -f "$state/pid" ]] && kill -0 "$(cat "$state/pid")" 2>/dev/null; then
  die "$name is already running (pid $(cat "$state/pid"))"
fi
rm -rf "$state"
mkdir -p "$state"

# --- pick a free address in the /24: .2 to .254, tracked by files in run/ ---
used="$(cat "$RUN_DIR"/*/ip 2>/dev/null || true)"
idx=""
for i in $(seq 2 254); do
  if ! grep -qx "$FC_NET_BASE.$i" <<<"$used"; then idx="$i"; break; fi
done
[[ -n "$idx" ]] || die "no free addresses left in $FC_SUBNET"

ip_addr="$FC_NET_BASE.$idx"
tap="${FC_TAP_PREFIX}${idx}"
IFS=. read -r o1 o2 o3 <<<"$FC_NET_BASE"
# Locally administered MAC derived from the IP: 06:00:AC:1E:00:02 for 172.30.0.2
mac="$(printf '06:00:%02X:%02X:%02X:%02X' "$o1" "$o2" "$o3" "$idx")"

echo "$ip_addr" > "$state/ip"
echo "$tap" > "$state/tap"
echo "$mac" > "$state/mac"

sock="$state/api.sock"
fail() {
  warn "start failed, cleaning up (console: $state/console.log)"
  [[ -f "$state/pid" ]] && kill "$(cat "$state/pid")" 2>/dev/null
  "$REPO_ROOT/net/tap.sh" del "$tap" >/dev/null 2>&1 || true
  exit 1
}
set -E
trap fail ERR

# Each VM gets its own copy of the disk. --reflink makes it instant on btrfs/xfs.
log "copying rootfs $(basename "$rootfs")"
cp --reflink=auto --sparse=always "$rootfs" "$state/rootfs.ext4"
basename "$rootfs" .ext4 > "$state/image"

"$REPO_ROOT/net/tap.sh" add "$tap"

# --- start the VMM. It does nothing until configured over the socket. ---
log "starting firecracker for $name"
touch "$state/firecracker.log"
firecracker --api-sock "$sock" --id "$name" \
  </dev/null >"$state/console.log" 2>&1 &
echo $! > "$state/pid"

for _ in $(seq 50); do [[ -S "$sock" ]] && break; sleep 0.1; done
[[ -S "$sock" ]] || { warn "API socket never appeared"; false; }

api() {  # api <METHOD> <path> <json>
  printf '\033[2m$ curl --unix-socket %s -X %s http://localhost%s -d %s\033[0m\n' \
    "${sock#"$REPO_ROOT"/}" "$1" "$2" "'$3'" >&2
  curl --fail-with-body -sS --unix-socket "$sock" -X "$1" "http://localhost$2" \
    -H 'Accept: application/json' -H 'Content-Type: application/json' -d "$3"
}

boot_args="console=ttyS0 reboot=k panic=1 pci=off"
boot_args+=" ip=${ip_addr}::${FC_GATEWAY}:${FC_NETMASK}:${name}:eth0:off:${FC_GUEST_DNS}"
boot_args+=" init=/sbin/fc-init ${BOOT_ARGS_EXTRA:-}"

api PUT /logger "$(jq -nc --arg p "$state/firecracker.log" '{log_path:$p, level:"Info"}')"
api PUT /machine-config "$(jq -nc --argjson c "$vcpus" --argjson m "$mem" '{vcpu_count:$c, mem_size_mib:$m}')"
api PUT /boot-source "$(jq -nc --arg k "$KERNEL_PATH" --arg a "$boot_args" '{kernel_image_path:$k, boot_args:$a}')"
api PUT /drives/rootfs "$(jq -nc --arg p "$state/rootfs.ext4" \
  '{drive_id:"rootfs", path_on_host:$p, is_root_device:true, is_read_only:false}')"
api PUT /network-interfaces/eth0 "$(jq -nc --arg m "$mac" --arg t "$tap" \
  '{iface_id:"eth0", guest_mac:$m, host_dev_name:$t}')"

if [[ -n "${MMDS_JSON:-}" ]]; then
  api PUT /mmds/config '{"version":"V2","network_interfaces":["eth0"]}'
  api PUT /mmds "$(jq -c . "$MMDS_JSON")"
fi

api PUT /actions '{"action_type":"InstanceStart"}'
trap - ERR

log "$name is up: ip $ip_addr, tap $tap, pid $(cat "$state/pid")"
log "console: tail -f ${state#"$REPO_ROOT"/}/console.log"
