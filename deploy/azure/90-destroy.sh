#!/usr/bin/env bash
# Delete every Azure resource for the project.
# The real asset is this repository; the cloud is rented on demand and can be
# rebuilt with 10-provision.sh. Requires typing the resource group name.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-variables.sh"

echo "This deletes EVERYTHING in ${RG}:"
az resource list -g "$RG" --query "[].{name:name, type:type}" -o table

echo
read -rp "Type the resource group name to confirm: " CONFIRM
if [ "$CONFIRM" != "$RG" ]; then
  echo "Aborted."
  exit 1
fi

az group delete --name "$RG" --yes --no-wait
echo "Deletion started (running in the background)."
echo
echo "Note: the Key Vault is soft-deleted for 7 days and its name stays reserved."
echo "To free the name immediately:"
echo "  az keyvault purge --name ${KV} --location ${LOCATION}"
