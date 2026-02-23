data "oci_containerengine_node_pools" "target" {
  compartment_id = var.compartment_ocid
  cluster_id     = var.oke_cluster_create ? module.oke[0].cluster_id : var.oke_cluster_id
  state          = var.oke_cluster_create ? [module.oke[0].pool_state] : ["ACTIVE"]
}

resource "kubernetes_namespace" "traefik" {
  depends_on = [data.oci_containerengine_node_pools.target]

  count = var.chart_create_namespace ? 1 : 0

  metadata {
    name = var.chart_namespace
  }
}

resource "kubernetes_secret" "license" {
  depends_on = [kubernetes_namespace.traefik]

  metadata {
    name      = "traefik-hub-license"
    namespace = var.chart_namespace
  }

  data = {
    token = var.chart_hub_token
  }

  type = "Opaque"
}

resource "helm_release" "traefik" {
  depends_on = [kubernetes_secret.license]
  name       = "traefik"

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"

  namespace        = var.chart_namespace
  create_namespace = false

  # values = [file(var.chart_values)]
  values = [var.chart_values]

  set = [
    {
      name  = "hub.token"
      value = "traefik-hub-license"
    },
    {
      name  = "hub.apimanagement.enabled"
      value = true
    },
    {
      name  = "image.registry"
      value = "ghcr.io"
    },
    {
      name  = "image.repository"
      value = "traefik/traefik-hub"
    },
    {
      name  = "image.tag"
      value = var.chart_hub_version
    }
  ]
}

# Used to get NOTES.txt
data "helm_template" "traefik" {
  name = "traefik"

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"

  namespace = var.chart_namespace
  values    = [var.chart_values]

  set = [
    {
      name  = "hub.token"
      value = "traefik-hub-license"
    },
    {
      name  = "image.registry"
      value = "ghcr.io"
    },
    {
      name  = "image.repository"
      value = "traefik/traefik-hub"
    },
    {
      name  = "image.tag"
      value = var.chart_hub_version
    }
  ]

  # As of v3.0.2, the data source requires this kube_version to be set.
  # Otherwise, it believes we are on k8s v1.20.
  kube_version = data.oci_containerengine_cluster.target.kubernetes_version
}
