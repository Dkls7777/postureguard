import os
import time
import socket
import ssl

import urllib.request
import psycopg
from dotenv import load_dotenv

# Load DATABASE_URL from the project root .env
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
DATABASE_URL = os.environ["DATABASE_URL"]

POLL_INTERVAL = 3
COMMON_PORTS = [21, 22, 23, 25, 80, 110, 143, 443, 3306, 3389, 5432, 8080]
RISKY_PORTS = {21: "FTP", 23: "Telnet", 3306: "MySQL", 3389: "RDP", 5432: "PostgreSQL"}

SECURITY_HEADERS = {
    "strict-transport-security": ("Missing HSTS header", "high"),
    "content-security-policy": ("Missing Content-Security-Policy", "medium"),
    "x-content-type-options": ("Missing X-Content-Type-Options", "low"),
    "x-frame-options": ("Missing X-Frame-Options", "low"),
    "referrer-policy": ("Missing Referrer-Policy", "low"),
}

SEV_PENALTY = {"critical": 40, "high": 20, "medium": 10, "low": 4, "info": 0}


def scan_tls(host):
    findings = []
    ctx = ssl.create_default_context()
    try:
        with socket.create_connection((host, 443), timeout=6) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                version = ssock.version()
                cert = ssock.getpeercert()
        exp = ssl.cert_time_to_seconds(cert["notAfter"])
        days_left = int((exp - time.time()) / 86400)
        if days_left < 0:
            findings.append(("tls", "critical", "TLS certificate expired", f"Expired {abs(days_left)} days ago"))
        elif days_left < 15:
            findings.append(("tls", "high", "TLS certificate expiring soon", f"{days_left} days left"))
        else:
            findings.append(("tls", "info", "Valid TLS certificate", f"{days_left} days left"))
        if version in ("TLSv1", "TLSv1.1"):
            findings.append(("tls", "high", "Outdated TLS version", f"Server negotiated {version}"))
        else:
            findings.append(("tls", "info", "Modern TLS version", f"Server negotiated {version}"))
    except Exception as e:
        findings.append(("tls", "high", "TLS connection failed", str(e)))
    return findings


def scan_headers(host):
    findings = []
    try:
        req = urllib.request.Request(f"https://{host}", headers={"User-Agent": "PostureGuard/0.1"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            headers = {k.lower(): v for k, v in resp.headers.items()}
        for h, (title, sev) in SECURITY_HEADERS.items():
            if h in headers:
                findings.append(("headers", "info", f"{h} present", headers[h][:120]))
            else:
                findings.append(("headers", sev, title, "Header not set"))
    except Exception as e:
        findings.append(("headers", "medium", "Could not fetch headers", str(e)))
    return findings


def scan_ports(host):
    findings = []
    open_ports = []
    for port in COMMON_PORTS:
        try:
            with socket.create_connection((host, port), timeout=2):
                open_ports.append(port)
        except Exception:
            pass
    for p in open_ports:
        if p in RISKY_PORTS:
            findings.append(("ports", "medium", f"Sensitive port open: {p} ({RISKY_PORTS[p]})", "Exposed to the internet"))
        else:
            findings.append(("ports", "info", f"Port {p} open", ""))
    if not open_ports:
        findings.append(("ports", "info", "No common ports open", ""))
    return findings


def score_findings(findings):
    score = 100
    for _cat, sev, _t, _d in findings:
        score -= SEV_PENALTY.get(sev, 0)
    score = max(0, min(100, score))
    if score >= 90:
        grade = "A"
    elif score >= 75:
        grade = "B"
    elif score >= 60:
        grade = "C"
    elif score >= 40:
        grade = "D"
    else:
        grade = "F"
    return score, grade


def process_one(conn):
    # Claim one queued job using SKIP LOCKED so multiple workers never collide
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT s.id, d.name
            FROM scans s JOIN domains d ON d.id = s.domain_id
            WHERE s.status = 'queued'
            ORDER BY s.requested_at
            FOR UPDATE OF s SKIP LOCKED
            LIMIT 1
            """
        )
        row = cur.fetchone()
        if row is None:
            conn.rollback()
            return False
        scan_id, host = row
        cur.execute("UPDATE scans SET status='running', started_at=now() WHERE id=%s", (scan_id,))
    conn.commit()

    print(f"Scanning {host} (scan {scan_id})")
    try:
        findings = scan_tls(host) + scan_headers(host) + scan_ports(host)
        score, grade = score_findings(findings)
        with conn.cursor() as cur:
            for cat, sev, title, detail in findings:
                cur.execute(
                    "INSERT INTO findings (scan_id, category, severity, title, detail) VALUES (%s,%s,%s,%s,%s)",
                    (scan_id, cat, sev, title, detail),
                )
            cur.execute(
                "UPDATE scans SET status='done', score=%s, grade=%s, finished_at=now() WHERE id=%s",
                (score, grade, scan_id),
            )
        conn.commit()
        print(f"Done {host}: {score}/100 ({grade}), {len(findings)} findings")
    except Exception as e:
        conn.rollback()
        with conn.cursor() as cur:
            cur.execute("UPDATE scans SET status='error', error=%s, finished_at=now() WHERE id=%s", (str(e), scan_id))
        conn.commit()
        print(f"Error {host}: {e}")
    return True


def main():
    print("PostureGuard worker started. Polling for jobs...")
    with psycopg.connect(DATABASE_URL) as conn:
        while True:
            if not process_one(conn):
                time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
