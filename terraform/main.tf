resource "proxmox_vm_qemu" "talos-control-plane" {
  for_each = var.talos_control_plane

  name        = each.value.hostname
  target_node = var.pve_node
  clone       = "talos-node"

  memory  = 2048
  sockets = 2
  cores   = 2
  scsihw  = "virtio-scsi-single"

  network {
    firewall = false
    model    = "virtio"
    tag      = var.vlan_tag
    bridge   = var.bridge
  }

  disk {
    type    = "scsi"
    size    = "32G"
    storage = var.storage
  }
}

resource "proxmox_vm_qemu" "talos-worker" {
  for_each = var.talos_workers

  name        = each.value.hostname
  target_node = var.pve_node
  clone       = "talos-node"

  memory  = 14848
  sockets = 2
  cores   = 2
  scsihw  = "virtio-scsi-single"

  network {
    firewall = false
    model    = "virtio"
    tag      = var.vlan_tag
    bridge   = var.bridge
  }

  disk {
    type    = "scsi"
    size    = "32G"
    storage = var.storage
  }
}
