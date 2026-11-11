#!/usr/bin/env bash
# Download a prebuilt guest kernel (uncompressed vmlinux) from Firecracker's CI bucket.
# Override with GUEST_KERNEL_URL=<url> to use any other vmlinux.
source "$(dirname "$0")/../lib/common.sh"

need curl
mkdir -p "$BUILD_DIR"

list_keys() {  # list_keys <prefix> <tag>  -> values of <tag> in the S3 listing
  curl -fsSL "${FC_CI_BUCKET}?list-type=2&delimiter=/&prefix=$1" \
    | grep -oE "<$2>[^<]+</$2>" | sed -E "s#</?$2>##g"
}

if [[ -n "${GUEST_KERNEL_URL:-}" ]]; then
  url="$GUEST_KERNEL_URL"
else
  prefix="$FC_CI_PREFIX"
  if [[ -z "$prefix" ]]; then
    prefix="$(list_keys firecracker-ci/ Prefix | grep -E '^firecracker-ci/[0-9]{8}-[^/]+/$' | sort | tail -1)"
    [[ -n "$prefix" ]] || die "could not find a CI prefix in $FC_CI_BUCKET"
  fi
  key="$(list_keys "${prefix}${ARCH}/vmlinux-${GUEST_KERNEL_SERIES}." Key \
    | grep -E "/vmlinux-${GUEST_KERNEL_SERIES//./\\.}\.[0-9]+$" | sort -V | tail -1)"
  [[ -n "$key" ]] || die "no vmlinux-${GUEST_KERNEL_SERIES}.x under ${prefix}${ARCH}/"
  url="${FC_CI_BUCKET}/${key}"
fi

log "fetching $url"
show curl -fSL --progress-bar -o "$KERNEL_PATH.tmp" "$url"
mv "$KERNEL_PATH.tmp" "$KERNEL_PATH"
# Keep the matching kernel config next to it when there is one; handy for kernel/build.sh.
curl -fsSL -o "$KERNEL_PATH.config" "$url.config" 2>/dev/null || rm -f "$KERNEL_PATH.config"

echo "$url" > "$KERNEL_PATH.version"
log "kernel: $KERNEL_PATH ($(basename "$url"))"
log "to pin this exact build, set FC_CI_PREFIX=${prefix:-} in config/versions.env"
