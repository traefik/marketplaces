output "latest_k8s_version" {
  value = local.kubernetes_version
}

data "oci_core_image" "oke" {
  image_id = local.image_id
}

output "image_name" {
  value = data.oci_core_image.oke.display_name
}

output "image_id" {
  value = local.image_id
}

output "node_shape" {
  value = local.node_shape
}

output "cluster_id" {
  value = oci_containerengine_cluster.traefik-demo.id
}

output "pool_state" {
  value = oci_containerengine_node_pool.traefik-demo.state
}
