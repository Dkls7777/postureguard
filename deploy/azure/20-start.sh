#!/usr/bin/env bash
# Wake the environment up for a work session.
# Starts the database, refreshes the workstation firewall rule (a residential IP
# is dynamic and a stale rule looks exactly like a broken database), and brings
# the worker back online.
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

# The worker runs in single-revision mode, where Azure owns the revision
# lifecycle: a deactivated revision cannot be activated again (the API returns
# "Method Not Allowed"). Changing the scale settings produces a new revision,
# which becomes the active one. Found by testing the script rather than trusting it.
echo "==> Bringing the worker back"
az containerapp update -g "$RG" -n "$CA_WORKER" \
  --min-replicas 1 --max-replicas 1 -o none
sleep 25
az containerapp replica list -g "$RG" -n "$CA_WORKER" -o table

echo
echo "Environment up. https://${CUSTOM_DOMAIN}"
