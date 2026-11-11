#!/usr/bin/env bash
# Check that this host can run Firecracker microVMs.
source "$(dirname "$0")/../lib/common.sh"

fail=0
ok()  { printf '  \033[32mok\033[0m    %s\n' "$*"; }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; fail=1; }
meh() { printf '  \033[33mwarn\033[0m  %s\n' "$*"; }

echo "kernel / KVM"
if [[ "$(uname -s)" == Linux ]]; then ok "Linux $(uname -r) ($ARCH)"; else bad "not Linux"; fi
if [[ -e /dev/kvm ]]; then
  ok "/dev/kvm exists"
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    ok "/dev/kvm is read/writable by $(id -un)"
  else
    bad "/dev/kvm not accessible: sudo usermod -aG kvm $(id -un), then log in again"
  fi
else
  bad "/dev/kvm missing: enable VT-x/AMD-V in firmware, load kvm_intel or kvm_amd"
fi
if lsmod 2>/dev/null | grep -qE '^kvm_(intel|amd)'; then
  ok "kvm module loaded: $(lsmod | awk '/^kvm_(intel|amd)/{print $1}')"
else
  meh "kvm_intel/kvm_amd not listed by lsmod (fine if built in)"
fi
if [[ -e /dev/net/tun ]]; then ok "/dev/net/tun available"; else bad "/dev/net/tun missing (modprobe tun)"; fi

echo "binaries"
if command -v firecracker >/dev/null; then
  have="$(firecracker --version | head -1)"
  if [[ "$have" == *"${FC_VERSION#v}"* ]]; then ok "$have"; else meh "$have (pinned: $FC_VERSION)"; fi
else
  bad "firecracker not installed: make install"
fi
if command -v jailer >/dev/null; then ok "jailer"; else meh "jailer not installed (needed for lab 07)"; fi

echo "tools"
for c in curl jq ip nft mkfs.ext4 tar; do
  if command -v "$c" >/dev/null; then ok "$c"; else bad "$c missing"; fi
done
if command -v docker >/dev/null; then ok "docker"; else meh "docker missing (needed to build rootfs from images)"; fi

echo "network"
if ip -o route show "$FC_SUBNET" 2>/dev/null | grep -qv "dev $FC_BRIDGE"; then
  bad "$FC_SUBNET is already routed via another interface; change config/network.env"
else
  ok "$FC_SUBNET is free (or already ours)"
fi
if [[ -n "$(uplink_iface 2>/dev/null)" ]]; then ok "uplink: $(uplink_iface)"; else meh "no default route found"; fi

echo "artifacts"
if [[ -f "$KERNEL_PATH" ]]; then ok "guest kernel: $KERNEL_PATH"; else meh "no guest kernel yet: make kernel"; fi

exit "$fail"
