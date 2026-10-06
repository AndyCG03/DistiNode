import "server-only";
import { withUser } from "@/lib/db";

export type RoomSummary = { id: string; code: string; name: string; role: "owner" | "member"; joinedAt: Date };

/** Todas las consultas pasan por withUser: RLS decide qué filas ve cada persona. */
export function listMyRooms(userId: string): Promise<RoomSummary[]> {
  return withUser(userId, async (db) => {
    const { rows } = await db.query(
      `select r.id, r.code, r.name, m.role, m.joined_at as "joinedAt"
         from room_members m join rooms r on r.id = m.room_id
        where m.user_id = $1
        order by m.joined_at desc`,
      [userId],
    );
    return rows;
  });
}

export function findRoomByCode(userId: string, code: string) {
  return withUser(userId, async (db) => {
    const { rows } = await db.query<{ id: string; code: string; name: string }>(
      "select id, code, name from rooms where code = $1",
      [code],
    );
    return rows[0] ?? null;
  });
}

export function isMember(userId: string, roomId: string) {
  return withUser(userId, async (db) => {
    const { rowCount } = await db.query("select 1 from room_members where room_id = $1 and user_id = $2", [
      roomId,
      userId,
    ]);
    return (rowCount ?? 0) > 0;
  });
}

export function createRoom(userId: string, name: string): Promise<string> {
  return withUser(userId, async (db) => (await db.query("select create_room($1) as code", [name])).rows[0].code);
}

export function joinRoom(userId: string, code: string): Promise<string | null> {
  return withUser(userId, async (db) => (await db.query("select join_room($1) as code", [code])).rows[0].code);
}
