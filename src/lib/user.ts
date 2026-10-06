export type AppUser = { id: string; email: string; name?: string | null; image?: string | null };

export function displayName(user: Pick<AppUser, "email" | "name">): string {
  const name = (user.name ?? "").trim();
  if (name) return name;
  const local = (user.email ?? "").split("@")[0];
  return local ? local.charAt(0).toUpperCase() + local.slice(1) : "Invitado";
}

export function avatarUrl(user: Pick<AppUser, "image">): string | undefined {
  return user.image || undefined;
}

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  const first = parts[0]?.[0] ?? "?";
  const second = parts.length > 1 ? parts[parts.length - 1][0] : "";
  return (first + second).toUpperCase();
}
