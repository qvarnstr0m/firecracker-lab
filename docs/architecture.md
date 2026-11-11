# Architecture

How the pieces fit, from the hardware up.

```text
┌──────────────────────────── host (Ubuntu Server) ────────────────────────────┐
│                                                                              │
│   firecracker (web1)        firecracker (web2)        libvirt/QEMU (CKA)     │
│   ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐   │
│   │ guest kernel     │      │ guest kernel     │      │ full VM          │   │
│   │ fc-init → nginx  │      │ fc-init → app    │      │                  │   │
│   ├──────────────────┤      ├──────────────────┤      └────────┬─────────┘   │
│   │ virtio-net/-blk  │      │ virtio-net/-blk  │               │             │
│   │ serial, API sock │      │ serial, API sock │            virbr0           │
│   └──┬─────────┬─────┘      └──┬─────────┬─────┘        192.168.122.0/24     │
│      │ tap     │ ext4 file     │ tap     │ ext4 file                         │
│      └──┐      run/web1/       └──┐      run/web2/                           │
│        fcbr0 172.30.0.1/24 ───────┴──── nftables NAT ──── uplink             │
│                                                                              │
│   ─────────────────────────── /dev/kvm (KVM) ──────────────────────────────  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Layers

**KVM.** A Linux kernel module that exposes the CPU's virtualization
extensions (Intel VT-x, AMD-V) through `/dev/kvm`. It runs guest code natively
and traps to userspace on I/O. Everything here, Firecracker and the CKA lab's
QEMU VMs alike, shares it.

**The VMM (Firecracker).** A userspace process, written in Rust, that opens
`/dev/kvm`, allocates guest memory, creates vCPU threads, and emulates a
minimal set of devices: virtio-net, virtio-block, virtio-vsock, a serial
console, an i8042 controller (only for reset) and an RTC. No PCI by default,
no BIOS, no USB, no display. Small device model, small attack surface, fast
boot. One process per VM.

**The API.** Each Firecracker process listens on its own Unix socket and
serves a REST API: configure before boot (`/machine-config`, `/boot-source`,
`/drives`, `/network-interfaces`), then act (`/actions`, `PATCH /vm`,
`/snapshot/*`, `/mmds`). See [lab 02](../labs/02-api-over-socket.md).

**The guest kernel.** An uncompressed `vmlinux` loaded directly into guest
memory and jumped into, with the command line from `/boot-source`. It needs
virtio drivers built in, not as modules, since there is no initrd. See
[`kernel/config/README.md`](../kernel/config/README.md).

**The root filesystem.** An ext4 image file on the host, exposed as
`/dev/vda`. Built from a container image by
[`rootfs/from-oci.sh`](../rootfs/from-oci.sh), with a tiny init
([`fc-init`](../rootfs/init/fc-init)) that execs the image's entrypoint.
Each VM gets its own copy in `run/<name>/`.

**The network.** One tap device per VM, all on bridge `fcbr0`, NAT to the
uplink with nftables. Guest IPs are static, set with the kernel's `ip=`
argument. See [lab 03](../labs/03-networking.md).

## Lifecycle of `make run NAME=web1 ROOTFS=nginx`

1. pick a free IP (`.2`–`.254`) by reading `run/*/ip`; derive tap name and MAC
2. copy `build/rootfs/nginx.ext4` to `run/web1/rootfs.ext4`
3. create `fctapN`, owned by you, attached to `fcbr0`
4. start `firecracker --api-sock run/web1/api.sock`, console to `console.log`
5. `PUT` logger, machine config, boot source, drive, network interface
6. `PUT /actions InstanceStart`
7. guest kernel boots, configures `eth0`, runs `/sbin/fc-init`, which execs nginx

When nginx exits, the guest kernel panics, reboots, and Firecracker exits.
`make stop` kills the process and removes the tap and `run/web1/`.

## Files and state

| Path | In git | What |
| --- | --- | --- |
| `config/*.env` | yes | versions, network |
| `build/vmlinux` | no | guest kernel |
| `build/rootfs/*.ext4` | no | images built from containers |
| `run/<name>/` | no | per-VM: socket, pid, ip, tap, disk copy, logs |
