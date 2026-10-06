"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isValidCode, normalizeCode } from "@/lib/room-code";

export type FormState = { error?: string };

export async function createRoom(_prev: FormState, formData: FormData): Promise<FormState> {
  const name = String(formData.get("name") ?? "").trim().slice(0, 60);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("create_room", { p_name: name || "Sala sin nombre" });
  if (error || typeof data !== "string") {
    return { error: "No pudimos crear la sala. Inténtalo de nuevo." };
  }
  redirect(`/sala/${data}`);
}

export async function joinRoom(_prev: FormState, formData: FormData): Promise<FormState> {
  const code = normalizeCode(String(formData.get("code") ?? ""));
  if (!isValidCode(code)) {
    return { error: "El código tiene 6 caracteres, por ejemplo K7Q2MX." };
  }
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("join_room", { p_code: code });
  if (error) return { error: "No pudimos unirte. Inténtalo de nuevo." };
  if (!data) return { error: "No hay ninguna sala con ese código." };
  redirect(`/sala/${data}`);
}
