# Lab 04: Running a container image as a microVM

**Goal:** understand how [`rootfs/from-oci.sh`](../rootfs/from-oci.sh) turns a
Docker image into a bootable disk, and run your own app that way. This is the
core trick behind fly.io: you push a container image, it runs as a VM.

## An image is a filesystem plus metadata

A container image is a stack of filesystem layers and a config:

```bash
docker image inspect nginx:alpine | jq '.[0].Config | {Entrypoint, Cmd, Env, WorkingDir, ExposedPorts}'
```

To boot it as a VM you need:

1. the layers flattened into one filesystem
2. that filesystem in a block device format the guest kernel can mount (ext4)
3. a PID 1 that does what a container runtime would: mount `/proc` and friends,
   set env vars and working directory, exec the entrypoint

## 1. Do it by hand

```bash
mkdir -p /tmp/oci && cd /tmp/oci

# 1. flatten: create (not run) a container and export its filesystem
cid=$(docker create nginx:alpine)
mkdir root && docker export "$cid" | sudo tar -C root -xf -
docker rm "$cid"
ls root

# 2. the config that docker run would have used
docker image inspect nginx:alpine | jq -r '.[0].Config | (.Entrypoint // []) + (.Cmd // []) | @sh'
```

Note what's *not* in `root/`: no kernel, no init system, no `/sbin/init`. A
container image assumes someone else provides those.

```bash
# 3. size it and build an ext4 image straight from the directory
du -sh root
truncate -s 200M nginx.ext4
sudo mkfs.ext4 -F -d root nginx.ext4
cd -
```

`mkfs.ext4 -d` populates the filesystem from a directory without mounting
anything, so no loop devices are involved.

## 2. The init

Read [`rootfs/init/fc-init`](../rootfs/init/fc-init). It's 30 lines of shell. It
ends by sourcing `/etc/fc-entrypoint.sh`, which `from-oci.sh` generates from the
image config:

```bash
make rootfs IMAGE=nginx:alpine     # prints the generated entrypoint file
```

Questions to answer from the code:

- Who configures `eth0`? (Hint: not the init.)
- What happens to the VM when nginx exits?
- Why must the image contain `/bin/sh`? What would it take to support
  `FROM scratch` images? (fly.io injects its own init binary, written in Rust.)

## 3. Your own app

```bash
docker build -t fc-go-hello rootfs/images/go-hello
make rootfs IMAGE=fc-go-hello ROOTFS=go-hello
make run NAME=hello ROOTFS=go-hello
curl http://$(cat run/hello/ip):8080/
```

The response includes the hostname, which came from the `ip=` boot argument.

## 4. Copy-on-start

`vm/run.sh` copies the image to `run/<name>/rootfs.ext4` before each start, so
VMs never share a writable disk. Start three from the same image and compare:

```bash
for i in 1 2 3; do make run NAME=h$i ROOTFS=go-hello; done
du -h --apparent-size run/h*/rootfs.ext4
du -h run/h*/rootfs.ext4
```

On btrfs or XFS, `cp --reflink` makes the copies nearly free. fly.io uses
LVM thin snapshots for the same reason.

## Checkpoint

- Package something you use (a Python app, Redis, ...) and run it.
- Build `nginx:alpine` and `nginx` (Debian). Compare rootfs size and boot time.
- What does a container get from its runtime that this VM doesn't? (cgroup
  limits inside, a seccomp profile, user namespaces, ...)

## Clean up

```bash
make stop NAME=hello; for i in 1 2 3; do make stop NAME=h$i; done
sudo rm -rf /tmp/oci
```
