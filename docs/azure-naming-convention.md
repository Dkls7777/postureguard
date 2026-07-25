# Azure Naming and Tagging Convention

This convention applies to every Azure resource in the PostureGuard project from
Phase 1 onward. The Terraform code introduced in Phase 4 will reuse these exact names.

## General pattern
<type>-<project>-<env>[-<component>][-<region>]


- `<type>`: standard abbreviation for the resource type (see table below)
- `<project>`: always `postureguard`
- `<env>`: `prod` (single environment in Phase 1; `dev` arrives with Terraform)
- `<region>`: `frc` = France Central

Two exceptions are forced by Azure itself:

- **Container Registry**: alphanumeric only, no hyphens → `acrpostureguardprod`
- **Key Vault**: 24 characters maximum → region omitted

## Phase 1 resources

| Type | Abbrev. | Name | Name scope |
|---|---|---|---|
| Resource Group | `rg` | `rg-postureguard-prod-frc` | subscription |
| Container Registry | `acr` | `acrpostureguardprod` | **global** |
| Key Vault | `kv` | `kv-postureguard-prod` | **global** |
| PostgreSQL Flexible Server | `psql` | `psql-postureguard-prod` | **global** |
| Log Analytics Workspace | `log` | `log-postureguard-prod-frc` | resource group |
| Container Apps Environment | `cae` | `cae-postureguard-prod-frc` | resource group |
| Container App (web) | `ca` | `ca-postureguard-web` | resource group |
| Container App (worker) | `ca` | `ca-postureguard-worker` | resource group |
| Managed Identity | `id` | `id-postureguard-web` | resource group |

Global scope means the name must be unique across all of Azure, because it becomes a
public DNS name. Those three resources therefore omit the region: they are already
unique, and the region is readable from the tags.

## Region

**France Central** (`francecentral`): lowest latency from Paris, data hosted in France
(a GDPR-relevant argument), and available quota on the trial subscription.

## Mandatory tags

| Tag | Value | Purpose |
|---|---|---|
| `project` | `postureguard` | cost filtering per project |
| `env` | `prod` | separate future environments |
| `phase` | `1` | trace which roadmap phase created the resource |
| `owner` | `sam.dossou` | ownership |
| `managedBy` | `azure-cli` | becomes `terraform` in Phase 4 |

Tags are not cosmetic here: Azure Cost Management can break the bill down by tag, and
`managedBy` acts as a migration marker when infrastructure moves to IaC.

## Structural decision: a single resource group

The whole of Phase 1 lives in `rg-postureguard-prod-frc`. Reason: the Azure credit is
time-limited, and `az group delete` tears everything down in one command. Splitting
into several groups (network / data / application) will come with Terraform, once
rebuilding is automated.

## Variables

All names are centralised in `deploy/azure/00-variables.sh`, sourced by every
deployment script. No resource name is ever hard-coded in a command.
