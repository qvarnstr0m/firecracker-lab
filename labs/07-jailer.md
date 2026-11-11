# Lab 07: Isolating the VMM with the jailer

**Goal:** run Firecracker the way it's meant to run in production: chrooted,
in its own cgroup and namespaces, as an unprivileged user.

## Why

KVM isolates the guest from the host. But Firecracker itself is a userspace
process handling untrusted guest input (virtio queues, MMDS requests). If a
guest found a bug in it, the attacker would have whatever that process has. So
far that's been your user account, with access to your home directory.

The `jailer` binary (installed with `make install`) sets up a box for one
Firecracker process and then execs it:

- a **chroot** containing only that VM's kernel, rootfs and socket
- a new **mount and PID namespace**, optionally a network namespace
- **cgroup** limits (CPU, memory)
- **drops to an unprivileged uid/gid**
- Firecracker then applies its own **seccomp** filters

The jailer must start as root; Firecracker never runs as root afterwards.

## 1. Prepare a uid and the chroot base

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin fcvm || true
FC_UID=$(id -u fcvm); FC_GID=$(id -g fcvm)
sudo mkdir -p /srv/jailer
```

## 2. Start a jailed VMM

```bash
ID=jail1
sudo jailer --id "$ID" \
  --exec-file "$(command -v firecracker)" \
  --uid "$FC_UID" --gid "$FC_GID" \
  --chroot-base-dir /srv/jailer \
  --cgroup-version 2 \
  --cgroup cpu.max="50000 100000" \
  --cgroup memory.max=300M \
  --daemonize \
  -- --api-sock /run/firecracker.socket
```

Everything after `--` goes to Firecracker. The chroot is
`/srv/jailer/firecracker/$ID/root/`, and the socket path is *inside* it.

```bash
ROOT=/srv/jailer/firecracker/$ID/root
sudo ls -la "$ROOT" "$ROOT/run"
ps -o user,pid,cmd -C firecracker
```

## 3. Put the VM's files inside the jail

Firecracker can only see files inside its chroot, owned so the jailed uid can
use them:

```bash
sudo cp build/vmlinux "$ROOT/vmlinux"
sudo cp --sparse=always build/rootfs/static-web.ext4 "$ROOT/rootfs.ext4"
sudo chown "$FC_UID:$FC_GID" "$ROOT/vmlinux" "$ROOT/rootfs.ext4"
sudo ip tuntap add dev fctap50 mode tap user fcvm
sudo ip link set fctap50 master fcbr0 up
```

## 4. Configure it through the jailed socket

Paths in API calls are now relative to the chroot:

```bash
S=$ROOT/run/firecracker.socket
FC() { sudo curl -sS --fail-with-body --unix-socket "$S" -X "$1" "http://localhost$2" \
         -H 'Content-Type: application/json' -d "$3"; echo; }

FC PUT /machine-config '{"vcpu_count": 1, "mem_size_mib": 128}'
FC PUT /boot-source '{"kernel_image_path": "/vmlinux",
  "boot_args": "console=ttyS0 reboot=k panic=1 pci=off init=/sbin/fc-init ip=172.30.0.50::172.30.0.1:255.255.255.0:jail1:eth0:off:1.1.1.1"}'
FC PUT /drives/rootfs '{"drive_id": "rootfs", "path_on_host": "/rootfs.ext4", "is_root_device": true, "is_read_only": false}'
FC PUT /network-interfaces/eth0 '{"iface_id": "eth0", "guest_mac": "06:00:AC:1E:00:32", "host_dev_name": "fctap50"}'
FC PUT /actions '{"action_type": "InstanceStart"}'
curl -s http://172.30.0.50/
```

## 5. Look at the box from outside

```bash
PID=$(pgrep -f "firecracker --id $ID")
sudo ls -l /proc/$PID/root/                 # its whole world
sudo grep -E 'Uid|Gid|Seccomp' /proc/$PID/status
cat /sys/fs/cgroup/firecracker/$ID/cpu.max /sys/fs/cgroup/firecracker/$ID/memory.max
```

## Checkpoint

- Try `--cgroup memory.max=64M` with a 128 MiB VM. What happens, and when?
- Add `--netns /var/run/netns/<ns>` and move the tap into that namespace.
  What does that protect against?
- Which of these protections does `vm/run.sh` give you? (None. Should it?)

## Clean up

```bash
sudo kill "$PID"
sudo ip link del fctap50
sudo rm -rf /srv/jailer/firecracker/$ID
sudo rmdir /sys/fs/cgroup/firecracker/$ID 2>/dev/null || true
```
