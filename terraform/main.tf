resource "proxmox_vm_qemu" "talos-control-plane" {
  count = var.control_plane_nodes_count

  name        = "talos-cp-${count.index + 1}"
  target_node = var.pve_node
  clone       = var.talos_template_name

  memory  = var.control_plane_total_mem / var.control_plane_nodes_count
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
    size    = "12G"
    storage = var.storage
  }
}

resource "proxmox_vm_qemu" "talos-worker" {
  count = var.worker_nodes_count

  name        = "talos-wk-${count.index + 1}"
  target_node = var.pve_node
  clone       = var.talos_template_name

  memory  = var.workers_total_mem / var.worker_nodes_count
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
