# Building a security posture scanner with Next.js and Python

I wanted to learn cloud security the way it actually sticks: by building something real. So I built PostureGuard, a web application that scans a domain and returns a security posture report covering TLS, HTTP security headers and open ports, with a 0-100 score and an A-F grade. This post walks through the architecture and the decisions I found most interesting.

## The shape of the system

PostureGuard has three moving parts:

- A Next.js web app (App Router, TypeScript) where users sign up, add a domain, and request scans.
- A PostgreSQL database that stores users, domains and scans.
- A Python worker that runs the actual scans in the background.

The web app never runs a scan itself. When a user clicks "Scan", the app just inserts a row into a `scans` table with the status `queued` and returns immediately. The worker picks the job up a moment later. This keeps the request fast and the two halves of the system decoupled.

## Using PostgreSQL as a job queue

The part I like most is that there is no separate message broker. The `scans` table doubles as the queue. The worker claims one job at a time with a single query:

    SELECT s.id, d.name
    FROM scans s JOIN domains d ON d.id = s.domain_id
    WHERE s.status = 'queued'
    ORDER BY s.requested_at
    FOR UPDATE OF s SKIP LOCKED
    LIMIT 1

`FOR UPDATE` locks the row so no one else can grab it, and `SKIP LOCKED` tells other workers to ignore locked rows and move on to the next job. That means I can run several workers in parallel and they will never process the same scan twice, without any extra infrastructure. For a project at this scale, a table plus `SKIP LOCKED` is simpler and more than enough.

## The scanners

The worker runs three checks, all built on the Python standard library to keep dependencies light:

- TLS: it opens a TLS connection, reads the certificate expiry and the negotiated protocol version, and flags expired certs or outdated TLS.
- HTTP headers: it fetches the site and checks for the security headers that matter (HSTS, Content-Security-Policy, X-Content-Type-Options, X-Frame-Options, Referrer-Policy).
- Ports: it attempts TCP connections to a list of common ports and flags sensitive ones like Telnet, RDP or an exposed database.

Each check returns findings tagged with a severity. The score starts at 100 and loses points per finding based on severity, then maps to a grade. Because the scoring is pure logic with no I/O, I pulled it into its own module and covered it with unit tests.

## Only scan what you own

A domain scanner is one `if` statement away from being an attack tool, so ownership matters. Before a domain can be scanned, the user has to prove they control it by adding a DNS TXT record containing a unique token I generate for them. The verification step does a live DNS lookup and only marks the domain verified if the token is present. Since only the domain owner can edit DNS records, this is a clean proof of control.

## Authentication done simply

Auth is email and password. Passwords are hashed with bcrypt and only the hash is stored. Sessions live server-side in the database; the browser only holds an opaque session id in an httpOnly cookie, so it is not reachable from JavaScript. Nothing fancy, but the fundamentals are right.

## Running it like production

To get a feel for operations, I did not just run the worker in a terminal. I turned it into a systemd service so it starts on boot and restarts if it crashes, with its logs captured by journald. A bash script dumps and compresses the database, keeps the last seven backups, and a systemd timer runs it every night. After a full machine restart, the worker came back on its own and the backup fired overnight without me touching anything.

One small gotcha worth noting: under systemd, Python buffers stdout, so my log lines never reached journald until I forced unbuffered output. A classic first surprise when you move a script into a service.

## What is next

This is Phase 0, the local MVP. From here the plan is to deploy it to Azure, then AWS, refactor the infrastructure to Terraform, run it on Kubernetes, wrap it in a DevSecOps pipeline, and wire it into a SOC with Microsoft Sentinel. Each step adds a layer, and each layer is a chance to learn a piece of cloud security by building instead of just reading about it.

The code is on GitHub. If you are learning cloud security too, I would recommend the same approach: pick one project and take it deep.
