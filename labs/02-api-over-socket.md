# Lab 02: Configuring a VM through the API socket

**Goal:** start the same VM as in lab 01, but by talking to Firecracker's REST
API with `curl --unix-socket`. This is how every orchestrator, fly.io's
included, drives Firecracker.

## Why an API

With `--config-file` you get one VM, configured once. With the API, a separate
program can create the VMM, configure it step by step, start it, pause it,
snapshot it, and hot-update some settings while it runs. The API is described
in Firecracker's
[OpenAPI spec](https://github.com/firecracker-microvm/firecracker/blob/main/src/firecracker/swagger/firecracker.yaml).

## 1. Start an empty VMM

Terminal 1:

```bash
rm -f /tmp/fc.sock
firecracker --api-sock /tmp/fc.sock
```

It's waiting. No VM exists yet; terminal 1 will become the serial console.

## 2. Ask it about itself

Terminal 2:

```bash
curl -s --unix-socket /tmp/fc.sock http://localhost/ | jq
curl -s --unix-socket /tmp/fc.sock http://localhost/machine-config | jq
```

The host part of the URL is ignored; only the path matters. State is
`Not started`.

## 3. Configure it, one resource at a time

```bash
FC() { curl -sS --fail-with-body --unix-socket /tmp/fc.sock -X "$1" "http://localhost$2" \
         -H 'Content-Type: application/json' -d "$3"; echo; }

FC PUT /machine-config '{"vcpu_count": 1, "mem_size_mib": 128}'

FC PUT /boot-source "{
  \"kernel_image_path\": \"$PWD/build/vmlinux\",
  \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off init=/sbin/fc-init\"
}"

FC PUT /drives/rootfs "{
  \"drive_id\": \"rootfs\",
  \"path_on_host\": \"$PWD/build/rootfs/alpine.ext4\",
  \"is_root_device\": true,
  \"is_read_only\": false
}"
```

A successful `PUT` returns `204 No Content`, so no output. Try an invalid one
to see an error:

```bash
FC PUT /machine-config '{"vcpu_count": 0, "mem_size_mib": 128}'
```

## 4. Start it

```bash
FC PUT /actions '{"action_type": "InstanceStart"}'
curl -s --unix-socket /tmp/fc.sock http://localhost/ | jq .state
```

Terminal 1 now shows the boot log and a shell.

## 5. What can change after start

Most resources are pre-boot only. Try changing memory now:

```bash
FC PUT /machine-config '{"vcpu_count": 1, "mem_size_mib": 256}'
```

It's refused. Things that can change at runtime include pausing (lab 06),
drive paths (`PATCH /drives/...`), rate limiters, and the metadata store (lab 05):

```bash
FC PATCH /vm '{"state": "Paused"}'    # the guest freezes
FC PATCH /vm '{"state": "Resumed"}'
```

Type in terminal 1 while it's paused, then resume.

## 6. The scripted version

Type `exit` in the guest (terminal 1) to end the VM.

[`vm/run.sh`](../vm/run.sh) makes exactly these calls, plus networking and
logging, and prints each one as it goes. From lab 03 on you'll use it through
`make run`.

## Checkpoint

- Which calls are mandatory before `InstanceStart`? Try leaving each out.
- Find `GET /vm/config` in the OpenAPI spec and use it on a running VM.

## Clean up

```bash
rm -f /tmp/fc.sock
```
