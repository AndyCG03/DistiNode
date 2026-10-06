import { toNextJsHandler } from "better-auth/next-js";
import type { NextRequest } from "next/server";
import { getAuth } from "@/lib/auth";
import { isAuthConfigured } from "@/lib/env";

const unavailable = () => new Response("Autenticación no configurada", { status: 503 });

export async function GET(request: NextRequest) {
  return isAuthConfigured() ? toNextJsHandler(getAuth()).GET(request) : unavailable();
}

export async function POST(request: NextRequest) {
  return isAuthConfigured() ? toNextJsHandler(getAuth()).POST(request) : unavailable();
}
