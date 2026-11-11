# Lab 01: Your first microVM

**Goal:** boot a Linux microVM by hand from a kernel, a root filesystem and a
config file, and see that there is nothing else to it.

## What a microVM needs

| Piece | Here |
| --- | --- |
| KVM | `/dev/kvm` on the host |
| A VMM | the `firecracker` binary, one process per VM |
| A guest kernel | an uncompressed `vmlinux`, no bootloader, no initrd |
| A root filesystem | an ext4 image file, exposed to the guest as a virtio block device |
| Settings | vCPUs, memory, kernel command line |

No BIOS, no PCI bus, no USB, no graphics. Firecracker emulates a handful of
devices (virtio-net, virtio-block, vsock, a serial console, a keyboard
controller for reset), which is why it boots in well under a second.

## 1. Host setup

```bash
make install     # Firecracker + jailer, version from config/versions.env
make check       # everything should say ok
make kernel      # build/vmlinux
```

If `check` complains about `/dev/kvm` permissions, add yourself to the `kvm`
group and log in again.

## 2. A root filesystem

Any ext4 image with a userland works. The quickest is Alpine, built from its
container image. Lab 04 explains how this works; for now, treat it as a way to
get a small filesystem:

```bash
make rootfs IMAGE=alpine:3.22 ROOTFS=alpine
ls -lh build/rootfs/alpine.ext4
```

## 3. A config file

Firecracker can be configured entirely from a JSON file. Render the template:

```bash
sed -e "s#@KERNEL@#$PWD/build/vmlinux#" \
    -e "s#@ROOTFS@#$PWD/build/rootfs/alpine.ext4#" \
    -e "s#@BOOT_ARGS@#init=/sbin/fc-init#" \
    -e "s#@VCPUS@#1#" -e "s#@MEM_MIB@#128#" \
    vm/vm-config.json.tpl > /tmp/vm1.json
cat /tmp/vm1.json
```

Read the kernel command line in it:

- `console=ttyS0`: kernel messages and the shell go to the serial port, which
  Firecracker connects to its own stdin/stdout
- `reboot=k panic=1`: on panic, reboot after 1 second; Firecracker exits on
  guest reboot, so the VM is gone
- `pci=off`: there is no PCI bus to probe
- `init=/sbin/fc-init`: the first process; it mounts `/proc`, `/sys`, `/dev`
  and starts the image's command (`/bin/sh` for Alpine)

## 4. Boot it

```bash
firecracker --no-api --config-file /tmp/vm1.json
```

You land in a shell inside the VM, on the serial console. Look around:

```sh
uname -a
cat /proc/cpuinfo | grep -c processor
free -m
dmesg | head -30
dmesg | grep -i virtio
```

Note how short `dmesg` is, and how few devices there are.

In a second terminal on the host:

```bash
ps -o pid,rss,etime,cmd -C firecracker
```

One process. Its resident memory is roughly what the guest has touched, not the
full 128 MiB.

## 5. Shut it down

Type `exit` in the guest shell. PID 1 exits, the kernel panics, `panic=1`
triggers a reboot, and Firecracker exits on reboot. A microVM's lifetime is its
main process's lifetime.

## Checkpoint

- What would break if you removed `console=ttyS0`?
- Boot it with `"vcpu_count": 2` and `"mem_size_mib": 512` and check inside.
- Time it: `time firecracker --no-api --config-file /tmp/vm1.json` and `exit`
  right away.

## Clean up

```bash
rm /tmp/vm1.json
```

Keep `build/` for the next lab.
