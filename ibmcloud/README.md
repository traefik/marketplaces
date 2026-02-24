# IBM Cloud - Traefik Hub Catalog

## Prerequisites

```bash
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
ibmcloud plugin install catalogs-management
ibmcloud plugin install kubernetes-service
ibmcloud plugin install vpc-infrastructure
ibmcloud plugin install container-registry
ibmcloud login --sso
ibmcloud target -r us-south
```

## Infrastructure

VPC `vpc-us-south-u7` with 3 subnets and public gateways.

```bash
# Get VPC ID
VPC_ID=$(ibmcloud is vpcs --output json | jq -r '.[] | select(.name=="vpc-us-south-u7") | .id')

# List subnets and public gateways
ibmcloud is subnets --vpc "$VPC_ID" --output json | jq -r '.[] | [.zone.name, .id, .public_gateway.id] | @tsv'
```

## Create a test cluster

```bash
VPC_ID=$(ibmcloud is vpcs --output json | jq -r '.[] | select(.name=="vpc-us-south-u7") | .id')
SUBNET_ID=$(ibmcloud is subnets --vpc "$VPC_ID" --output json | jq -r '[.[] | select(.zone.name=="us-south-1")][0].id')

# Create cluster
ibmcloud ks cluster create vpc-gen2 \
    --name traefik-hub-test \
    --zone us-south-1 \
    --vpc-id "$VPC_ID" \
    --subnet-id "$SUBNET_ID" \
    --flavor bx2.2x8 \
    --workers 1

# Get cluster ID from the name
CLUSTER_ID=$(ibmcloud ks cluster get --cluster traefik-hub-test --output json | jq -r '.id')

# Wait for the cluster and worker nodes to be ready
until ibmcloud ks cluster get --cluster "$CLUSTER_ID" --output json | jq -e '.state == "normal"' > /dev/null 2>&1; do
  echo "Waiting for cluster to be ready..."
  sleep 30
done
until ibmcloud ks worker ls --cluster "$CLUSTER_ID" --output json | jq -e 'all(.health.state == "normal")' > /dev/null 2>&1; do
  echo "Waiting for worker nodes to be ready..."
  sleep 30
done

# Allow outbound HTTPS only (Secure by Default blocks all outbound)
SG_ID=$(ibmcloud ks security-group ls --cluster "$CLUSTER_ID" --output json | jq -r '.[0].id')
ibmcloud is sg-rulec "$SG_ID" outbound tcp --port-min 443 --port-max 443 --remote 0.0.0.0/0

# Tip: to open all outbound instead, use --disable-outbound-traffic-protection at creation
# or: ibmcloud ks vpc outbound-traffic-protection disable --cluster "$CLUSTER_ID"

# Tip: if outbound is fully blocked, mirror images to ICR instead:
# ibmcloud cr login
# ibmcloud cr namespace-add traefik-hub  # once
# crane copy ghcr.io/traefik/traefik-hub:v3.19.0 us.icr.io/traefik-hub/traefik-hub:v3.19.0

# Get kubeconfig
ibmcloud ks cluster config --cluster "$CLUSTER_ID"

# Disable default IBM ingress ALB (Traefik Hub replaces it)
ALB_ID=$(ibmcloud ks ingress alb ls --cluster "$CLUSTER_ID" --output json | jq -r '.[0].albID')
ibmcloud ks ingress alb disable --alb "$ALB_ID" --cluster "$CLUSTER_ID"
```

## Delete a test cluster

```bash
ibmcloud ks cluster rm --cluster "$CLUSTER_ID" -f
```

## Releasing

```bash
bash release.sh <catalog-name>
```
