# Deploying a Next.js and Python app on Azure Container Apps

Phase 0 left PostureGuard running on my laptop. Phase 1 was about putting it on Azure properly: a public HTTPS endpoint on my own domain, a managed database, no secrets sitting anywhere they should not be, and a bill I could keep under control. It took two evenings. This post covers the parts that turned out to be more interesting than the documentation suggested.

## I audited my own tenant before deploying anything

Before creating a single resource, I listed my own permissions. One principal held `Owner` on the whole subscription and `Global Administrator` on the directory, with no separation between authority over resources and authority over identities. The account name also ended in `#EXT#`, which means the only administrator of my tenant was an external identity backed by a personal consumer account.

Entra ID security defaults were already enabled, so multifactor authentication was enforced across the tenant. Then I checked the owning account itself: two-step verification was off, and its only verification methods routed back to the same mailbox the account was tied to. The tenant looked protected while its sole administrator was not. A green checkmark in a portal tells you a policy exists, not that it covers the account that matters.

The fix took ten minutes: an authenticator app as an independent second factor, two-step verification on, and a recovery code written on paper. Not a cloud setting in sight.

## Least privilege only counts if you test it

Building everything as subscription `Owner` is convenient and wrong, so I created a dedicated working account holding exactly one role assignment: `Contributor` scoped to a single resource group. Two deliberate choices there. The scope is the resource group rather than the subscription, so the account cannot see or touch anything else. And the role is Contributor rather than Owner, so it can create and delete resources but cannot grant permissions.

Then I tried to break it. From that account, creating a resource group outside the scope returns `AuthorizationFailed`. Assigning itself `Owner` also returns `AuthorizationFailed`, because granting roles is a separate permission it does not hold. Listing resource groups returns exactly one row. The second denial is the one that matters, because it is what stops a compromised working account from escalating.

Showing that output is more convincing than describing a role assignment, and it took three commands.

## Two images, and what actually ships

Both components build with multi-stage Dockerfiles and run as unprivileged users. The web image uses Next.js standalone output, which brings it to 270 MB instead of roughly 1.2 GB.

The interesting number is elsewhere. `npm ci` installs 386 packages. The runtime image contains 24. It also reported twelve high-severity advisories, so instead of running `npm audit fix` I checked which of them actually reach production:

    eslint  : absent from runtime image
    postcss : absent from runtime image
    sharp   : PRESENT in runtime image

Nine of the twelve sat in the eslint dependency chain or in postcss, both of which stay behind in the build stage. That is not a reason to ignore them, since a compromised build tool is a supply-chain problem, but it changes the priority completely.

The automated fix would have been worse than the vulnerability. `npm audit fix --force` proposed installing `next@9.3.3`, a release from 2020, because no patched version existed inside the advisory range. npm reports the newest unaffected version, which on a fast-moving framework can mean a six-year downgrade.

The one package genuinely shipped was `sharp 0.34.5`, used by Next.js for image optimisation and carrying four libvips CVEs. Installing `sharp@latest` looked like it worked and did not: it put a patched copy at the top level and relocated the vulnerable one to `node_modules/next/node_modules/sharp`, where Node's resolution order would still have preferred it. The audit report changed, the runtime behaviour did not. The real fix was the npm `overrides` mechanism, and the syntax for a package that is also a direct dependency is `"sharp": "$sharp"`. Verified by inspecting the image afterwards, not by re-reading the report.

Deduplicating those native binaries also took the image from 305 MB to 270 MB. Removing a vulnerability removed 35 MB of duplication with it.

The habit worth keeping: scan the artefact, not the lockfile. `npm audit` describes your development tree. An attacker interacts with the image you deployed.

## Secrets that are referenced, not copied

There is no password anywhere in this deployment. The applications authenticate with a user-assigned managed identity, which has no credential at all: Azure issues short-lived tokens on demand. It holds `AcrPull`, so it can fetch images but not publish them, and `Key Vault Secrets User`, so it can read secrets but not create or modify them.

The database connection string lives in Key Vault and is injected as a reference rather than a value. `az containerapp show` returns `secretRef: database-url` and nothing else, so an account able to read the application definition still cannot read the database password. Rotating the secret in the vault propagates with a restart, without touching the deployment.

One thing surprised me: being subscription `Owner` does not let you read a vault's contents. Azure separates the management plane (creating and configuring the vault) from the data plane (reading and writing secrets), and Owner only grants the first. That is real protection rather than paperwork, because a compromised administrative account does not automatically read your secrets.

## The network assumption I got wrong

I allowed the Container Apps environment's `staticIp` through the PostgreSQL firewall, deployed, and got a connection timeout. That address is the inbound IP. Outbound traffic on a consumption environment leaves from a shared pool, and `outboundIpAddresses` returned around 180 addresses that change over time. PostgreSQL Flexible Server accepts 256 firewall rules, so allow-listing by IP is not tedious here, it is unworkable.

