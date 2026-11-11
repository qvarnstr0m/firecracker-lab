# Lab 05: Passing configuration into the guest

**Goal:** get per-VM configuration (secrets, app settings, identity) into a
microVM without rebuilding its rootfs.

Two channels:

| Channel | Size | When | Read by |
| --- | --- | --- | --- |
| Kernel command line | a few KB | boot only | `/proc/cmdline` |
| MMDS (microVM metadata service) | up to 50 KB by default | any time, can be updated live | HTTP from inside the guest |

## 1. Kernel arguments

Anything the kernel doesn't recognize is left in `/proc/cmdline` for userspace.
`vm/run.sh` appends `BOOT_ARGS_EXTRA`:

```bash
mkdir -p /tmp/cmdline
cat > /tmp/cmdline/Dockerfile <<'EOF'
FROM alpine:3.22
CMD ["sh", "-c", "cat /proc/cmdline; for w in $(cat /proc/cmdline); do case $w in app.*) echo \"got $w\";; esac; done"]
EOF
docker build -t fc-cmdline /tmp/cmdline
make rootfs IMAGE=fc-cmdline
BOOT_ARGS_EXTRA="app.env=staging app.region=home" make run NAME=args ROOTFS=fc-cmdline
sleep 2; cat run/args/console.log
```

Good for small, boot-time facts. Not good for secrets: anyone in the guest can
read `/proc/cmdline`, and it's visible in the Firecracker process's API config.

## 2. MMDS

MMDS is an HTTP endpoint Firecracker serves *inside* the VMM, reachable from
the guest at a link-local address (`169.254.169.254` by default), like cloud
instance metadata. The host writes JSON over the API socket; the guest reads it
over the network interface.

Write the metadata:

```bash
cat > /tmp/meta.json <<'EOF'
{"app": {"name": "hello", "greeting": "hej"}, "secrets": {"db_password": "not-in-the-image"}}
EOF
```

`vm/run.sh` sets MMDS up before boot when `MMDS_JSON` is set. The calls it makes:

```text
PUT /mmds/config {"version": "V2", "network_interfaces": ["eth0"]}
PUT /mmds        <the JSON>
```

A guest that reads it (MMDS V2 requires a session token first, like AWS IMDSv2):

```bash
mkdir -p /tmp/mmds
cat > /tmp/mmds/Dockerfile <<'EOF'
FROM alpine:3.22
RUN apk add --no-cache curl
COPY read-mmds.sh /read-mmds.sh
CMD ["sh", "/read-mmds.sh"]
EOF
cat > /tmp/mmds/read-mmds.sh <<'EOF'
ip route add 169.254.169.254 dev eth0
while true; do
  token=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-metadata-token-ttl-seconds: 60')
  curl -s -H "X-metadata-token: $token" -H 'Accept: application/json' http://169.254.169.254/app
  echo
  sleep 5
done
EOF
docker build -t fc-mmds /tmp/mmds
make rootfs IMAGE=fc-mmds
MMDS_JSON=/tmp/meta.json make run NAME=meta ROOTFS=fc-mmds
sleep 3; tail -3 run/meta/console.log
```

## 3. Update it live

```bash
curl -sS --unix-socket run/meta/api.sock -X PATCH http://localhost/mmds \
  -H 'Content-Type: application/json' -d '{"app": {"greeting": "hallå"}}'
sleep 6; tail -2 run/meta/console.log
```

`PATCH` merges; `PUT` replaces. This is how a control plane can rotate config
without restarting the VM.

## Checkpoint

- Fetch `/` with `Accept: text/plain` instead of JSON. What changes?
- Can a second VM read the first VM's MMDS? Why not?
- fly.io injects secrets as environment variables at boot. How would you do
  that with MMDS and a slightly smarter `fc-init`?

## Clean up

```bash
make stop NAME=args; make stop NAME=meta
rm -rf /tmp/cmdline /tmp/mmds /tmp/meta.json
```
