variable "talos_control_plane" {
  default = {
    1 = { hostname = "talos-cp-1" }
    2 = { hostname = "talos-cp-2" }
    3 = { hostname = "talos-cp-3" }
  }
}

variable "talos_workers" {
  default = {
    1 = { hostname = "talos-wk-1" }
    2 = { hostname = "talos-wk-2" }
    3 = { hostname = "talos-wk-3" }
    4 = { hostname = "talos-wk-4" }
  }
}

variable "pve_node" {
  type = string
}

variable "talos_iso" {
  type = string
}

variable "vlan_tag" {
  type = string
}

variable "bridge" {
  type = string
}

variable "storage" {
  type = string
}
