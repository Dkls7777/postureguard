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

## Shell gotcha worth a paragraph

`set -euo pipefail` in a file meant to be **sourced** applies to the interactive shell
itself: any command returning a non-zero exit code closes the terminal. It cost me two
lost sessions before I spotted it. Strict mode belongs in executed scripts, never in a
sourced variables file.

## Azure CLI and Microsoft Graph

The CLI's Graph token carries a restricted set of scopes: reading
`identitySecurityDefaultsEnforcementPolicy` fails with `AccessDenied — required scopes
are missing in the token`, even as Global Administrator. Being Global Admin does not
mean the tool you are holding asked for the permission. Identity policy work goes
through the portal.

## The audit finding I did not expect

Listing my own role assignments showed a single principal holding `Owner` on the whole
subscription and `Global Administrator` on the directory — and the account name carried
the `#EXT#` marker, meaning the tenant's only administrator is an external identity
backed by a personal Gmail account. The security of the entire Azure environment rested
on the security of a consumer mailbox. That is the kind of finding an audit report opens
with, and I found it on my own tenant in the first ten minutes.

## The mistake I made while hardening my own accounts

While enabling two-step login on my password manager, I screenshotted the setup panel —
including the TOTP seed. Sharing it burned the secret and I had to rotate it immediately:
disable the provider, re-enable it, re-enrol the authenticator, regenerate the recovery
code. Nothing was breached, but the second factor was worthless until rotated.

The lesson is the distinction between an **identifier** and an **authentication secret**.
A subscription ID appearing in a screenshot is untidy. A TOTP seed appearing in a
screenshot is a compromise. Same reflex to build: know which category a value belongs to
before it reaches a screen capture.

## Least privilege, and testing it

Strong angle for the article: showing the `AuthorizationFailed` output is far more
convincing than describing a role assignment. Three commands, three proofs — denied
outside scope, denied when self-escalating, and a resource group listing that returns
exactly one row.

Also worth writing up: GUIDs were filtered out of the terminal output with a `sed`
function rather than blurred in the image afterwards. Redacting at the source is
repeatable; retouching a screenshot is not.

## Revising a recommendation mid-build

I planned to create a second Global Administrator to decouple the tenant from a consumer
account. After hardening the original account, that plan became a net negative: a
password-based admin next to a passwordless MFA-protected one. Changing the design was
the right call, and saying so in the article is more useful than pretending the first
plan was correct.
