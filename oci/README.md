# oci-traefiklabs-stacks

To launch it locally, you'll need to go back to latest terraform version before license change:

```sh
sudo apt-get install terraform=1.5.7-1
```

and set those env. variables:

```sh
export TF_VAR_chart_hub_token=
export TF_VAR_chart_hub_version="v3.17.0"
export TF_VAR_chart_namespace="traefik"
export TF_VAR_chart_values=""
export TF_VAR_region="eu-madrid-1"
export TF_VAR_tenancy_ocid=""
export TF_VAR_compartment_ocid=""
export TF_VAR_oke_cluster_create=true
export TF_VAR_chart_create_namespace=true
export TF_VAR_local_run=true
```       

## Debug an OCI stack

Unfortunately, `TF_LOG` can't be set on OCI VMs.
Thus, to debug the execution of the stack, you may want to execute some commands on OCI stack VM.
This can be achieved with the following terraform object:

```terraform
resource "null_resource" "debug" {

  provisioner "local-exec" {
    command = <<EOT
set -x
env
ls -la /home/orm
cat /home/orm/config
cat /etc/subuid
cat /etc/subgid
id
docker version
EOT
  }

  provisioner "local-exec" {
    command = "docker ${join(" ", ["run", "--rm", "-t", "--userns", "keep-id:uid=1000,gid=1000", "-v", "/home/orm:/home/orm", "-e", "OCI_CLI_AUTH", "-e",
    "OCI_CLI_CONFIG_FILE", "-e", "OCI_CLI_CLOUD_SHELL", "-e", "OCI_CLI_USE_INSTANCE_METADATA_SERVICE",
    "ghcr.io/oracle/oci-cli:20250716", "ce", "cluster", "generate-token", "--cluster-id",
    data.oci_containerengine_cluster.target.id, "--region", var.region])}"
  }

  triggers = {
    always_run = timestamp()
  }
}
```
   
> [!NOTE] 
> While running docker commands, you may have to know OCI VM uses `podman`.
> cf. https://docs.podman.io/en/latest/markdown/podman-run.1.html

## Releasing

1. run `make release`
2. go to [TraefikLabs stacks](https://cloud.oracle.com/resourcemanager/stacks?region=us-ashburn-1)
3. for each of `hub-apim-stack`, `hub-stack`, `proxy-stack`:
   - click on the stack, then Edit > Edit stack
   - upload the corresponding zip file generated previously
   - click on Next > Next
   - check the box Run apply
   - click on Save changes
4. once all have been deployed (one by one) then destroyed successfully, go to [Partner portal](https://partner.cloudmarketplace.oracle.com)
5. click on Artifacts
6. for each of `hub-apim`, `hub`, `proxy`:
   - Create Artifact
   - enter the artifact name: <artifact>-YYYYMMDD
   - select the Stack OCID
   - check the "Mandatory Guidelines" box
   - click on Create
7. go to Listings > Started
8. for each:
   - click on right menu > New Version > OK
   - click on Listing > Started > right menu > Edit > App Install Package > right menu > New Version > OK
   - on the newly created package > right menu > Edit > Define Package Information > Edit > increment version number > Save
   - Configure Terraform Template > Edit > select the corresponding artifact
   - click on Back
   - on the newly created version > right menu > Mark As Default > OK
   - Submit
9. go to Listings > Submitted, for each click on Publish
