#!/usr/bin/env bash
# Build both images from the current commit, push them, and roll out new revisions.
# Images are tagged with the short git SHA so that any deployment is traceable to
# the exact code that produced it, and rollback has something specific to target.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-variables.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
  echo "Working tree is dirty. Commit before deploying so the image tag means something."
  exit 1
fi

SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
echo "==> Deploying commit ${SHA}"

az acr login --name "$ACR" -o none

for component in web worker; do
  echo "==> Building ${component}"
  docker build -t "postureguard-${component}:${SHA}" "${REPO_ROOT}/${component}"
  docker tag "postureguard-${component}:${SHA}" "${ACR_LOGIN_SERVER}/postureguard-${component}:${SHA}"
  docker push "${ACR_LOGIN_SERVER}/postureguard-${component}:${SHA}"
done

echo "==> Rolling out"
az containerapp update -g "$RG" -n "$CA_WEB" \
  --image "${ACR_LOGIN_SERVER}/postureguard-web:${SHA}" -o none
az containerapp update -g "$RG" -n "$CA_WORKER" \
  --image "${ACR_LOGIN_SERVER}/postureguard-worker:${SHA}" -o none

echo "==> Revisions"
for app in "$CA_WEB" "$CA_WORKER"; do
  echo "-- ${app}"
  az containerapp revision list -g "$RG" -n "$app" \
    --query "[].{revision:name, active:properties.active, traffic:properties.trafficWeight}" \
    -o table
done
