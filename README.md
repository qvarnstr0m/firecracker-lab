# firecracker-lab

Hands-on labs for running workloads as lightweight microVMs with
[Firecracker](https://firecracker-microvm.github.io/), the way platforms like
fly.io do: container image in, microVM out.

Firecracker isn't a standalone hypervisor like Proxmox. It's a small virtual
machine monitor (VMM) that runs on top of KVM in the Linux kernel. Each microVM
is one Firecracker process, controlled through a REST API on a Unix socket.
This repo has the scripts to set that up and a series of labs that build on
each other, from one VM booted by hand to a small orchestrator in Go.

## Requirements

- A Linux host with `/dev/kvm` (bare metal, or a VM with nested virtualization).
  Developed on Ubuntu Server; any recent distro should work.
- Your user in the `kvm` group: `sudo usermod -aG kvm $USER`
- `curl`, `jq`, `iproute2`, `nftables`, `e2fsprogs`, `sudo`
- Docker, to turn container images into root filesystems (from lab 04 on, and
  for building the base rootfs in lab 01)
- Go, for lab 08

The microVM network uses `172.30.0.0/24` on bridge `fcbr0`, kept apart from
libvirt's default `192.168.122.0/24` and Docker's `172.17.0.0/16`, so it can
share a host with both. Change it in [`config/network.env`](config/network.env).

## Quick start

```bash
make install                         # Firecracker + jailer on the host
make check                           # verify /dev/kvm, permissions, tools
make kernel                          # fetch guest kernel
make net                             # bridge + NAT for microVMs
make rootfs IMAGE=nginx:alpine       # container image -> ext4
make run NAME=web1 ROOTFS=nginx      # start a microVM
make list
curl http://172.30.0.2/              # nginx inside the microVM
make stop NAME=web1
make clean
```

`make help` lists every target.

## Layout

| Path | What |
| --- | --- |
| [`config/`](config) | Pinned versions and network settings, one place each |
| [`host/`](host) | Install, check and uninstall Firecracker and the jailer |
| [`kernel/`](kernel) | Fetch a prebuilt guest kernel, or build one |
| [`rootfs/`](rootfs) | Container image to ext4 rootfs, the guest init, example images |
| [`net/`](net) | Bridge, NAT and per-VM tap devices |
| [`vm/`](vm) | Start, stop and list microVMs through the API socket |
| [`labs/`](labs) | Step-by-step labs, in order |
| [`orchestrator/`](orchestrator) | Go code for lab 08 |
| [`docs/`](docs) | Architecture, fly.io comparison, troubleshooting |

Kernels, rootfs images and runtime state go in `build/` and `run/`, which are
gitignored.

## Labs

| # | Lab | Concept |
| --- | --- | --- |
| 01 | [First microVM](labs/01-first-microvm.md) | Kernel + rootfs + config file = a VM |
| 02 | [API over a socket](labs/02-api-over-socket.md) | Configuring a VM with `curl --unix-socket` |
| 03 | [Networking](labs/03-networking.md) | Tap, bridge, NAT |
| 04 | [Image to VM](labs/04-image-to-vm.md) | Running a Docker image as a microVM |
| 05 | [Metadata and config](labs/05-metadata-and-config.md) | MMDS and kernel arguments |
| 06 | [Snapshots](labs/06-snapshots.md) | Pause, snapshot, restore |
| 07 | [Jailer](labs/07-jailer.md) | chroot, cgroups, unprivileged VMMs |
| 08 | [Mini orchestrator](labs/08-mini-orchestrator.md) | A Go program that runs VMs on request |

See [`labs/README.md`](labs/README.md) for prerequisites per lab.

## Design principles

- Pinned versions in one place: [`config/versions.env`](config/versions.env)
- A separate subnet that doesn't interfere with libvirt or Docker
- Each lab explains one concept and builds on the previous one
- Scripts print the raw API calls instead of hiding them
- No large binaries in git
- Plain bash and a Makefile until lab 08, where Go takes over

## License

[MIT](LICENSE)
