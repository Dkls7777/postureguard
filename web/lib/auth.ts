import { cookies } from "next/headers";
import bcrypt from "bcryptjs";
import pool from "@/lib/db";

const SESSION_COOKIE = "pg_session";
const SESSION_DAYS = 7;

export async function hashPassword(password: string) {
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(password: string, hash: string) {
  return bcrypt.compare(password, hash);
}

export async function createSession(userId: string) {
  const expires = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
  const result = await pool.query(
    "INSERT INTO sessions (user_id, expires_at) VALUES ($1, $2) RETURNING id",
    [userId, expires]
  );
  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE, result.rows[0].id, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    expires,
    path: "/",
  });
}

export async function getCurrentUser() {
  const cookieStore = await cookies();
  const sessionId = cookieStore.get(SESSION_COOKIE)?.value;
  if (!sessionId) return null;
  const result = await pool.query(
    `SELECT u.id, u.email, u.org_id
     FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.id = $1 AND s.expires_at > now()`,
    [sessionId]
  );
  return result.rows[0] ?? null;
}

export async function destroySession() {
  const cookieStore = await cookies();
  const sessionId = cookieStore.get(SESSION_COOKIE)?.value;
  if (sessionId) {
    await pool.query("DELETE FROM sessions WHERE id = $1", [sessionId]);
    cookieStore.delete(SESSION_COOKIE);
  }
}
