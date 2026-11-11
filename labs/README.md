# Labs

Do them in order. Each lab teaches one concept and assumes the ones before it.

| # | Lab | You learn | Needs |
| --- | --- | --- | --- |
| 01 | [First microVM](01-first-microvm.md) | What a microVM is made of: kernel, rootfs, a few settings | `make install kernel` |
| 02 | [API over a socket](02-api-over-socket.md) | Firecracker's REST API, VM lifecycle | lab 01 |
| 03 | [Networking](03-networking.md) | Tap devices, a bridge, NAT; reaching a VM | lab 02, `make net` |
| 04 | [Image to VM](04-image-to-vm.md) | How a container image becomes a bootable disk | lab 03, Docker |
| 05 | [Metadata and config](05-metadata-and-config.md) | Passing config in: kernel args and MMDS | lab 04 |
| 06 | [Snapshots](06-snapshots.md) | Pausing, snapshotting and restoring a running VM | lab 04 |
| 07 | [Jailer](07-jailer.md) | Production isolation: chroot, cgroups, dropped privileges | lab 04 |
| 08 | [Mini orchestrator](08-mini-orchestrator.md) | Putting it together in a Go service | labs 01–07, Go |

## Conventions

- Commands run from the repo root unless a lab says otherwise.
- `$` lines run as your normal user; `sudo` is written out where it's needed.
- Each lab ends with **Clean up** so the next lab starts from a known state.
- The scripts in `vm/`, `net/` and `rootfs/` do what the early labs teach by
  hand. Once you've done a step by hand, use the script.
