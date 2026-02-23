variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "region" {}

variable "oke_display_name" {
  default = "traefik-demo"
}

variable "node_shape" {
  type    = string
  default = "VM.Standard.E3.Flex"
}

variable "oke_nodes_count" {
  type    = string
  default = "1"
}

variable "oke_nodes_cpu" {
  type    = string
  default = "2"
}

variable "oke_nodes_mem_in_gb" {
  type    = string
  default = "8"
}

variable "oke_kubernetes_version" {
  type    = string
  default = "v1.33"
}
