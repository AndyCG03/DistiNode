import { Liveblocks } from "@liveblocks/node";
import type { NextRequest } from "next/server";
import { colorFor } from "@/lib/colors";
import { getUser } from "@/lib/auth";
import { isAuthConfigured, isLiveblocksConfigured, liveblocksSecret, liveblocksServerUrl } from "@/lib/env";
import { isMember } from "@/lib/rooms";
import { avatarUrl, displayName } from "@/lib/user";

const ROOM_RE = /^distinode:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/;

let client: Liveblocks | null = null;
const liveblocks = () => (client ??= new Liveblocks({ secret: liveblocksSecret(), baseUrl: liveblocksServerUrl() }));

/** Firma el acceso a una sala de Liveblocks solo si la persona es miembro (según Postgres + RLS). */
export async function POST(request: NextRequest) {
  if (!isAuthConfigured() || !isLiveblocksConfigured()) {
    return new Response("Faltan la base de datos o Liveblocks en este despliegue", { status: 503 });
  }
  const user = await getUser();
  if (!user) return new Response("No has iniciado sesión", { status: 401 });

  const body = (await request.json().catch(() => null)) as { room?: unknown } | null;
  const match = typeof body?.room === "string" ? ROOM_RE.exec(body.room) : null;
  if (!match) return new Response("Sala no válida", { status: 400 });

  if (!(await isMember(user.id, match[1]))) return new Response("No eres miembro de esta sala", { status: 403 });

  const session = liveblocks().prepareSession(user.id, {
    userInfo: { name: displayName(user), color: colorFor(user.id), avatar: avatarUrl(user) },
  });
  session.allow(body!.room as string, session.FULL_ACCESS);
  const { status, body: token } = await session.authorize();
  return new Response(token, { status });
}
