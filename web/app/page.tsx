export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-neutral-950 text-neutral-100 px-6">
      <div className="max-w-2xl text-center">
        <h1 className="text-5xl font-bold tracking-tight">PostureGuard</h1>
        <p className="mt-4 text-lg text-neutral-400">
          Scan a domain, get a clear security posture report: TLS, HTTP headers
          and open ports, scored from 0 to 100 with an A to F grade.
        </p>
        <div className="mt-8 inline-flex items-center rounded-full border border-neutral-700 px-4 py-2 text-sm text-neutral-400">
          Phase 1 - live on Azure Container Apps
        </div>
      </div>
    </main>
  );
}
