import { Liveblocks } from "@liveblocks/node";
import type { NextRequest } from "next/server";
import { colorFor } from "@/lib/colors";
import { liveblocksSecret } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import { avatarUrl, displayName } from "@/lib/user";

const ROOM_RE = /^distinode:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/;

let client: Liveblocks | null = null;
const liveblocks = () =>
  (client ??= new Liveblocks({ secret: liveblocksSecret(), baseUrl: process.env.LIVEBLOCKS_BASE_URL || undefined }));

/** Firma el acceso a una sala de Liveblocks solo si la persona es miembro (según Supabase + RLS). */
export async function POST(request: NextRequest) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return new Response("No has iniciado sesión", { status: 401 });

  const body = (await request.json().catch(() => null)) as { room?: unknown } | null;
  const match = typeof body?.room === "string" ? ROOM_RE.exec(body.room) : null;
  if (!match) return new Response("Sala no válida", { status: 400 });

  const { data: membership } = await supabase
    .from("room_members")
    .select("room_id")
    .eq("room_id", match[1])
    .eq("user_id", user.id)
    .maybeSingle();
  if (!membership) return new Response("No eres miembro de esta sala", { status: 403 });

  const session = liveblocks().prepareSession(user.id, {
    userInfo: { name: displayName(user), color: colorFor(user.id), avatar: avatarUrl(user) },
  });
  session.allow(body!.room as string, session.FULL_ACCESS);
  const { status, body: token } = await session.authorize();
  return new Response(token, { status });
}
