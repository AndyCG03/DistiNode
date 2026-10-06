import type { User } from "@supabase/supabase-js";

export function displayName(user: Pick<User, "email" | "user_metadata">): string {
  const meta = user.user_metadata ?? {};
  const name = (meta.full_name || meta.name || "") as string;
  if (name.trim()) return name.trim();
  const local = (user.email ?? "").split("@")[0];
  return local ? local.charAt(0).toUpperCase() + local.slice(1) : "Invitado";
}

export function avatarUrl(user: Pick<User, "user_metadata">): string | undefined {
  const meta = user.user_metadata ?? {};
  return (meta.avatar_url || meta.picture || undefined) as string | undefined;
}

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  const first = parts[0]?.[0] ?? "?";
  const second = parts.length > 1 ? parts[parts.length - 1][0] : "";
  return (first + second).toUpperCase();
}
