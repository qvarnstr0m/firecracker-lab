#!/usr/bin/env bash
# Shared helpers. Every script sources this file.
# shellcheck shell=bash
# Variables defined here are used by the scripts that source this file.
# shellcheck disable=SC2034

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# shellcheck source=../config/versions.env
source "$REPO_ROOT/config/versions.env"
# shellcheck source=../config/network.env
source "$REPO_ROOT/config/network.env"

# Build output (kernels, rootfs images) and runtime state (sockets, logs).
# Both are gitignored.
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build}"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/run}"
KERNEL_PATH="${KERNEL_PATH:-$BUILD_DIR/vmlinux}"
ROOTFS_DIR="$BUILD_DIR/rootfs"

ARCH="$(uname -m)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Print a command before running it, so the raw steps are visible.
show() { printf '\033[2m$ %s\033[0m\n' "$*" >&2; "$@"; }

need() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
  done
}

as_root() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

require_linux() {
  [[ "$(uname -s)" == Linux ]] || die "this needs a Linux host with /dev/kvm"
}

# Validate a microVM name: lowercase letters, digits and dashes.
valid_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]] || die "invalid name '$1' (use a-z, 0-9, -)"
}

uplink_iface() {
  if [[ -n "${FC_UPLINK:-}" ]]; then
    echo "$FC_UPLINK"
  else
    ip -o route show default | awk '{for (i=1;i<NF;i++) if ($i=="dev") {print $(i+1); exit}}'
  fi
}
