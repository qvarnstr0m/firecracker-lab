#!/usr/bin/env bash
# Optional: build the guest kernel yourself.
#
# Uses kernel/config/microvm-<arch>.config if present, otherwise the config that
# kernel/fetch.sh saved next to the prebuilt kernel (build/vmlinux.config).
# Needs: build-essential flex bison bc libelf-dev libssl-dev
source "$(dirname "$0")/../lib/common.sh"

need curl tar make gcc flex bison bc

ver="$GUEST_KERNEL_BUILD_VERSION"
major="${ver%%.*}"
src="$BUILD_DIR/linux-$ver"
cfg="$REPO_ROOT/kernel/config/microvm-${ARCH}.config"
[[ -f "$cfg" ]] || cfg="$KERNEL_PATH.config"
[[ -f "$cfg" ]] || die "no kernel config: add $REPO_ROOT/kernel/config/microvm-${ARCH}.config or run kernel/fetch.sh first"

mkdir -p "$BUILD_DIR"
if [[ ! -d "$src" ]]; then
  log "downloading linux-$ver"
  show curl -fSL --progress-bar "https://cdn.kernel.org/pub/linux/kernel/v${major}.x/linux-${ver}.tar.xz" \
    | tar -C "$BUILD_DIR" -xJf -
fi

log "configuring with $cfg"
cp "$cfg" "$src/.config"
make -C "$src" olddefconfig

log "building vmlinux (this takes a while)"
make -C "$src" -j"$(nproc)" vmlinux

cp "$src/vmlinux" "$KERNEL_PATH"
echo "built from linux-$ver with $(basename "$cfg")" > "$KERNEL_PATH.version"
log "kernel: $KERNEL_PATH"
