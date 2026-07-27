# Azure deployment scripts

The real asset of this project is the repository. The cloud is rented on demand:
these scripts exist so the whole environment can be destroyed between work sessions
and rebuilt in minutes, which is what makes it affordable to run on a time-limited
credit. They are also the draft of the Terraform configuration arriving in Phase 4: the resource names and tags here are the ones it will reuse.

| Script | Purpose |
|---|---|
| `00-variables.sh` | Shared names, region and tags. Sourced by every other script; never executed. |
| `10-provision.sh` | Build the entire environment from nothing. Idempotent, safe to re-run. |
| `20-start.sh` | Wake up for a session: start the database, refresh the workstation firewall rule, bring the worker back. |
| `30-stop.sh` | Pause everything billable between sessions. |
| `40-update-images.sh` | Build both images from the current commit, push, and roll out new revisions. |
| `90-destroy.sh` | Delete every resource. Requires typing the resource group name. |

## Typical session

```bash
./20-start.sh          # database up, worker running, your IP allowed
# ... work, commit ...
./40-update-images.sh  # ship the current commit
./30-stop.sh           # pause before leaving
```

## Notes worth knowing

**`00-variables.sh` carries no `set -euo pipefail`.** Strict mode in a *sourced* file
applies to the interactive shell, so any command returning a non-zero exit code closes
the terminal. Strict mode belongs in executed scripts only.

**The subscription ID is resolved at runtime**, never committed. It is an identifier
rather than a secret, but keeping environment identifiers out of the repository is the
habit worth having.

**`30-stop.sh` deactivates the worker's revision** instead of setting
`--min-replicas 0`. An app without ingress has no scale trigger, so the scale setting
alone leaves the replica running, verified with `az containerapp replica list`. A cost
control you have not verified is not a cost control.

**`20-start.sh` refreshes the workstation firewall rule** on every run, because a
residential IP address changes and a stale rule looks exactly like a broken database.

**`40-update-images.sh` refuses to deploy a dirty working tree.** Images are tagged with
the short git SHA; if local code differs from the commit, the tag is a lie and the
traceability is worthless.

**The custom domain is not scripted.** DNS records and certificate binding are done once
per environment; see step 9 of `docs/report/phase-1-azure.md`.

**Key Vault soft-delete reserves the vault name for seven days** after a group delete.
`90-destroy.sh` prints the `az keyvault purge` command needed to free it immediately.
Purge protection is deliberately disabled for this reason: in production it should be on,
since it prevents an attacker from permanently destroying secrets, but here it would
break the tear-down-and-rebuild cycle these scripts exist for.
