import { Pool } from "pg";

// A single connection pool reused across the app.
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export default pool;
