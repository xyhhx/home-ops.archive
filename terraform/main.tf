resource "proxmox_vm_qemu" "talos-control-plane" {
  count = var.control_plane_nodes_count

  agent       = var.qemu_guest_agent_enabled
  clone       = var.talos_template_name
  name        = "talos-cp-${count.index + 1}"
  tags        = var.pve_tags
  target_node = var.pve_node

  memory  = var.control_plane_total_mem / var.control_plane_nodes_count
  sockets = 2
  cores   = 2
  scsihw  = "virtio-scsi-single"
  onboot  = true

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

  agent       = var.qemu_guest_agent_enabled
  clone       = var.talos_template_name
  name        = "talos-wk-${count.index + 1}"
  tags        = var.pve_tags
  target_node = var.pve_node

  memory  = var.workers_total_mem / var.worker_nodes_count
  sockets = 2
  cores   = 2
  scsihw  = "virtio-scsi-single"
  onboot  = true

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

  disk {
    type    = "scsi"
    size    = "72G"
    storage = var.storage
  }
}
