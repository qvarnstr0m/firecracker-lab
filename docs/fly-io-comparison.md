# What this lab mirrors from fly.io, and what it leaves out

fly.io runs customer apps as Firecracker microVMs on its own bare-metal
servers. This page maps what the labs build to what a platform like that does.
It's based on fly.io's public blog posts and docs, not on inside knowledge.

## Mirrored

| Platform piece | In this lab |
| --- | --- |
| Firecracker on bare-metal Linux with KVM | Firecracker directly on the Ubuntu host, no nested VM |
| Container image in, VM out | `rootfs/from-oci.sh`, [lab 04](../labs/04-image-to-vm.md) |
| Own init as PID 1 that runs the entrypoint | `fc-init`, a shell script (fly.io's is a Rust binary) |
| Per-VM block device from a shared base image | copy (or reflink) per VM; fly.io uses LVM thin snapshots |
| Per-VM tap device, host routes traffic | tap + bridge + NAT, [lab 03](../labs/03-networking.md) |
| Config and secrets passed in at boot | kernel args and MMDS, [lab 05](../labs/05-metadata-and-config.md) |
| Suspend / resume | snapshots, [lab 06](../labs/06-snapshots.md) |
| Jailer isolation | [lab 07](../labs/07-jailer.md) |
| Per-host daemon that drives Firecracker | the Go orchestrator, [lab 08](../labs/08-mini-orchestrator.md) |
| Proxy that routes requests to machines, starts stopped ones | milestone 6 of lab 08 |

## Left out

- **Many hosts.** Scheduling, placement and capacity across a fleet. Here it's
  one host.
- **Global networking.** Anycast IPs, an edge proxy in every region, a
  WireGuard mesh between hosts and a private IPv6 network per organization.
  Here it's one NATed /24.
- **Image distribution.** Pulling from a registry into a block-device cache on
  each host. Here Docker does the pulling.
- **Persistent volumes.** Separate block devices that survive the machine.
- **Logs and metrics pipelines**, health checks, rolling deploys.
- **Multi-tenancy hardening** beyond the jailer: per-tenant network
  namespaces, rate limiters on disk and network, abuse handling.
- **Kubernetes.** Running Kubernetes nodes as Firecracker VMs is possible but
  needs a custom kernel with everything containerd and kube-proxy require. It
  stays out of scope here and in the CKA lab.
