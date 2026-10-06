import type { Metadata } from "next";
import Link from "next/link";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { SetupNotice } from "@/components/SetupNotice";
import { SiteHeader } from "@/components/SiteHeader";
import { getUser } from "@/lib/auth";
import { isAuthConfigured, isLiveblocksConfigured, liveblocksPublicUrl } from "@/lib/env";
import { findRoomByCode } from "@/lib/rooms";
import { JoinRoomForm } from "@/app/salas/RoomForms";
import { Room } from "@/features/canvas/Room";
import { isValidCode, normalizeCode } from "@/lib/room-code";

export async function generateMetadata(props: PageProps<"/sala/[codigo]">): Promise<Metadata> {
  const { codigo } = await props.params;
  return { title: `Sala ${normalizeCode(codigo)}` };
}

export default async function SalaPage(props: PageProps<"/sala/[codigo]">) {
  const { codigo } = await props.params;
  const code = normalizeCode(codigo);
  if (!isAuthConfigured())
    return (
      <SetupNotice
        service="la base de datos (inicio de sesión)"
        vars={["DATABASE_URL", "BETTER_AUTH_SECRET", "BETTER_AUTH_URL", "SMTP_URL"]}
      />
    );
  if (!isLiveblocksConfigured())
    return <SetupNotice service="Liveblocks (tiempo real)" vars={["LIVEBLOCKS_SECRET_KEY"]} />;
  const user = await getUser();
  if (!user) redirect(`/entrar?next=/sala/${code}`);

  // RLS: solo devuelve la sala si soy miembro.
  const room = isValidCode(code) ? await findRoomByCode(user.id, code) : null;

  if (!room) {
    return (
      <>
        <SiteHeader />
        <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center px-5 pb-24">
          <h1 className="text-2xl font-bold tracking-tight">Aún no estás en esta sala</h1>
          <p className="mt-2 mb-6 text-gris-texto">
            Si te pasaron el código <span className="cifras font-semibold text-tinta">{code}</span>, únete y entrarás al
            lienzo.
          </p>
          <JoinRoomForm defaultCode={code} />
          <Link href="/salas" className="mt-6 text-sm font-semibold text-verde underline-offset-4 hover:underline">
            Volver a mis salas
          </Link>
        </main>
      </>
    );
  }

  // El navegador habla con Liveblocks en el mismo origen (Caddy) o en la URL configurada.
  const h = await headers();
  const origin = `${h.get("x-forwarded-proto") ?? "http"}://${h.get("x-forwarded-host") ?? h.get("host")}`;
  return <Room room={room} baseUrl={liveblocksPublicUrl(origin)} />;
}
