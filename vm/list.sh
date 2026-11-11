#!/usr/bin/env bash
# List microVMs started by vm/run.sh, asking each VMM for its state over the API.
source "$(dirname "$0")/../lib/common.sh"

printf '%-16s %-14s %-8s %-10s %-12s %s\n' NAME IP TAP PID STATE ROOTFS
shopt -s nullglob
for state in "$RUN_DIR"/*/; do
  state="${state%/}"
  name="$(basename "$state")"
  pid="$(cat "$state/pid" 2>/dev/null || echo -)"
  vm_state="stopped"
  if [[ "$pid" != - ]] && kill -0 "$pid" 2>/dev/null; then
    # GET / returns {"id":..., "state":"Running|Paused|Not started", ...}
    vm_state="$(curl -sS --max-time 1 --unix-socket "$state/api.sock" http://localhost/ 2>/dev/null \
      | jq -r '.state // "unknown"' 2>/dev/null || echo unknown)"
  fi
  printf '%-16s %-14s %-8s %-10s %-12s %s\n' "$name" \
    "$(cat "$state/ip" 2>/dev/null || echo -)" "$(cat "$state/tap" 2>/dev/null || echo -)" \
    "$pid" "$vm_state" "$(cat "$state/image" 2>/dev/null || echo -)"
done
