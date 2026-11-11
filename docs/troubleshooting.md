# Troubleshooting

Start with `make check`. Then look at, in order: the script's output,
`run/<name>/console.log` (guest), `run/<name>/firecracker.log` (VMM).

## Host

**`/dev/kvm: Permission denied`**
Add yourself to the group and log in again: `sudo usermod -aG kvm $USER`.
Check with `id`.

**`/dev/kvm` doesn't exist**
Virtualization is off in the firmware, or the module isn't loaded:
`sudo modprobe kvm_intel` (or `kvm_amd`), `dmesg | grep -i kvm`. Inside a VM,
nested virtualization must be enabled on the outer host.

## Boot

**`Kernel panic - not syncing: VFS: Unable to mount root fs`**
The guest kernel lacks virtio-block or ext4, or the drive isn't marked
`is_root_device`. Use the kernel from `make kernel`.

**`Kernel panic ... Attempted to kill init!` right after boot**
PID 1 exited. Usually the workload: read `console.log` above the panic. If
it's `fc-init: not found` or `can't execute`, the image has no `/bin/sh`.

**VM exits immediately when started with `make run`**
The image's command is an interactive shell (like plain `alpine`). Its stdin is
`/dev/null`, so it exits, and the VM with it. Use an image with a long-running
command, or `firecracker --config-file` in the foreground (lab 01).

**`Resource busy` / `Address in use` on the socket**
A stale socket from a killed VMM. `make stop NAME=<vm>` or remove
`run/<name>/api.sock`.

## Network

**Can't ping the VM from the host**
`ip -br link show master fcbr0` should list the VM's tap, `UP`.
`ip addr show fcbr0` should have `172.30.0.1/24`. In `console.log`, look for
`IP-Config: Complete` and the right address.

**Host reaches the VM, VM can't reach the internet**
Docker sets the iptables `FORWARD` policy to `DROP`, and a packet must be
accepted by every firewall chain, nftables and iptables alike. `make net`
adds `DOCKER-USER` rules for this; if Docker was installed afterwards, run
`make net` again. Also check: `sysctl net.ipv4.ip_forward` is 1,
`sudo nft list table ip firecracker_lab` has the masquerade rule, and the
uplink in it is the interface with your default route. `ufw` can have the
same effect as Docker: `sudo ufw route allow in on fcbr0`.

**Name resolution fails in the guest**
`cat /etc/resolv.conf` in the guest; it's written from the `ip=` argument's DNS
field (`FC_GUEST_DNS`).

**Conflicts with libvirt**
libvirt uses `virbr0` and `192.168.122.0/24`; this lab uses `fcbr0` and
`172.30.0.0/24`, and its own nftables table. If you changed either subnet,
`ip route` shows what's taken.

## Rootfs

**`mkfs.ext4: invalid option -- 'd'`**
e2fsprogs older than 1.43. Upgrade the distro or the package.

**`exec format error` in the guest**
The image was pulled for another architecture. `from-oci.sh` pulls for the
host's arch, but a locally built or cached image may differ:
`docker image inspect <image> | jq '.[0].Architecture'`.
