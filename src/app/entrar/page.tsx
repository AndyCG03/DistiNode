import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { SetupNotice } from "@/components/SetupNotice";
import { SiteHeader } from "@/components/SiteHeader";
import { getUser } from "@/lib/auth";
import { isAuthConfigured, isGoogleConfigured } from "@/lib/env";
import { safeNext } from "@/lib/safe-next";
import { LoginForm } from "./LoginForm";

export const metadata: Metadata = { title: "Entrar" };

export default async function EntrarPage(props: PageProps<"/entrar">) {
  const params = await props.searchParams;
  const next = safeNext(typeof params.next === "string" ? params.next : null);
  const error = typeof params.error === "string" ? params.error : null;

  if (!isAuthConfigured())
    return (
      <SetupNotice
        service="la base de datos (inicio de sesión)"
        vars={["DATABASE_URL", "BETTER_AUTH_SECRET", "BETTER_AUTH_URL", "SMTP_URL"]}
      />
    );
  if (await getUser().catch(() => null)) redirect(next);

  return (
    <>
      <SiteHeader />
      <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center px-5 pb-24">
        <h1 className="text-3xl font-bold tracking-tight">Entra a DistiNode</h1>
        <p className="mt-2 text-gris-texto">Te enviamos un enlace al correo. Sin contraseñas.</p>
        {error && (
          <p role="alert" className="mt-5 rounded-lg border border-rojo/40 px-3 py-2 text-sm text-rojo">
            No pudimos completar el inicio de sesión. Prueba de nuevo.
          </p>
        )}
        <LoginForm next={next} google={isGoogleConfigured()} />
      </main>
    </>
  );
}
