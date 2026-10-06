import "server-only";
import { betterAuth } from "better-auth";
import { nextCookies } from "better-auth/next-js";
import { magicLink } from "better-auth/plugins/magic-link";
import { headers } from "next/headers";
import { pool } from "@/lib/db";
import { isAuthConfigured, isGoogleConfigured } from "@/lib/env";
import { sendMagicLinkEmail } from "@/lib/mail";
import type { AppUser } from "@/lib/user";

function createAuth() {
  return betterAuth({
    appName: "DistiNode",
    database: pool(),
    secret: process.env.BETTER_AUTH_SECRET,
    baseURL: process.env.BETTER_AUTH_URL,
    trustedOrigins: process.env.BETTER_AUTH_URL ? [process.env.BETTER_AUTH_URL] : undefined,
    socialProviders: isGoogleConfigured()
      ? { google: { clientId: process.env.GOOGLE_CLIENT_ID!, clientSecret: process.env.GOOGLE_CLIENT_SECRET! } }
      : {},
    session: { expiresIn: 60 * 60 * 24 * 30 },
    plugins: [
      magicLink({
        expiresIn: 60 * 15,
        sendMagicLink: ({ email, url }) => sendMagicLinkEmail(email, url),
      }),
      nextCookies(),
    ],
  });
}

let instance: ReturnType<typeof createAuth> | null = null;

/** Perezoso: así `next build` no necesita base de datos. */
export function getAuth() {
  instance ??= createAuth();
  return instance;
}

export async function getUser(): Promise<AppUser | null> {
  if (!isAuthConfigured()) return null;
  const session = await getAuth().api.getSession({ headers: await headers() });
  return session?.user ?? null;
}
