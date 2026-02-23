data "oci_containerengine_cluster_option" "current" {
  cluster_option_id = "all"
}

data "oci_core_services" "current" {
}

data "oci_identity_availability_domain" "ad1" {
  compartment_id = var.compartment_ocid
  ad_number      = 1
}

data "oci_containerengine_node_pool_option" "current" {
  node_pool_option_id = data.oci_containerengine_cluster_option.current.cluster_option_id
  compartment_id      = var.compartment_ocid
}

locals {
  # take the latest patch version of kubernetes minor
  # when a new version is released, old patch node pool images are deleted
  # e.g.: v1.33.1 is out, then all v1.33.0 are removed and there is an integrity check between control-plane and node pool
  kubernetes_version = reverse([for version in data.oci_containerengine_cluster_option.current.kubernetes_versions : version if length(regexall("${var.oke_kubernetes_version}\\.[0-9]+", version)) > 0])[0]
  oke_sources        = data.oci_containerengine_node_pool_option.current.sources

  oracle_linux_images = [for source in local.oke_sources : source.image_id if length(regexall("Oracle-Linux-\\d+\\.\\d+-[0-9.]{10}-\\d+-OKE-${substr(local.kubernetes_version, 1, -1)}+-[0-9]*", source.source_name)) > 0]

  # See https://docs.oracle.com/en-us/iaas/images/oke-worker-node-oracle-linux-8x/index.htm
  image_id = local.oracle_linux_images[0]

  shapes      = data.oci_containerengine_node_pool_option.current.shapes
  flex_shapes = [for shape in local.shapes : shape if length(regexall("VM\\.Standard(\\.E[0-9]|[0-9])\\.Flex", shape)) > 0]
  node_shape  = local.flex_shapes[length(local.flex_shapes) - 1]

  core_services   = data.oci_core_services.current.services
  network_service = one([for s in local.core_services : s if length(regexall("All [A-Z]+ Services In Oracle Services Network", s.name)) > 0])
}

resource "oci_core_vcn" "traefik-demo" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = var.oke_display_name
  dns_label      = "traefikdemo"
}

resource "oci_core_internet_gateway" "traefik-demo" {
  compartment_id = var.compartment_ocid
  display_name   = var.oke_display_name
  enabled        = "true"
  vcn_id         = oci_core_vcn.traefik-demo.id
}

resource "oci_core_nat_gateway" "traefik-demo" {
  compartment_id = var.compartment_ocid
  display_name   = var.oke_display_name
  vcn_id         = oci_core_vcn.traefik-demo.id
}

resource "oci_core_service_gateway" "traefik-demo" {
  compartment_id = var.compartment_ocid
  display_name   = var.oke_display_name
  services {
    service_id = local.network_service.id
  }
  vcn_id = oci_core_vcn.traefik-demo.id
}

resource "oci_core_route_table" "traefik-demo" {
  compartment_id = var.compartment_ocid
  display_name   = "oke-private-${var.oke_display_name}"
  route_rules {
    description       = "traffic to the internet"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.traefik-demo.id
  }
  route_rules {
    description       = "traffic to OCI services"
    destination       = local.network_service.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.traefik-demo.id
  }
  vcn_id = oci_core_vcn.traefik-demo.id
}

resource "oci_core_subnet" "svclb" {
  cidr_block                 = "10.0.20.0/24"
  compartment_id             = var.compartment_ocid
  display_name               = "oke-${var.oke_display_name}-svclb-regional"
  dns_label                  = "lbsubde4f0e3f7"
  prohibit_public_ip_on_vnic = "false"
  route_table_id             = oci_core_default_route_table.traefik-demo.id
  security_list_ids          = [oci_core_security_list.svclb.id]
  vcn_id                     = oci_core_vcn.traefik-demo.id
}

resource "oci_core_subnet" "nodes" {
  cidr_block                 = "10.0.10.0/24"
  compartment_id             = var.compartment_ocid
  display_name               = "oke-${var.oke_display_name}-nodesubnet-regional"
  dns_label                  = "sub58536a37a"
  prohibit_public_ip_on_vnic = "true"
  route_table_id             = oci_core_route_table.traefik-demo.id
  security_list_ids          = [oci_core_security_list.nodes.id]
  vcn_id                     = oci_core_vcn.traefik-demo.id
}

resource "oci_core_subnet" "kubernetes_api_endpoint" {
  cidr_block                 = "10.0.0.0/28"
  compartment_id             = var.compartment_ocid
  display_name               = "oke-${var.oke_display_name}-k8sApiEndpoint-regional"
  dns_label                  = "subd14ec26fe"
  prohibit_public_ip_on_vnic = "false"
  route_table_id             = oci_core_default_route_table.traefik-demo.id
  security_list_ids          = [oci_core_security_list.kubernetes_api_endpoint.id]
  vcn_id                     = oci_core_vcn.traefik-demo.id
}

resource "oci_core_default_route_table" "traefik-demo" {
  display_name = "oke-public-${var.oke_display_name}"
  route_rules {
    description       = "traffic to/from internet"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.traefik-demo.id
  }
  manage_default_resource_id = oci_core_vcn.traefik-demo.default_route_table_id
}

resource "oci_core_security_list" "svclb" {
  compartment_id = var.compartment_ocid
  display_name   = "oke-svclb-${var.oke_display_name}"
  vcn_id         = oci_core_vcn.traefik-demo.id

  lifecycle {
    ignore_changes = [
      egress_security_rules,
      ingress_security_rules
    ]
  }
}

