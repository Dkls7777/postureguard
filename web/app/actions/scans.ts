"use server";

import { redirect } from "next/navigation";
import pool from "@/lib/db";
import { getCurrentUser } from "@/lib/auth";

export async function scanDomainAction(formData: FormData) {
  const user = await getCurrentUser();
  if (!user) redirect("/login");

  const domainId = String(formData.get("domainId") || "");
  const res = await pool.query(
    "SELECT id, verified FROM domains WHERE id = $1 AND org_id = $2",
    [domainId, user.org_id]
  );
  const domain = res.rows[0];
  if (!domain) redirect("/dashboard");
  if (!domain.verified) redirect("/dashboard?error=not_verified");

  const scan = await pool.query(
    "INSERT INTO scans (domain_id) VALUES ($1) RETURNING id",
    [domainId]
  );
  redirect(`/scans/${scan.rows[0].id}`);
}
