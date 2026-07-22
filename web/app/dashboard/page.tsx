import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/auth";
import { logoutAction } from "@/app/actions/auth";

export default async function DashboardPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login");

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
        <p className="mt-4 text-neutral-400">Signed in as {user.email}</p>
        <p className="mt-8 text-neutral-500">
          Domain submission and scanning will appear here (next steps).
        </p>
      </div>
    </main>
  );
}
