"use server";

import { redirect } from "next/navigation";
import { getUser } from "@/lib/auth";
import { isValidCode, normalizeCode } from "@/lib/room-code";
import { createRoom as dbCreateRoom, joinRoom as dbJoinRoom } from "@/lib/rooms";

export type FormState = { error?: string };

export async function createRoom(_prev: FormState, formData: FormData): Promise<FormState> {
  const user = await getUser();
  if (!user) redirect("/entrar?next=/salas");
  const name = String(formData.get("name") ?? "")
    .trim()
    .slice(0, 60);
  let code: string;
  try {
    code = await dbCreateRoom(user.id, name || "Sala sin nombre");
  } catch {
    return { error: "No pudimos crear la sala. Inténtalo de nuevo." };
  }
  redirect(`/sala/${code}`);
}

export async function joinRoom(_prev: FormState, formData: FormData): Promise<FormState> {
  const user = await getUser();
  if (!user) redirect("/entrar?next=/salas");
  const code = normalizeCode(String(formData.get("code") ?? ""));
  if (!isValidCode(code)) {
    return { error: "El código tiene 6 caracteres, por ejemplo K7Q2MX." };
  }
  let joined: string | null;
  try {
    joined = await dbJoinRoom(user.id, code);
  } catch {
    return { error: "No pudimos unirte. Inténtalo de nuevo." };
  }
  if (!joined) return { error: "No hay ninguna sala con ese código." };
  redirect(`/sala/${joined}`);
}
