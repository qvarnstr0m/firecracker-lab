# Guest kernel config

`kernel/build.sh` looks here for `microvm-<arch>.config`, for example
`microvm-x86_64.config`. If the file is missing, it uses the config that
`kernel/fetch.sh` downloaded next to the prebuilt kernel (`build/vmlinux.config`).

Good starting points are Firecracker's own guest configs in
[`resources/guest_configs/`](https://github.com/firecracker-microvm/firecracker/tree/main/resources/guest_configs).

Options this lab depends on:

| Option | Why |
| --- | --- |
| `CONFIG_VIRTIO_BLK`, `CONFIG_VIRTIO_NET`, `CONFIG_VIRTIO_MMIO` | rootfs disk and network |
| `CONFIG_EXT4_FS` | rootfs filesystem |
| `CONFIG_SERIAL_8250_CONSOLE` | `console=ttyS0` |
| `CONFIG_IP_PNP` | `ip=` kernel argument configures `eth0` without DHCP |
| `CONFIG_DEVTMPFS` | `/dev` in the guest |