Three options existed. Private VNet integration is the right posture, but private access cannot be enabled after creation on Flexible Server, so it would have meant deleting and recreating the server, rebuilding the environment inside a delegated subnet, and reloading the schema. A NAT Gateway would give one stable egress IP and a single rule, at around 30 euros a month against a 175 euro credit. I took the third: the `AllowAzureServices` rule, which is Azure's convention of a `0.0.0.0` start and end address and means reachable from Azure resources, not reachable from the internet.

Being precise about the cost of that choice: the attack surface widens from one address to the Azure range, including resources in other tenants. What it does not do is weaken authentication, which is a 32-character random password from Key Vault over enforced TLS. The residual risk is bounded, it is written down, and closing it properly is the first item of Phase 2.

## Turning on the logs found a bug I had shipped in Phase 0

I set up a Log Analytics workspace expecting it to be housekeeping. The first KQL query returned `psycopg.errors.ConnectionTimeout` from the worker, repeating after I had stopped the database for the night. The worker opens a single connection at startup and the process exits if it fails, so the platform restarts it and it fails again.

Locally, systemd had been restarting it in exactly the same way for the whole of Phase 0. The defect was never visible because the recovery mechanism hid it.

The aggregate query was better still:

    ContainerAppConsoleLogs_CL
    | where TimeGenerated > ago(24h)
    | summarize events = count() by ContainerAppName_s
    | order by events desc

178 events from a silent background worker against 42 from the web app serving public traffic. No log reading required; the asymmetry is the finding. That is closer to detection work than to debugging, and the language is the same KQL that Microsoft Sentinel uses, which is where this workspace is heading in Phase 3.

The same step taught me a second thing. Setting `--min-replicas 0` did not stop the worker, because an app without ingress has no scale trigger. `az containerapp replica list` showed it still running and still crashing. Deactivating the revision is the actual off switch. A cost control you have not verified is not a cost control.

## Renting the cloud instead of owning it

The credit behind this phase expires after 30 days, which turned cost discipline into a design constraint rather than an afterthought. Two apps left running would consume far beyond the monthly free grant of 180,000 vCPU-seconds and cost around 40 euros a month, so the web app scales to zero and bills only on traffic, at the price of a cold start of a few seconds.

Everything else is scripted: provision, start, stop, deploy, destroy. The environment is meant to be torn down between sessions and rebuilt in about twenty minutes. The real asset is the repository, and the cloud is rented on demand. Those scripts are also the draft of the Terraform configuration coming in Phase 4, using the same names and tags, so that migration should be a port rather than a rewrite.

The deploy script refuses to run on a dirty working tree. Images are tagged with the short git SHA, never `latest`, so if local code differs from the commit then the tag is a lie and the traceability is worthless. Container Apps keeps the previous revision active at zero traffic weight, which makes a rollback one command against a known image.

One small gotcha worth noting, in the same family as the systemd buffering surprise from Phase 0: `az login --use-device-code` is what every WSL tutorial recommends, and it stopped working on day two. Since 1 July 2026, newly created Entra tenants block device code flow by default under security defaults, because the flow is heavily abused in phishing. Interactive browser login is the path now, which under WSL means a small helper script so the CLI can hand the URL to the Windows browser.

## Scanning my own deployment

The honest way to verify a deployment is to use it. I created an account on the live instance, proved ownership of my domain with a DNS TXT record, and queued a scan from the browser. The worker in France Central picked it up, ran the three scanners and wrote the findings in about one second. The queue-as-database design from Phase 0 works unchanged on Container Apps.

Then the tool turned on me twice.

Scanning the apex `samdossou.com` returned `No address associated with hostname`, and the scanner was right: the apex has no A, AAAA or CNAME record, so the bare domain reaches nothing. I had bound a certificate and verified HTTPS without ever noticing that the domain I had bought led nowhere.

It also exposed a flaw in my own scoring. A domain that does not resolve at all scores 70 out of 100, grade C, because the scanner applies the TLS and headers penalties as though it had measured something weak when in fact it measured nothing. A domain that cannot be evaluated and a domain that is merely imperfect should not share a grade band.

Scanning the deployed application gave the result that matters: `app.samdossou.com` scores 58 out of 100, grade D. TLS 1.3 with a valid certificate, and five missing security headers with HSTS as the single high finding.

I am keeping the D. Adding those headers is fifteen lines and the deployment pipeline is already in place, but a documented before and after is worth more than an A obtained quietly. Phase 2 will close it.

## What is next

Phase 2 is production hardening: the security headers, moving the database onto a private network, and two more scanners for cookies and CORS. After that, Sentinel and a SOC, then Terraform, then Kubernetes.

The pattern I would recommend to anyone learning cloud security this way: deploy something you built, then point your own tool at it. Reading about missing security headers is abstract. Watching your own scanner grade your own production deployment a D is not.

The code is on GitHub, and the build report for this phase records every step, including the two decisions I reversed halfway through.
