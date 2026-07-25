#!/usr/bin/env bash
# PostureGuard - shared variables for all Azure scripts (Phase 1)
# Usage: source deploy/azure/00-variables.sh

set -euo pipefail

# --- Context ---
export SUBSCRIPTION_ID="23664c13-06e5-4a70-83a1-e880b3d153c9"
export LOCATION="francecentral"
export LOC_ABBR="frc"
export PROJECT="postureguard"
export ENVIRONMENT="prod"

# --- Resources (see docs/azure-naming-convention.md) ---
export RG="rg-${PROJECT}-${ENVIRONMENT}-${LOC_ABBR}"
export ACR="acr${PROJECT}${ENVIRONMENT}"          # alphanumeric only, global scope
export KV="kv-${PROJECT}-${ENVIRONMENT}"          # 24 chars max, global scope
export PSQL="psql-${PROJECT}-${ENVIRONMENT}"      # global scope
export PSQL_DB="postureguard"
export PSQL_ADMIN="pgadmin"
export LOG="log-${PROJECT}-${ENVIRONMENT}-${LOC_ABBR}"
export CAE="cae-${PROJECT}-${ENVIRONMENT}-${LOC_ABBR}"
export CA_WEB="ca-${PROJECT}-web"
export CA_WORKER="ca-${PROJECT}-worker"
export CUSTOM_DOMAIN="app.samdossou.com"

# --- Tags applied to every resource ---
export TAGS="project=${PROJECT} env=${ENVIRONMENT} phase=1 owner=sam.dossou managedBy=azure-cli"
