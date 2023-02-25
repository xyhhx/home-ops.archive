output "control_plane_macs" {
  value = {
    for k, v in proxmox_vm_qemu.talos-control-plane : k => flatten([
      for nics in v.network : [
        nics.macaddr
      ]
    ])
  }
}

output "worker_macs" {
  value = {
    for k, v in proxmox_vm_qemu.talos-worker : k => flatten([
      for nics in v.network : [
        nics.macaddr
      ]
    ])
  }
}
