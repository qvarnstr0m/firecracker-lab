# Lab 03: Networking

**Goal:** give a microVM a network interface, reach it from the host, and let
it reach the internet.

## The picture

```text
 guest                      host
 ┌───────────┐   ┌────────┐   ┌─────────────────┐   ┌──────┐
 │ eth0      │───│ fctap2 │───│ fcbr0           │───│ NAT  │── uplink (eno1)
 │172.30.0.2 │   └────────┘   │ 172.30.0.1/24   │   └──────┘
 └───────────┘   ┌────────┐   │                 │
 ┌───────────┐───│ fctap3 │───│                 │
 │172.30.0.3 │   └────────┘   └─────────────────┘
 └───────────┘
```

- A **tap device** is a virtual Ethernet port whose other end is a file
  descriptor. Firecracker opens it and moves frames between it and the guest's
  virtio-net device.
- A **bridge** is a virtual switch. All taps plug into `fcbr0`; the host is on
  it too, at `172.30.0.1`, which is the guests' gateway.
- **NAT** (nftables masquerade) rewrites guest traffic leaving the uplink so it
  appears to come from the host.

The subnet is `172.30.0.0/24`, deliberately apart from libvirt's
`192.168.122.0/24`, so the CKA lab VMs and the microVMs don't collide.

## 1. Host side, by hand

Do it once by hand to see each piece. Read [`net/setup.sh`](../net/setup.sh)
alongside.

```bash
sudo ip link add fcbr0 type bridge
sudo ip addr add 172.30.0.1/24 dev fcbr0
sudo ip link set fcbr0 up
sudo sysctl -w net.ipv4.ip_forward=1

sudo ip tuntap add dev fctap2 mode tap user "$USER"
sudo ip link set fctap2 master fcbr0 up

ip -br link show master fcbr0
```

Now replace all that with the script, which also adds the NAT rules:

```bash
sudo ip link del fctap2; sudo ip link del fcbr0
make net
sudo nft list table ip firecracker_lab
```

## 2. Guest side

The guest needs an address. Without DHCP, the simplest way is the kernel's own
IP autoconfiguration through the `ip=` boot argument:

```text
ip=<guest-ip>::<gateway>:<netmask>:<hostname>:<device>:off:<dns>
ip=172.30.0.2::172.30.0.1:255.255.255.0:web1:eth0:off:1.1.1.1
```

And Firecracker needs a network interface with a MAC and the tap name:

```text
PUT /network-interfaces/eth0
{"iface_id": "eth0", "guest_mac": "06:00:AC:1E:00:02", "host_dev_name": "fctap2"}
```

## 3. Run one

`vm/run.sh` starts VMs in the background with the serial console going to a
log file, so the guest needs a workload that doesn't wait for keyboard input.
A bare Alpine shell would read end-of-file and exit, taking the VM with it.
Use the small web server image from this repo:

```bash
docker build -t fc-static-web rootfs/images/static-web
make rootfs IMAGE=fc-static-web ROOTFS=static-web
make run NAME=web1 ROOTFS=static-web
make list
```

Read the printed API calls; find the `ip=` argument and the network interface.
Then check from the host:

```bash
ping -c 3 172.30.0.2
curl -s http://172.30.0.2/
cat run/web1/console.log
```

## 4. A second VM

```bash
make rootfs IMAGE=nginx:alpine
make run NAME=web2 ROOTFS=nginx
curl -sI http://172.30.0.3/ | head -3
ip -br link show master fcbr0
```

Two taps on the bridge now. From another machine on your LAN the VMs aren't
reachable directly; they're behind NAT. Lab 08 deals with that. For now, an
SSH tunnel works: `ssh -L 8080:172.30.0.3:80 <host>`.

## 5. Outbound

Prove a guest can reach the internet, with a throwaway image whose command does
the check and exits:

```bash
mkdir -p /tmp/netcheck
cat > /tmp/netcheck/Dockerfile <<'EOF'
FROM alpine:3.22
CMD ["sh", "-c", "ip addr show eth0; ip route; ping -c 2 1.1.1.1; wget -qO- https://example.com | head -3"]
EOF
docker build -t fc-netcheck /tmp/netcheck
make rootfs IMAGE=fc-netcheck
make run NAME=check ROOTFS=fc-netcheck
sleep 3; cat run/check/console.log
make list     # 'check' is stopped: its command finished, so the VM did too
```

## Checkpoint

- Run `sudo tcpdump -eni fcbr0` while curling a VM. Where do you see the
  guest's MAC?
- Delete the NAT table (`sudo nft delete table ip firecracker_lab`): what still
  works and what doesn't? Then `make net` again.
- Why is the tap owned by your user rather than root?

## Clean up

```bash
make stop NAME=web1; make stop NAME=web2; make stop NAME=check
```

Leave the network up; later labs use it. `make net-down` removes it.
