#!/usr/bin/env bash
# Pause everything billable between sessions.
# The web app scales to zero on its own; the worker does not, because it has no
# ingress and therefore no scale trigger. Deactivating its revision is the only
# reliable off switch -- verified with `az containerapp replica list`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-variables.sh"

echo "==> Deactivating the worker"
REV=$(az containerapp revision list -g "$RG" -n "$CA_WORKER" \
        --query "[?properties.active] | [0].name" -o tsv)
if [ -n "${REV:-}" ]; then
  az containerapp revision deactivate -g "$RG" -n "$CA_WORKER" --revision "$REV" -o none
  echo "    ${REV} deactivated"
else
  echo "    no active revision"
fi

echo "==> Stopping PostgreSQL"
STATE=$(az postgres flexible-server show -g "$RG" -n "$PSQL" --query state -o tsv)
if [ "$STATE" = "Ready" ]; then
  az postgres flexible-server stop -g "$RG" -n "$PSQL" -o none
  echo "    stopped (Azure restarts it automatically after 7 days)"
else
  echo "    already ${STATE}"
fi

echo "==> Remaining replicas (should be empty)"
az containerapp replica list -g "$RG" -n "$CA_WORKER" -o table

echo
echo "Paused. Only storage and the registry keep billing."
