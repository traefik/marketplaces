#!/bin/bash
set -eo pipefail

CATALOG_NAME="${1:?Usage: $0 <catalog-name>}"
CHART_TGZ_URL="${2:-https://traefik.github.io/charts/traefik/traefik-39.0.2.tgz}"
TARGET_VERSION="${3:-v3.6.8}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Fetch offering ---
echo "==> Fetching offering from catalog '${CATALOG_NAME}'..."
OFFERING_JSON=$(ibmcloud catalog offering get --catalog "${CATALOG_NAME}" --offering "Traefik Hub" --output json)

VERSION_LOCATOR=$(echo "$OFFERING_JSON" | jq -r '.kinds[0].versions[0].version_locator // empty')

# --- Import version if it doesn't exist ---
if [ -z "$VERSION_LOCATOR" ]; then
  echo "==> Importing ${TARGET_VERSION}..."
  ibmcloud catalog offering import-version \
    --catalog "${CATALOG_NAME}" \
    --offering "Traefik Hub" \
    --zipurl "${CHART_TGZ_URL}" \
    --target-version "${TARGET_VERSION}" \
    --include-config

  # Re-fetch after import
  OFFERING_JSON=$(ibmcloud catalog offering get --catalog "${CATALOG_NAME}" --offering "Traefik Hub" --output json)
  VERSION_LOCATOR=$(echo "$OFFERING_JSON" | jq -r '.kinds[0].versions[0].version_locator')
else
  echo "==> Version ${TARGET_VERSION} already exists (${VERSION_LOCATOR}), updating..."
fi

echo "==> Version locator: ${VERSION_LOCATOR}"

# --- Update offering (GET + merge overrides) ---
echo "==> Updating offering (icon, tags)..."
echo "$OFFERING_JSON" \
  | jq --slurpfile o "${SCRIPT_DIR}/offering.json.tpl" '. + $o[0]' \
  > /tmp/ibmcloud-offering.json

ibmcloud catalog offering update \
  --catalog "${CATALOG_NAME}" \
  --offering "Traefik Hub" \
  --updated-offering /tmp/ibmcloud-offering.json

# --- Update version (GET + merge overrides) ---
echo "==> Fetching version details..."
VERSION_JSON=$(ibmcloud catalog offering version get --version-locator "${VERSION_LOCATOR}" --output json)

README=$(cat "${SCRIPT_DIR}/version-readme.md")

echo "==> Updating version (helm values, licenses, readme)..."
echo "$VERSION_JSON" \
  | jq --slurpfile o "${SCRIPT_DIR}/version-overrides.json" \
    --arg readme "$README" \
    '.kinds[0].versions[0] += $o[0] | .kinds[0].versions[0].long_description = $readme' \
  > /tmp/ibmcloud-version.json

ibmcloud catalog offering version update \
  --version-locator "${VERSION_LOCATOR}" \
  --updated-offering-version /tmp/ibmcloud-version.json

echo "==> Done."
