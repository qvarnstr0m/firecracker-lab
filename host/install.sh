#!/usr/bin/env bash
# Install the pinned Firecracker and jailer binaries.
source "$(dirname "$0")/../lib/common.sh"

require_linux
need curl tar sha256sum

v="$FC_VERSION"
tgz="firecracker-${v}-${ARCH}.tgz"
url="https://github.com/firecracker-microvm/firecracker/releases/download/${v}/${tgz}"

if command -v firecracker >/dev/null && firecracker --version | head -1 | grep -q "${v#v}"; then
  log "firecracker ${v} already installed: $(command -v firecracker)"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading ${tgz}"
show curl -fsSL -o "$tmp/$tgz" "$url"
show curl -fsSL -o "$tmp/$tgz.sha256.txt" "$url.sha256.txt"
(cd "$tmp" && sha256sum -c "$tgz.sha256.txt") || die "checksum mismatch"

tar -C "$tmp" -xzf "$tmp/$tgz"
rel="$tmp/release-${v}-${ARCH}"

log "installing to ${FC_INSTALL_PREFIX}"
show as_root install -m 0755 "$rel/firecracker-${v}-${ARCH}" "$FC_INSTALL_PREFIX/firecracker"
show as_root install -m 0755 "$rel/jailer-${v}-${ARCH}" "$FC_INSTALL_PREFIX/jailer"

firecracker --version | head -1
jailer --version | head -1
log "done. run host/check.sh to verify the host."
