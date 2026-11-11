# Working on the labs remotely

How to do the labs from another machine, for example a laptop at work, over
[Tailscale](https://tailscale.com/). Everything in the labs is command line, so
an SSH session is all you need. The host here is called `tiny`; use your own
host's name.

```text
 laptop ── tailnet (WireGuard) ── tiny ── fcbr0 ── microVMs
                                   │                172.30.0.0/24
                                   └── no ports open to the internet
```

Before you start: check that your work network and laptop allow a Tailscale
client and outbound connections to it. Some corporate networks block VPN
clients or have policies about them.

## 1. Tailscale on the host

On the host:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4          # the host's tailnet address, 100.x.y.z
```

Install Tailscale on the laptop and log in to the same tailnet. Then, from the
laptop:

```bash
ssh <user>@tiny          # MagicDNS name, or the 100.x.y.z address
```

This uses the host's normal OpenSSH server and keys. Don't forward port 22 on
your router; the tailnet replaces that.

Optional: `sudo tailscale up --ssh` lets Tailscale handle SSH authentication
with your tailnet identity instead of SSH keys.

## 2. tmux on the host

An SSH connection can drop. Work inside tmux so the session survives it:

```bash
sudo apt install tmux
tmux new -As lab         # create, or reattach to, a session called "lab"
```

- **Lab 01** runs the VM in the foreground on your terminal. Without tmux, a
  dropped connection kills the VM.
- **Lab 02** needs two terminals, one for the serial console and one for `curl`.
  Split the window with `Ctrl-b %`, switch panes with `Ctrl-b o`.
- VMs started with `make run` run in the background with their console in
  `run/<name>/console.log`, so they don't depend on your session.

Detach with `Ctrl-b d`; `tmux new -As lab` picks up where you left off, also
from home.

## 3. Reaching the microVMs from the laptop

The VMs sit on `172.30.0.0/24` behind NAT on the host. From your SSH session on
the host, `curl http://172.30.0.2/` works. From the laptop's browser it doesn't,
until you do one of these.

### Option A: subnet route (all VMs, no tunnels)

Advertise the microVM subnet to your tailnet. On the host:

```bash
sudo tailscale set --advertise-routes=172.30.0.0/24
```

Approve the route in the Tailscale admin console (Machines → tiny → Edit route
settings). macOS and Windows clients accept routes automatically; a Linux
laptop needs `sudo tailscale set --accept-routes`.

If Docker is installed on the host, also let tailnet traffic through to the
VMs. In [`config/network.env`](../config/network.env):

```bash
FC_TRUSTED_IFACES=tailscale0
```

Then `make net` again. Now `http://172.30.0.2/` works from the laptop.

`net/setup.sh` turns on IP forwarding, which subnet routing needs, but only
until reboot. To keep it across reboots:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-forwarding.conf
```

Only devices in your tailnet can reach the VMs this way; the subnet isn't
exposed to the internet or your work network.

### Option B: SSH tunnel (one service at a time)

No Tailscale settings needed:

```bash
ssh -L 8080:172.30.0.2:80 <user>@tiny
```

Then open `http://localhost:8080` on the laptop.

## 4. Git on the host

Git identity is per clone; it isn't stored in the repository. After cloning on
the host:

```bash
git clone git@github.com:qvarnstr0m/firecracker-lab.git
cd firecracker-lab
git config user.name qvarnstr0m
git config user.email <your personal email>
```

To push from the host, either:

- add an SSH key from the host to your GitHub account
  (`ssh-keygen -t ed25519`, then add `~/.ssh/id_ed25519.pub` on GitHub), or
- forward your laptop's SSH agent: `ssh -A <user>@tiny`. Only do this to hosts
  you trust, since root on the host can use your forwarded keys.

Keep your work Git identity and keys out of this repo.

## Checklist

- [ ] Tailscale on host and laptop, same tailnet
- [ ] `ssh <user>@tiny` works from the laptop
- [ ] `tmux new -As lab` on the host
- [ ] subnet route approved, `FC_TRUSTED_IFACES=tailscale0` if Docker is
      installed, or an SSH tunnel
- [ ] Git identity and push access set up in the host's clone
