#!/usr/bin/env bash
# Stop a microVM, remove its tap device and its state directory.
#
#   vm/stop.sh <name>       KEEP=1 keeps run/<name>/ (logs, disk) for inspection
source "$(dirname "$0")/../lib/common.sh"

name="${1:?usage: $0 <name>}"
valid_name "$name"
state="$RUN_DIR/$name"
[[ -d "$state" ]] || die "no microVM named $name"

if [[ -f "$state/pid" ]]; then
  pid="$(cat "$state/pid")"
  if kill -0 "$pid" 2>/dev/null; then
    # Our minimal guest has no ACPI shutdown handling, so stop the VMM itself.
    # (Firecracker also offers PUT /actions {"action_type":"SendCtrlAltDel"} on x86.)
    show kill "$pid"
    for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    kill -0 "$pid" 2>/dev/null && show kill -9 "$pid"
  fi
fi

[[ -f "$state/tap" ]] && "$REPO_ROOT/net/tap.sh" del "$(cat "$state/tap")"

if [[ "${KEEP:-0}" == 1 ]]; then
  rm -f "$state/pid" "$state/api.sock"
  log "$name stopped; state kept in ${state#"$REPO_ROOT"/}"
else
  rm -rf "$state"
  log "$name stopped"
fi
