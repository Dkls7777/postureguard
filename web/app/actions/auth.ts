"use server";

import { redirect } from "next/navigation";
import pool from "@/lib/db";
import {
  hashPassword,
  verifyPassword,
  createSession,
  destroySession,
} from "@/lib/auth";

export async function signupAction(formData: FormData) {
  const email = String(formData.get("email") || "").trim().toLowerCase();
  const password = String(formData.get("password") || "");
  if (!email || password.length < 8) redirect("/signup?error=missing");

  const existing = await pool.query("SELECT id FROM users WHERE email = $1", [email]);
  if (existing.rows.length > 0) redirect("/signup?error=exists");

  const passwordHash = await hashPassword(password);

  const client = await pool.connect();
  let userId: string;
  try {
    await client.query("BEGIN");
    const org = await client.query(
      "INSERT INTO organizations (name) VALUES ($1) RETURNING id",
      [email]
    );
    const user = await client.query(
      "INSERT INTO users (org_id, email, password_hash) VALUES ($1, $2, $3) RETURNING id",
      [org.rows[0].id, email, passwordHash]
    );
    await client.query("COMMIT");
    userId = user.rows[0].id;
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }

  await createSession(userId);
  redirect("/dashboard");
}

export async function loginAction(formData: FormData) {
  const email = String(formData.get("email") || "").trim().toLowerCase();
  const password = String(formData.get("password") || "");

  const result = await pool.query(
    "SELECT id, password_hash FROM users WHERE email = $1",
    [email]
  );
  const user = result.rows[0];
  if (!user || !(await verifyPassword(password, user.password_hash))) {
    redirect("/login?error=invalid");
  }

  await createSession(user.id);
  redirect("/dashboard");
}

export async function logoutAction() {
  await destroySession();
  redirect("/login");
}
