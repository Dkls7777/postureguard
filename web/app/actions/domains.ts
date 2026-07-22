"use server";

import { redirect } from "next/navigation";
import { randomBytes } from "crypto";
import { promises as dns } from "dns";
import { revalidatePath } from "next/cache";
import pool from "@/lib/db";
import { getCurrentUser } from "@/lib/auth";

function normalizeDomain(input: string) {
  return input
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/\/.*$/, "");
}

const DOMAIN_RE = /^(?=.{1,253}$)([a-z0-9-]{1,63}\.)+[a-z]{2,}$/;

export async function addDomainAction(formData: FormData) {
  const user = await getCurrentUser();
  if (!user) redirect("/login");

  const name = normalizeDomain(String(formData.get("domain") || ""));
  if (!DOMAIN_RE.test(name)) redirect("/dashboard?error=invalid_domain");

  const token = randomBytes(16).toString("hex");
  try {
    await pool.query(
      "INSERT INTO domains (org_id, name, verification_token) VALUES ($1, $2, $3)",
      [user.org_id, name, token]
    );
  } catch (e: unknown) {
    if ((e as { code?: string }).code === "23505") {
      redirect("/dashboard?error=domain_exists");
    }
    throw e;
  }

  revalidatePath("/dashboard");
  redirect("/dashboard");
}

export async function verifyDomainAction(formData: FormData) {
  const user = await getCurrentUser();
  if (!user) redirect("/login");

  const domainId = String(formData.get("domainId") || "");
  const res = await pool.query(
    "SELECT id, name, verification_token FROM domains WHERE id = $1 AND org_id = $2",
    [domainId, user.org_id]
  );
  const domain = res.rows[0];
  if (!domain) redirect("/dashboard");

  const expected = `postureguard-site-verification=${domain.verification_token}`;
  let verified = false;
  try {
    const records = await dns.resolveTxt(`_postureguard.${domain.name}`);
    verified = records.some((chunks) => chunks.join("").trim() === expected);
  } catch {
    verified = false;
  }

  if (verified) {
    await pool.query(
      "UPDATE domains SET verified = true, verified_at = now() WHERE id = $1",
      [domain.id]
    );
    revalidatePath("/dashboard");
    redirect("/dashboard?verified=1");
  }

  redirect("/dashboard?verify_failed=1");
}
