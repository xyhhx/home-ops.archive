variable "pve_node" {
  type        = string
  description = "The Proxmox node to add the talos nodes to"
}

variable "vlan_tag" {
  type        = string
  description = "The VLAN tag to attribute to the nodes' network devices"
}

variable "bridge" {
  type        = string
  description = "The Linux bridge name (in Proxmox) to assign to the nodes"
}

variable "storage" {
  type        = string
  description = "The storage pool to add talos nodes' drives to"
}

variable "talos_template_name" {
  type        = string
  description = "The name of the Talos template in Proxmox"
}

variable "control_plane_nodes_count" {
  type        = number
  description = "The amount of control plane nodes to provision"
}

variable "worker_nodes_count" {
  type        = number
  description = "The amount of worker nodes to provision"
}

variable "control_plane_total_mem" {
  type = number
  description = "How many MB to distribute among the control plane nodes"
}

variable "workers_total_mem" {
  type = number
  description = "How many MB to distribute among the worker nodes"
}
