import { notFound, redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/auth";
import pool from "@/lib/db";
import AutoRefresh from "./AutoRefresh";

const sevColor: Record<string, string> = {
  critical: "text-red-400",
  high: "text-orange-400",
  medium: "text-yellow-400",
  low: "text-blue-400",
  info: "text-neutral-400",
};

export default async function ScanPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const user = await getCurrentUser();
  if (!user) redirect("/login");
  const { id } = await params;

  const scanRes = await pool.query(
    `SELECT s.id, s.status, s.score, s.grade, s.error, d.name AS domain
     FROM scans s JOIN domains d ON d.id = s.domain_id
     WHERE s.id = $1 AND d.org_id = $2`,
    [id, user.org_id]
  );
  const scan = scanRes.rows[0];
  if (!scan) notFound();

  const findingsRes = await pool.query(
    `SELECT category, severity, title, detail FROM findings
     WHERE scan_id = $1
     ORDER BY array_position(ARRAY['critical','high','medium','low','info'], severity)`,
    [id]
  );
  const findings = findingsRes.rows;
  const pending = scan.status === "queued" || scan.status === "running";

  return (
    <main className="min-h-screen bg-neutral-950 text-neutral-100 px-6 py-10">
      {pending && <AutoRefresh />}
      <div className="mx-auto max-w-3xl">
        <a href="/dashboard" className="text-sm text-neutral-400 underline">
          Back to dashboard
        </a>
        <h1 className="mt-4 text-2xl font-bold">Scan report: {scan.domain}</h1>

        <div className="mt-4 flex items-center gap-4">
          <span className="rounded-full border border-neutral-700 px-3 py-1 text-sm">
            Status: {scan.status}
          </span>
          {scan.status === "done" && (
            <span className="text-lg font-semibold">
              Score: {scan.score}/100 (grade {scan.grade})
            </span>
          )}
        </div>

        {pending && (
          <p className="mt-6 text-neutral-400">
            Scan in progress. This page refreshes automatically.
          </p>
        )}

        {scan.status === "error" && (
          <p className="mt-6 text-red-400">Scan error: {scan.error}</p>
        )}

        {scan.status === "done" && (
          <section className="mt-8">
            <h2 className="text-lg font-semibold">Findings</h2>
            {findings.length === 0 && (
              <p className="mt-2 text-neutral-500">No issues found.</p>
            )}
            <ul className="mt-4 space-y-3">
              {findings.map((f, i) => (
                <li key={i} className="rounded-lg border border-neutral-800 p-4">
                  <div className="flex items-center justify-between">
                    <span className="font-medium">{f.title}</span>
                    <span className={`text-xs uppercase ${sevColor[f.severity] ?? ""}`}>
                      {f.severity} / {f.category}
                    </span>
                  </div>
                  {f.detail && (
                    <p className="mt-1 text-sm text-neutral-400">{f.detail}</p>
                  )}
                </li>
              ))}
            </ul>
          </section>
        )}
      </div>
    </main>
  );
}
