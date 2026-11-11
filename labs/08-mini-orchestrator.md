# Lab 08: A mini orchestrator

**Goal:** replace the bash scripts with a small Go service that starts and
stops microVMs on request, roughly what fly.io's `flyd` does on each host.

This lab is a project, not an afternoon. It's split into milestones; each one
works on its own. Code goes in [`orchestrator/`](../orchestrator).

## What exists

- [`internal/firecracker/client.go`](../orchestrator/internal/firecracker/client.go):
  an HTTP client over the API socket, `Put` and `Patch`
- [`cmd/fcorch/main.go`](../orchestrator/cmd/fcorch/main.go): a placeholder

```bash
cd orchestrator && go build ./... && go vet ./...
```

## The API to build

```text
POST   /machines          {"image": "nginx:alpine", "vcpus": 1, "mem_mib": 256}
                          -> {"id": "m-3f9c", "ip": "172.30.0.4", "state": "started"}
GET    /machines          -> list
GET    /machines/{id}     -> one, with state from the VMM
DELETE /machines/{id}     -> stop and clean up
POST   /machines/{id}/suspend   (milestone 5)
POST   /machines/{id}/resume
```

## Milestones

### 1. Start and stop one VM from Go

Port `vm/run.sh` to Go: spawn `firecracker` with `os/exec`, wait for the socket,
make the same `PUT` calls with the client, start it. `vm/stop.sh` becomes a
method. Keep shelling out to `net/tap.sh` for now.

Decide: what does the orchestrator do with a VM whose process died?

### 2. State

Keep machines in memory, keyed by ID, guarded by a mutex. Allocate IPs and tap
names in Go instead of scanning `run/`. On startup, find leftover `run/*`
directories and either adopt or clean them.

### 3. HTTP API

`net/http` with Go's pattern routing (`mux.HandleFunc("POST /machines", ...)`).
Return JSON. Test with curl. Add a `-listen` flag; bind to localhost.

### 4. Images

On `POST /machines` with an image the host hasn't seen, build the rootfs
(shell out to `rootfs/from-oci.sh` first; later, pull and unpack layers in Go
with a registry library and skip Docker entirely). Cache rootfs images by digest.

### 5. Suspend and resume

Use lab 06: snapshot on suspend, kill the process, restore on resume. Measure
resume latency.

### 6. Ingress

VMs live on a private subnet. Add a reverse proxy in the orchestrator
(`httputil.ReverseProxy`) that routes `Host: <id>.lab.local` to the right VM.
Then: start a suspended machine on the first request to it, and suspend it
after N minutes idle. That's scale-to-zero.

### 7. Jailer

Start VMs through the jailer (lab 07) instead of directly.

## Out of scope (see [docs/fly-io-comparison.md](../docs/fly-io-comparison.md))

Multiple hosts, scheduling, persistent volumes, Anycast, WireGuard mesh, a
proper init in the guest.

## Checkpoint per milestone

Write down: what happens if the orchestrator crashes while VMs are running?
After milestone 2 your answer should change.
