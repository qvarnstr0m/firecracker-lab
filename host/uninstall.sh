#!/usr/bin/env bash
# Remove the Firecracker and jailer binaries installed by install.sh.
source "$(dirname "$0")/../lib/common.sh"

for bin in firecracker jailer; do
  if [[ -e "$FC_INSTALL_PREFIX/$bin" ]]; then
    show as_root rm -f "$FC_INSTALL_PREFIX/$bin"
  fi
done
log "binaries removed. build/ and run/ are left alone; use 'make clean' for those."
