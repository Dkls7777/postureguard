#!/usr/bin/env bash
# Wake the environment up for a work session.
# Starts the database, refreshes the workstation firewall rule (home IP is dynamic),
# and brings the worker back online.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-variables.sh"

echo "==> Starting PostgreSQL"
STATE=$(az postgres flexible-server show -g "$RG" -n "$PSQL" --query state -o tsv)
if [ "$STATE" = "Stopped" ]; then
  az postgres flexible-server start -g "$RG" -n "$PSQL" -o none
  echo "    started"
else
  echo "    already ${STATE}"
fi

echo "==> Refreshing workstation firewall rule"
MY_IP=$(curl -s https://api.ipify.org)
az postgres flexible-server firewall-rule create \
  -g "$RG" -s "$PSQL" -n "dev-workstation" \
  --start-ip-address "$MY_IP" --end-ip-address "$MY_IP" -o none
echo "    allowed ${MY_IP}"

echo "==> Activating the worker"
REV=$(az containerapp revision list -g "$RG" -n "$CA_WORKER" \
        --query "[0].name" -o tsv)
az containerapp revision activate -g "$RG" -n "$CA_WORKER" --revision "$REV" -o none
az containerapp update -g "$RG" -n "$CA_WORKER" --min-replicas 1 --max-replicas 1 -o none
echo "    revision ${REV} active"

echo
echo "Environment up. https://${CUSTOM_DOMAIN}"
