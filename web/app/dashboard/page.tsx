import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/auth";
import { logoutAction } from "@/app/actions/auth";
import { addDomainAction, verifyDomainAction } from "@/app/actions/domains";
import { scanDomainAction } from "@/app/actions/scans";
import pool from "@/lib/db";

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ [k: string]: string | undefined }>;
}) {
  const user = await getCurrentUser();
  if (!user) redirect("/login");
  const sp = await searchParams;

  const domainsRes = await pool.query(
    "SELECT id, name, verified, verification_token FROM domains WHERE org_id = $1 ORDER BY created_at DESC",
    [user.org_id]
  );
  const domains = domainsRes.rows;

  return (
    <main className="min-h-screen bg-neutral-950 text-neutral-100 px-6 py-10">
      <div className="mx-auto max-w-3xl">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold">Dashboard</h1>
          <form action={logoutAction}>
            <button className="rounded-md border border-neutral-700 px-3 py-1.5 text-sm">
              Log out
            </button>
          </form>
        </div>
        <p className="mt-2 text-sm text-neutral-400">Signed in as {user.email}</p>

        <section className="mt-8">
          <h2 className="text-lg font-semibold">Add a domain</h2>
          <form action={addDomainAction} className="mt-3 flex gap-2">
            <input
              name="domain"
              type="text"
              required
              placeholder="example.com"
              className="flex-1 rounded-md bg-neutral-900 border border-neutral-700 px-3 py-2"
            />
            <button className="rounded-md bg-neutral-100 text-neutral-900 px-4 py-2 font-medium">
              Add
            </button>
          </form>
          {sp.error === "invalid_domain" && (
            <p className="mt-2 text-sm text-red-400">Please enter a valid domain (e.g. example.com).</p>
          )}
          {sp.error === "domain_exists" && (
            <p className="mt-2 text-sm text-red-400">You already added this domain.</p>
          )}
          {sp.error === "not_verified" && (
            <p className="mt-2 text-sm text-red-400">Verify the domain before scanning.</p>
          )}
          {sp.verified === "1" && (
            <p className="mt-2 text-sm text-green-400">Domain verified successfully.</p>
          )}
          {sp.verify_failed === "1" && (
            <p className="mt-2 text-sm text-red-400">
              Verification failed. Make sure the TXT record is set, then try again.
            </p>
          )}
        </section>

        <section className="mt-10">
          <h2 className="text-lg font-semibold">Your domains</h2>
          {domains.length === 0 && (
            <p className="mt-2 text-sm text-neutral-500">No domains yet.</p>
          )}
          <ul className="mt-4 space-y-4">
            {domains.map((d) => (
              <li key={d.id} className="rounded-lg border border-neutral-800 p-4">
                <div className="flex items-center justify-between">
                  <span className="font-medium">{d.name}</span>
                  {d.verified ? (
                    <span className="rounded-full bg-green-900/40 text-green-400 px-3 py-1 text-xs">
                      Verified
                    </span>
                  ) : (
                    <span className="rounded-full bg-yellow-900/40 text-yellow-400 px-3 py-1 text-xs">
                      Pending
                    </span>
                  )}
                </div>

                {d.verified ? (
                  <form action={scanDomainAction} className="mt-4">
                    <input type="hidden" name="domainId" value={d.id} />
                    <button className="rounded-md bg-neutral-100 text-neutral-900 px-4 py-1.5 text-sm font-medium">
                      Scan now
                    </button>
                  </form>
                ) : (
                  <div className="mt-4 text-sm text-neutral-400">
                    <p>Add this DNS TXT record, then click Verify:</p>
                    <div className="mt-2 rounded-md bg-neutral-900 border border-neutral-800 p-3 font-mono text-xs break-all">
                      <div>Name: _postureguard.{d.name}</div>
                      <div>Type: TXT</div>
                      <div>Value: postureguard-site-verification={d.verification_token}</div>
                    </div>
                    <form action={verifyDomainAction} className="mt-3">
                      <input type="hidden" name="domainId" value={d.id} />
                      <button className="rounded-md border border-neutral-700 px-3 py-1.5 text-sm">
                        Verify
                      </button>
                    </form>
                  </div>
                )}
              </li>
            ))}
          </ul>
        </section>
      </div>
    </main>
  );
}
