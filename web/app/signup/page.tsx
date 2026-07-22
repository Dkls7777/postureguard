import { signupAction } from "@/app/actions/auth";

export default async function SignupPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <main className="flex min-h-screen items-center justify-center bg-neutral-950 text-neutral-100 px-6">
      <form
        action={signupAction}
        className="w-full max-w-sm space-y-4 rounded-xl border border-neutral-800 p-8"
      >
        <h1 className="text-2xl font-bold">Create your account</h1>
        {error === "exists" && (
          <p className="text-sm text-red-400">This email is already registered.</p>
        )}
        {error === "missing" && (
          <p className="text-sm text-red-400">
            Enter a valid email and a password of at least 8 characters.
          </p>
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
          minLength={8}
          placeholder="Password (min 8 chars)"
          className="w-full rounded-md bg-neutral-900 border border-neutral-700 px-3 py-2"
        />
        <button className="w-full rounded-md bg-neutral-100 text-neutral-900 py-2 font-medium">
          Sign up
        </button>
        <p className="text-sm text-neutral-400">
          Already have an account? <a href="/login" className="underline">Log in</a>
        </p>
      </form>
    </main>
  );
}
