{
  "boot-source": {
    "kernel_image_path": "@KERNEL@",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off @BOOT_ARGS@"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "@ROOTFS@",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": @VCPUS@,
    "mem_size_mib": @MEM_MIB@
  },
  "network-interfaces": []
}
