data "oci_containerengine_node_pools" "target" {
  compartment_id = var.compartment_ocid
  cluster_id     = var.oke_cluster_create ? module.oke[0].cluster_id : var.oke_cluster_id
  state          = var.oke_cluster_create ? [module.oke[0].pool_state] : ["ACTIVE"]
}

resource "helm_release" "traefik" {
  depends_on = [data.oci_containerengine_node_pools.target]
  name       = "traefik"

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"

  namespace        = var.chart_namespace
  create_namespace = var.chart_namespace_create

  # values = [file(var.chart_values)]
  values = [var.chart_values]
}

data "helm_template" "traefik" {
  name = "traefik"

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"

  namespace = var.chart_namespace
  values    = [var.chart_values]

  # As of v3.0.2, the data source requires this kube_version to be set.
  # Otherwise, it believes we are on k8s v1.20.
  kube_version = data.oci_containerengine_cluster.target.kubernetes_version
}