resource "oci_core_security_list" "nodes" {
  compartment_id = var.compartment_ocid
  display_name   = "oke-nodes-${var.oke_display_name}"
  egress_security_rules {
    description      = "Allow pods on one worker node to communicate with pods on other worker nodes"
    destination      = "10.0.10.0/24"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = "false"
  }
  egress_security_rules {
    description      = "Access to Kubernetes API Endpoint"
    destination      = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = "false"

    tcp_options {
      max = 6443
      min = 6443
    }
  }
  egress_security_rules {
    description      = "Kubernetes worker to control plane communication"
    destination      = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = "false"
    tcp_options {
      max = 12250
      min = 12250
    }
  }
  egress_security_rules {
    description      = "Path discovery"
    destination      = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol  = "1"
    stateless = "false"
  }
  egress_security_rules {
    description      = "Allow nodes to communicate with OKE to ensure correct start-up and continued functioning"
    destination      = local.network_service.cidr_block
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6"
    stateless        = "false"

    tcp_options {
      max = 443
      min = 443
    }
  }
  egress_security_rules {
    description      = "ICMP Access from Kubernetes Control Plane"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol  = "1"
    stateless = "false"
  }
  egress_security_rules {
    description      = "Worker Nodes access to Internet"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = "false"
  }
  ingress_security_rules {
    description = "Allow pods on one worker node to communicate with pods on other worker nodes"
    protocol    = "all"
    source      = "10.0.10.0/24"
    stateless   = "false"
  }
  ingress_security_rules {
    description = "Path discovery"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol  = "1"
    source    = "10.0.0.0/28"
    stateless = "false"
  }
  ingress_security_rules {
    description = "TCP access from Kubernetes Control Plane"
    protocol    = "6"
    source      = "10.0.0.0/28"
    stateless   = "false"
  }
  ingress_security_rules {
    description = "Inbound SSH traffic to worker nodes"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = "false"
    tcp_options {
      max = 22
      min = 22
    }
  }
  vcn_id = oci_core_vcn.traefik-demo.id
  lifecycle {
    ignore_changes = [
      egress_security_rules,
      ingress_security_rules
    ]
  }
}

resource "oci_core_security_list" "kubernetes_api_endpoint" {
  compartment_id = var.compartment_ocid
  display_name   = "oke-k8sApiEndpoint-${var.oke_display_name}"

  egress_security_rules {
    description      = "Allow Kubernetes Control Plane to communicate with OKE"
    destination      = local.network_service.cidr_block
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6"
    stateless        = "false"

    tcp_options {
      max = 443
      min = 443
    }
  }
  egress_security_rules {
    description      = "All traffic to worker nodes"
    destination      = "10.0.10.0/24"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = "false"
  }
  egress_security_rules {
    description      = "Path discovery"
    destination      = "10.0.10.0/24"
    destination_type = "CIDR_BLOCK"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol  = "1"
    stateless = "false"
  }
  ingress_security_rules {
    description = "External access to Kubernetes API endpoint"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = "false"

    tcp_options {
      max = 6443
      min = 6443
    }
  }
  ingress_security_rules {
    description = "Kubernetes worker to Kubernetes API endpoint communication"
    protocol    = "6"
    source      = "10.0.10.0/24"
    stateless   = "false"

    tcp_options {
      max = 6443
      min = 6443
    }
  }
  ingress_security_rules {
    description = "Kubernetes worker to control plane communication"
    protocol    = "6"
    source      = "10.0.10.0/24"
    stateless   = "false"

    tcp_options {
      max = 12250
      min = 12250
    }
  }
  ingress_security_rules {
    description = "Path discovery"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol  = "1"
    source    = "10.0.10.0/24"
    stateless = "false"
  }
  vcn_id = oci_core_vcn.traefik-demo.id
}

resource "oci_containerengine_cluster" "traefik-demo" {
  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }
  compartment_id = var.compartment_ocid
  endpoint_config {
    is_public_ip_enabled = "true"
    subnet_id            = oci_core_subnet.kubernetes_api_endpoint.id
  }
  freeform_tags = {
    "OKEclusterName" = var.oke_display_name
  }
  kubernetes_version = local.kubernetes_version
  name               = var.oke_display_name
  options {
    admission_controller_options {
      is_pod_security_policy_enabled = "false"
    }
    persistent_volume_config {
      freeform_tags = {
        "OKEclusterName" = var.oke_display_name
      }
    }
    service_lb_config {
      freeform_tags = {
        "OKEclusterName" = var.oke_display_name
      }
    }
    service_lb_subnet_ids = [oci_core_subnet.svclb.id]
  }
  type   = "ENHANCED_CLUSTER" # "BASIC_CLUSTER"
  vcn_id = oci_core_vcn.traefik-demo.id
}

resource "oci_containerengine_node_pool" "traefik-demo" {
  cluster_id     = oci_containerengine_cluster.traefik-demo.id
  compartment_id = var.compartment_ocid
  freeform_tags = {
    "OKEnodePoolName" = var.oke_display_name
  }
  initial_node_labels {
    key   = "name"
    value = var.oke_display_name
  }
  kubernetes_version = local.kubernetes_version
  name               = var.oke_display_name
  node_config_details {
    freeform_tags = {
      "OKEnodePoolName" = var.oke_display_name
    }
    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [oci_core_subnet.nodes.id]
    }
    placement_configs {
      availability_domain = data.oci_identity_availability_domain.ad1.name
      subnet_id           = oci_core_subnet.nodes.id
    }
    size = var.oke_nodes_count
  }
  node_eviction_node_pool_settings {
    eviction_grace_duration              = "PT2M"
    is_force_delete_after_grace_duration = true
  }
  node_shape = local.node_shape
  node_shape_config {
    memory_in_gbs = var.oke_nodes_mem_in_gb
    ocpus         = var.oke_nodes_cpu
  }
  node_source_details {
    image_id    = local.image_id
    source_type = "IMAGE"
  }
}
