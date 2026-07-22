import { loginAction } from "@/app/actions/auth";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <main className="flex min-h-screen items-center justify-center bg-neutral-950 text-neutral-100 px-6">
      <form
        action={loginAction}
        className="w-full max-w-sm space-y-4 rounded-xl border border-neutral-800 p-8"
      >
        <h1 className="text-2xl font-bold">Log in</h1>
        {error === "invalid" && (
          <p className="text-sm text-red-400">Invalid email or password.</p>
        )}
        <input
          name="email"
          type="email"
          required
          placeholder="Email"
          className="w-full rounded-md bg-neutral-900 border border-neutral-700 px-3 py-2"
        />
        <input
          name="password"
          type="password"
          required
          placeholder="Password"
          className="w-full rounded-md bg-neutral-900 border border-neutral-700 px-3 py-2"
        />
        <button className="w-full rounded-md bg-neutral-100 text-neutral-900 py-2 font-medium">
          Log in
        </button>
        <p className="text-sm text-neutral-400">
          No account yet? <a href="/signup" className="underline">Sign up</a>
        </p>
      </form>
    </main>
  );
}
