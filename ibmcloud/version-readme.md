Traefik Hub is a modern cloud-native API gateway and ingress controller built on top of Traefik Proxy. It provides API management capabilities including access control, rate limiting, and API portal features.

In IBM Cloud, you can configure your installation from the Create tab, and then install it with a single click instead of executing the Helm installation directly. Your Helm Chart is installed by using IBM Cloud Schematics, and after the installation is complete, you can view the chart instance, update the version, or uninstall from your Schematics workspace.

## Before you begin

* You must have a [Traefik Hub license token](https://hub.traefik.io/). You will be prompted for this token during installation.
* Download Kubernetes 1.22+ and Helm 3.9+.
* To successfully install the software, you must have the [administrator and manager roles](https://cloud.ibm.com/docs/iam?topic=iam-userroles#iamusermanrol) on the Kubernetes cluster service.

## Required resources

To run the software, the following resources are required:

* An IBM Cloud Kubernetes Service (IKS) cluster with at least 1 worker node
* 2 vCPU and 4 GB memory available on the cluster
* A Traefik Hub license token

## Installing the software

During installation, a Kubernetes secret containing your Traefik Hub license token is automatically created in the target namespace via a pre-install script.

The following Helm values are configured automatically:

| Parameter | Value | Description |
|-----------|-------|-------------|
| `hub.token` | `traefik-hub-license` | References the license secret |
| `hub.apimanagement.enabled` | `true` | Enables API management |
| `image.registry` | `ghcr.io` | Image registry |
| `image.repository` | `traefik/traefik-hub` | Image repository |
| `image.tag` | `v3.19.0` | Image version |

## Upgrading to a new version

When a new version of a Helm Chart is available, you're alerted in your Schematics workspace. To upgrade to a new version, complete the following steps:

1. Go to the **Menu** > **Schematics**.
2. Select your workspace name.
3. Click **Settings**. In the Summary section, your version number is displayed.
4. Click **Update**.
5. Select a version, and click **Update**.

## Uninstalling the software

Complete the following steps to uninstall a Helm Chart from your account.

1. Go to the **Menu** > **Schematics**.
2. Select your workspace name.
3. Click **Actions** > **Destroy resources**. All resources in your workspace are deleted.
4. Click **Update**.
5. To delete your workspace, click **Actions** > **Delete workspace**.
