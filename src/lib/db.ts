import "server-only";
import { Pool, type PoolClient } from "pg";
import { databaseUrl } from "@/lib/env";

declare global {
  var __distinodePool: Pool | undefined;
}

/** Un único pool por proceso (también entre recargas en desarrollo). */
export function pool(): Pool {
  globalThis.__distinodePool ??= new Pool({ connectionString: databaseUrl(), max: 10 });
  return globalThis.__distinodePool;
}

/**
 * Ejecuta `fn` en una transacción con `app.user_id` fijado: las políticas RLS de rooms y room_members
 * leen ese valor. La app se conecta con un rol sin BYPASSRLS, así que la base de datos aplica los permisos.
 */
export async function withUser<T>(userId: string, fn: (db: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool().connect();
  try {
    await client.query("begin");
    await client.query("select set_config('app.user_id', $1, true)", [userId]);
    const result = await fn(client);
    await client.query("commit");
    return result;
  } catch (e) {
    await client.query("rollback").catch(() => {});
    throw e;
  } finally {
    client.release();
  }
}
