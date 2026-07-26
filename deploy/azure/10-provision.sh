#!/usr/bin/env bash
# Provision the whole Phase 1 environment from nothing.
#
# Idempotent: every resource is created only if absent, so the script can be
# re-run safely. This is the draft of the Terraform code arriving in Phase 4 --
# the resource names and tags here are the ones that configuration will reuse.
#
# Usage: ./10-provision.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-variables.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

step() { echo; echo "==> $*"; }

# ---------------------------------------------------------------- resource group
step "Resource group ${RG}"
if az group show -n "$RG" &>/dev/null; then
  echo "    exists"
else
  az group create -n "$RG" -l "$LOCATION" --tags $TAGS -o none
  echo "    created"
fi

# -------------------------------------------------------------------- key vault
# Created before the database so the admin password never exists outside the vault.
# Purge protection is deliberately off: it would reserve the vault name after a
# group delete and break the tear-down-and-rebuild cycle this script exists for.
step "Key Vault ${KV}"
if az keyvault show -n "$KV" &>/dev/null; then
  echo "    exists"
else
  az keyvault create -n "$KV" -g "$RG" -l "$LOCATION" \
    --enable-rbac-authorization true --retention-days 7 --tags $TAGS -o none
  echo "    created"
fi

# Subscription Owner does not grant access to vault contents: Azure separates the
# management plane from the data plane, so a dedicated data-plane role is required.
step "Granting myself Key Vault Secrets Officer"
MY_ID=$(az ad signed-in-user show --query id -o tsv)
KV_SCOPE=$(az keyvault show -n "$KV" --query id -o tsv)
az role assignment create \
  --assignee-object-id "$MY_ID" --assignee-principal-type User \
  --role "Key Vault Secrets Officer" --scope "$KV_SCOPE" -o none 2>/dev/null || true
echo "    granted (waiting 30s for RBAC propagation)"
sleep 30

# The password is alphanumeric on purpose: PostgreSQL connection strings are URLs,
# and characters like @ / : ? break them.
step "Database admin password"
if az keyvault secret show --vault-name "$KV" -n postgres-admin-password &>/dev/null; then
  echo "    already in the vault"
else
  PWD_NEW=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)
  az keyvault secret set --vault-name "$KV" -n postgres-admin-password \
    --value "$PWD_NEW" -o none
  unset PWD_NEW
  echo "    generated and stored"
fi

# ------------------------------------------------------------ container registry
# Admin account disabled: authentication runs on Entra identities, so no registry
# password exists anywhere in this project.
step "Container registry ${ACR}"
if az acr show -n "$ACR" &>/dev/null; then
  echo "    exists"
else
  az acr create -n "$ACR" -g "$RG" --sku Basic --admin-enabled false \
    --tags $TAGS -o none
  echo "    created"
fi

# -------------------------------------------------------------------- postgresql
step "PostgreSQL ${PSQL}"
DB_PWD=$(az keyvault secret show --vault-name "$KV" -n postgres-admin-password --query value -o tsv)
FQDN="${PSQL}.postgres.database.azure.com"

if az postgres flexible-server show -g "$RG" -n "$PSQL" &>/dev/null; then
  echo "    exists"
else
  # --public-access 0.0.0.0 is the Azure convention for "reachable from Azure
  # resources", not "reachable from the internet". Consumption Container Apps
  # egress from a shared pool of ~180 addresses that changes over time, so
  # per-IP allow-listing is unworkable. Closing this properly is Phase 2 work.
  az postgres flexible-server create \
    -g "$RG" -n "$PSQL" -l "$LOCATION" \
    --admin-user "$PSQL_ADMIN" --admin-password "$DB_PWD" \
    --tier Burstable --sku-name Standard_B1ms --storage-size 32 \
    --version 16 --backup-retention 7 --geo-redundant-backup Disabled \
    --public-access 0.0.0.0 --tags $TAGS --yes -o none
  echo "    created"
fi

step "Database ${PSQL_DB}"
if az postgres flexible-server db show -g "$RG" -s "$PSQL" -d "$PSQL_DB" &>/dev/null; then
  echo "    exists"
else
  az postgres flexible-server db create -g "$RG" -s "$PSQL" -n "$PSQL_DB" -o none
  echo "    created"
fi

