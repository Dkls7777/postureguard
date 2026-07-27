import Link from "next/link";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-neutral-950 text-neutral-100 px-6">
      <div className="max-w-2xl text-center">
        <h1 className="text-5xl font-bold tracking-tight">PostureGuard</h1>
        <p className="mt-4 text-lg text-neutral-400">
          Scan a domain, get a clear security posture report: TLS, HTTP headers
          and open ports, scored from 0 to 100 with an A to F grade.
        </p>

        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <Link
            href="/signup"
            className="rounded-full bg-neutral-100 px-6 py-3 text-sm font-medium text-neutral-950 transition hover:bg-white"
          >
            Create an account
          </Link>
          <Link
            href="/login"
            className="rounded-full border border-neutral-700 px-6 py-3 text-sm font-medium text-neutral-300 transition hover:border-neutral-500 hover:text-neutral-100"
          >
            Log in
          </Link>
        </div>

        <p className="mt-6 text-sm text-neutral-500">
          Ownership is verified with a DNS TXT record before a domain can be
          scanned.
        </p>

        <div className="mt-12 inline-flex items-center rounded-full border border-neutral-800 px-4 py-2 text-xs text-neutral-500">
          Phase 1 - live on Azure Container Apps
        </div>
      </div>
    </main>
  );
}
