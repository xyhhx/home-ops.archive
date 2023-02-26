resource "proxmox_vm_qemu" "talos-control-plane" {
  count = 2

  name        = "talos-cp-${count.index + 1}"
  target_node = var.pve_node
  clone       = var.talos_template_name

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
  count = 2

  name        = "talos-wk-${count.index + 1}"
  target_node = var.pve_node
  clone       = var.talos_template_name

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
