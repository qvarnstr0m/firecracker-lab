# Lab 06: Snapshots

**Goal:** pause a running microVM, save its full state to disk, and restore it
in a new Firecracker process, with the app's memory intact.

This is what lets platforms suspend idle machines and resume them in
milliseconds instead of booting.

## What a snapshot contains

| File | Content |
| --- | --- |
| `vm.snap` | VMM and device state: vCPU registers, virtio queues, config |
| `vm.mem` | Guest memory, byte for byte (as large as `mem_size_mib`) |
| the rootfs | Not included. The restored VM must see the same disk at the same path |

The tap device must also exist under the same name.

## 1. A VM with state worth keeping

A counter in memory, printed every second:

```bash
mkdir -p /tmp/counter
cat > /tmp/counter/Dockerfile <<'EOF'
FROM alpine:3.22
CMD ["sh", "-c", "i=0; while true; do i=$((i+1)); echo \"count $i\"; sleep 1; done"]
EOF
docker build -t fc-counter /tmp/counter
make rootfs IMAGE=fc-counter
make run NAME=snap1 ROOTFS=fc-counter
sleep 5; tail -2 run/snap1/console.log
```

## 2. Pause and snapshot

```bash
S=run/snap1/api.sock
FC() { curl -sS --fail-with-body --unix-socket "$S" -X "$1" "http://localhost$2" \
         -H 'Content-Type: application/json' -d "$3"; echo; }

FC PATCH /vm '{"state": "Paused"}'
FC PUT /snapshot/create "{
  \"snapshot_type\": \"Full\",
  \"snapshot_path\": \"$PWD/run/snap1/vm.snap\",
  \"mem_file_path\": \"$PWD/run/snap1/vm.mem\"
}"
ls -lh run/snap1/vm.*
tail -1 run/snap1/console.log      # remember this number
```

## 3. Kill the VMM, keep the rest

```bash
kill "$(cat run/snap1/pid)"
ip link show "$(cat run/snap1/tap)"   # tap still there
```

## 4. Restore in a new process

```bash
rm -f run/snap1/api.sock
firecracker --api-sock run/snap1/api.sock --id snap1 \
  </dev/null >>run/snap1/console.log 2>&1 &
echo $! > run/snap1/pid
sleep 0.5

FC PUT /snapshot/load "{
  \"snapshot_path\": \"$PWD/run/snap1/vm.snap\",
  \"mem_backend\": {\"backend_type\": \"File\", \"backend_path\": \"$PWD/run/snap1/vm.mem\"},
  \"resume_vm\": true
}"
sleep 3; tail -3 run/snap1/console.log
```

The counter continues from where it stopped, not from 1. No boot happened.

## 5. How fast

```bash
FC PATCH /vm '{"state": "Paused"}'
time FC PATCH /vm '{"state": "Resumed"}'
```

Then time a full kill-and-restore cycle against a cold boot with `make run`.

## Things to know

- **Clones share identity.** Restoring the same snapshot twice gives two VMs
  with the same RNG state, MAC, IP and in-memory secrets. Firecracker's docs on
  [snapshot security](https://github.com/firecracker-microvm/firecracker/blob/main/docs/snapshotting/random-for-clones.md)
  explain the risks.
- **Diff snapshots** (`"snapshot_type": "Diff"`, with `track_dirty_pages` set
  in `/machine-config` before boot) save only pages changed since the last
  snapshot.
- **Same host type.** Snapshots are tied to the CPU model and Firecracker
  version.
- **Memory on demand.** With `"backend_type": "Uffd"`, a userfaultfd handler
  loads pages lazily, so a large VM resumes before all its memory is read.

## Checkpoint

- Compare `vm.mem` size with `du` (it's sparse). Why?
- What happens if you restore while the original VM is still running?

## Clean up

```bash
make stop NAME=snap1
rm -rf /tmp/counter
```
