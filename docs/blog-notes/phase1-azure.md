# Blog notes — Phase 1: Deploying a Next.js + Python app on Azure Container Apps

Running notes for the Phase 1 article. Raw material, not prose.

## Angles worth keeping

- **Convention before creation.** Writing the naming and tagging convention before the
  first `az group create` is what makes the Terraform migration in Phase 4 a port
  rather than a rewrite.
- **Tags as a cost control.** `phase` and `project` tags let Cost Management answer
  "what did this roadmap phase actually cost me" — worth a screenshot at the end of the
  phase.
- **Redaction is not enough.** A reviewer flagged a subscription ID visible in a
  screenshot. Blurring the image would have been theatre: the same value was
  hard-coded in a committed shell script. The real fix was resolving it at runtime with
  `az account show --query id`. Point for the article: secrets hygiene is about where
  values live, not about what is visible in a picture.
- **One resource group on purpose.** Usually an anti-pattern; here it is a deliberate
  trade-off driven by a 30-day credit. Explain the reasoning rather than presenting it
  as best practice.

## Gotchas encountered

- Azure CLI Debian package targets `jammy`; installs fine on much newer Ubuntu.
- `az login --use-device-code` is the reliable path under WSL.
- The `containerapp` CLI extension only ships as a preview version — expected, not a
  problem.
- `az consumption budget list` returns nothing useful on a trial subscription; the
  budget is visible in the portal.
