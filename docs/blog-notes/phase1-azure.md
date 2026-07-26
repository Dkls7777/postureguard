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

## Rotating the placeholder password

`POSTGRES_PASSWORD` in a Docker Compose file is only read when the volume is first
initialised. Editing the file changes nothing on an existing database — the rotation has
to go through `ALTER USER` inside the running container, then the connection strings in
`.env` and `web/.env.local`, then a restart of both the container and the systemd worker.
A classic trap that quietly leaves the old credential valid if you only edit the file.

Two things nearly made me declare victory too early. Grepping for the placeholder turned
up matches in the Turbopack build cache — harmless, since the string was never a real
secret, but the lesson generalises: build artefacts retain values, so purging source and
config is not the same as purging a secret. And my first health check passed against a
dev server started before the rotation: PostgreSQL does not drop existing sessions when a
password changes, so a stale process kept serving requests on the old credential and made
the verification look green. Killing it and restarting was the only honest test.

## Candidate for a separate article: what npm audit actually tells you

Containerising the web app surfaced 12 high-severity npm advisories. Rather than running
`npm audit fix` and moving on, I worked out which of them actually ship. The numbers below
are the article.

**The build tree is not the artefact.** `npm ci` installs 386 packages. The runtime image
contains 24. The multi-stage build leaves 94% of the dependency tree behind in the builder
stage, and I verified that by inspecting the image rather than trusting the theory:

    eslint  : absent from runtime image
    postcss : absent from runtime image
    sharp   : PRESENT in runtime image

Nine of the twelve advisories sat in the `brace-expansion → minimatch → eslint →
eslint-config-next` chain, a devDependency, plus `postcss`, which runs at build time. None
reach production. That is not a reason to ignore them — a compromised build tool is a
supply-chain problem — but it changes the priority entirely.

**The automated fix was worse than the vulnerability.** `npm audit fix --force` proposed
installing `next@9.3.3`, a release from 2020, because no patched version existed in the
advisory's range. npm reports the newest unaffected version, which on a fast-moving
framework can mean a six-year downgrade. Accepting it would have destroyed the app to
silence a warning.

**Fixing a pinned transitive dependency took three attempts.** `sharp 0.34.5` was the only
package genuinely present at runtime, used by Next.js for image optimisation, carrying four
libvips CVEs.

1. `npm install sharp@latest` installed 0.35.3 at the top level — and relocated the
   vulnerable copy to `node_modules/next/node_modules/sharp`. Node resolves to the nearest
   `node_modules`, so Next.js would still have loaded 0.34.5. The audit report changed; the
   runtime behaviour did not.
2. `"overrides": { "sharp": "^0.35.0" }` failed with `EOVERRIDE`: npm refuses an override
   that contradicts a direct dependency.
3. `"overrides": { "sharp": "$sharp" }` is the documented syntax for exactly this case — it
   aligns every transitive resolution with the direct dependency. That worked.

Verified in the artefact, not in the report:

    node_modules/sharp                    -> 0.35.3
    node_modules/next/node_modules/sharp  -> absent

**Where it landed.** 11 advisories remain, every one confined to the build stage, proven by
inspecting what ships. Zero known vulnerabilities in the deployed image — a sentence that is
defensible because it was measured.

**The security fix also shrank the image.** Before the override, the image carried two
copies of `sharp`: the patched one at the top level and the vulnerable one pinned underneath
Next.js. Deduplicating to a single patched version took the web image from 305 MB to 270 MB.
Removing a vulnerability removed 35 MB of duplicate native binaries with it. Security and
image hygiene are usually the same work.

**The reflex worth naming.** Scan the artefact, not the lockfile. `npm audit` describes your
development tree; an attacker interacts with the image you deployed. Two different
inventories, and only one of them is in production.

## A small networking lesson while testing the images

My first container test pointed the connection string at `host.docker.internal` and timed
out. The database is not on the host — it is another container. Attaching the test
containers to the same Docker network and addressing PostgreSQL by its service name worked
immediately. Worth keeping because it is the same model Container Apps uses: services
resolve each other by name, the image never changes, only the environment variable does.
