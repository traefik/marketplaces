variable "tenancy_ocid" {}
variable "region" {}

variable "compartment_ocid" {
  description = "Compartment where OKE and Marketplace subscription resources will be created"
}

variable "oke_cluster_id" {
  type    = string
  default = ""
}

variable "oke_cluster_name" {
  type    = string
  default = "traefik-demo"
}
variable "oke_cluster_create" {
  type    = bool
  default = false
}
variable "oke_insecure" {
  type    = bool
  default = false
}

variable "chart_values" {
  type = string
}

variable "chart_namespace" {
  type = string
}

variable "chart_namespace_create" {
  type    = bool
  default = false
}

// Can be set to true for local development
variable "local_run" {
  type    = bool
  default = false
}
