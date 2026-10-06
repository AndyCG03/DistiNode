// Aplica db/migrations/*.sql en orden, una sola vez cada una. Uso: node scripts/migrate.mjs
// Necesita MIGRATION_DATABASE_URL (dueño de las tablas) o, si no, DATABASE_URL.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "db", "migrations");
const url = process.env.MIGRATION_DATABASE_URL || process.env.DATABASE_URL;
if (!url) {
  console.error("Falta MIGRATION_DATABASE_URL o DATABASE_URL");
  process.exit(1);
}

const client = new pg.Client({ connectionString: url });

// Postgres puede tardar unos segundos en aceptar conexiones al arrancar el contenedor.
for (let attempt = 1; ; attempt++) {
  try {
    await client.connect();
    break;
  } catch (e) {
    if (attempt >= 30) throw e;
    await new Promise((r) => setTimeout(r, 1000));
  }
}

await client.query(
  "create table if not exists schema_migrations (name text primary key, applied_at timestamptz not null default now())",
);
const { rows } = await client.query("select name from schema_migrations");
const done = new Set(rows.map((r) => r.name));
const files = (await readdir(dir)).filter((f) => f.endsWith(".sql")).sort();

for (const file of files) {
  if (done.has(file)) continue;
  const sql = await readFile(path.join(dir, file), "utf8");
  process.stdout.write(`→ ${file} … `);
  try {
    await client.query("begin");
    await client.query(sql);
    await client.query("insert into schema_migrations (name) values ($1)", [file]);
    await client.query("commit");
    console.log("ok");
  } catch (e) {
    await client.query("rollback");
    console.log("error");
    console.error(e);
    process.exit(1);
  }
}
console.log("Migraciones al día.");
await client.end();
