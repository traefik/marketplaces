#output "chart_output" {
#  # value = [ data.helm_template.traefik ]
#  value     = [helm_release.traefik]
#  sensitive = true
#}

#output "chart_manifest" {
#  value = yamlencode(jsondecode(helm_release.traefik.manifest))
#}

output "chart_status" {
  value = helm_release.traefik.status
}

output "chart_version" {
  value = helm_release.traefik.metadata.version
}

output "chart_notes" {
  value = data.helm_template.traefik.notes
}