step "Workstation firewall rule"
MY_IP=$(curl -s https://api.ipify.org)
az postgres flexible-server firewall-rule create \
  -g "$RG" -s "$PSQL" -n "dev-workstation" \
  --start-ip-address "$MY_IP" --end-ip-address "$MY_IP" -o none
echo "    allowed ${MY_IP}"

# psql runs from the postgres image so nothing has to be installed locally.
step "Loading the schema"
docker run --rm -i \
  -v "${REPO_ROOT}/db/init:/sql:ro" -e PGPASSWORD="$DB_PWD" postgres:16 \
  psql "host=${FQDN} port=5432 dbname=${PSQL_DB} user=${PSQL_ADMIN} sslmode=require" \
  -f /sql/01-schema.sql

# sslmode=require is part of the stored value, so encryption in transit is a
# property of the secret rather than an option someone can forget to pass.
step "Connection string secret"
DB_URL="postgresql://${PSQL_ADMIN}:${DB_PWD}@${FQDN}:5432/${PSQL_DB}?sslmode=require"
az keyvault secret set --vault-name "$KV" -n database-url --value "$DB_URL" -o none
unset DB_PWD DB_URL
echo "    stored"

# ----------------------------------------------------------------- observability
step "Log Analytics ${LOG}"
if az monitor log-analytics workspace show -g "$RG" -n "$LOG" &>/dev/null; then
  echo "    exists"
else
  az monitor log-analytics workspace create -g "$RG" -n "$LOG" -l "$LOCATION" \
    --retention-time 30 --tags $TAGS -o none
  echo "    created"
fi

step "Container Apps environment ${CAE}"
if az containerapp env show -g "$RG" -n "$CAE" &>/dev/null; then
  echo "    exists"
else
  LOG_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$LOG" --query customerId -o tsv)
  LOG_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RG" -n "$LOG" \
              --query primarySharedKey -o tsv)
  az containerapp env create -g "$RG" -n "$CAE" -l "$LOCATION" \
    --logs-workspace-id "$LOG_ID" --logs-workspace-key "$LOG_KEY" --tags $TAGS -o none
  unset LOG_KEY
  echo "    created"
fi

# --------------------------------------------------------------- managed identity
# No password exists for this identity -- Azure issues short-lived tokens on demand.
# AcrPull, not AcrPush: it can fetch images but never publish them.
# Secrets User, not Secrets Officer: it can read secrets but never write them.
step "Managed identity ${UAMI_NAME}"
if az identity show -g "$RG" -n "$UAMI_NAME" &>/dev/null; then
  echo "    exists"
else
  az identity create -g "$RG" -n "$UAMI_NAME" -l "$LOCATION" --tags $TAGS -o none
  echo "    created (waiting 20s for the service principal to appear)"
  sleep 20
fi
UAMI_ID=$(az identity show -g "$RG" -n "$UAMI_NAME" --query id -o tsv)
UAMI_PRINCIPAL=$(az identity show -g "$RG" -n "$UAMI_NAME" --query principalId -o tsv)

step "Identity role assignments"
az role assignment create --assignee-object-id "$UAMI_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal --role "AcrPull" \
  --scope "$(az acr show -n "$ACR" --query id -o tsv)" -o none 2>/dev/null || true
az role assignment create --assignee-object-id "$UAMI_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" \
  --scope "$KV_SCOPE" -o none 2>/dev/null || true
echo "    AcrPull + Key Vault Secrets User (waiting 30s for propagation)"
sleep 30

# ------------------------------------------------------------------ applications
# DATABASE_URL is a Key Vault reference resolved at startup by the identity above,
# so the connection string never appears in the application definition.
KV_URI="https://${KV}.vault.azure.net/secrets/database-url"

step "Web app ${CA_WEB}"
if az containerapp show -g "$RG" -n "$CA_WEB" &>/dev/null; then
  echo "    exists"
else
  az containerapp create -g "$RG" -n "$CA_WEB" --environment "$CAE" \
    --image "${ACR_LOGIN_SERVER}/postureguard-web:${IMAGE_TAG}" \
    --registry-server "$ACR_LOGIN_SERVER" --registry-identity "$UAMI_ID" \
    --user-assigned "$UAMI_ID" \
    --secrets "database-url=keyvaultref:${KV_URI},identityref:${UAMI_ID}" \
    --env-vars "DATABASE_URL=secretref:database-url" \
    --target-port 3000 --ingress external \
    --min-replicas 0 --max-replicas 3 --cpu 0.5 --memory 1.0Gi \
    --tags $TAGS -o none
  echo "    created"
fi

# No ingress: the worker only consumes the queue. Exactly one replica -- at zero
# nobody processes scans, and SKIP LOCKED would handle more without collision but
# there is no reason to pay for that yet.
step "Worker ${CA_WORKER}"
if az containerapp show -g "$RG" -n "$CA_WORKER" &>/dev/null; then
  echo "    exists"
else
  az containerapp create -g "$RG" -n "$CA_WORKER" --environment "$CAE" \
    --image "${ACR_LOGIN_SERVER}/postureguard-worker:${IMAGE_TAG}" \
    --registry-server "$ACR_LOGIN_SERVER" --registry-identity "$UAMI_ID" \
    --user-assigned "$UAMI_ID" \
    --secrets "database-url=keyvaultref:${KV_URI},identityref:${UAMI_ID}" \
    --env-vars "DATABASE_URL=secretref:database-url" \
    --min-replicas 1 --max-replicas 1 --cpu 0.25 --memory 0.5Gi \
    --tags $TAGS -o none
  echo "    created"
fi

echo
echo "Provisioned. Default hostname:"
az containerapp show -g "$RG" -n "$CA_WEB" \
  --query "properties.configuration.ingress.fqdn" -o tsv
echo
echo "The custom domain (${CUSTOM_DOMAIN}) needs its DNS records and certificate"
echo "bound once per environment -- see docs/report/progress-report.md, step 9."
