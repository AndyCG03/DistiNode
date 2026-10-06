import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "@/components/SiteHeader";
import { JoinRoomForm } from "@/app/salas/RoomForms";
import { Room } from "@/features/canvas/Room";
import { isValidCode, normalizeCode } from "@/lib/room-code";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(props: PageProps<"/sala/[codigo]">): Promise<Metadata> {
  const { codigo } = await props.params;
  return { title: `Sala ${normalizeCode(codigo)}` };
}

export default async function SalaPage(props: PageProps<"/sala/[codigo]">) {
  const { codigo } = await props.params;
  const code = normalizeCode(codigo);
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?next=/sala/${code}`);

  // RLS: solo devuelve la sala si soy miembro.
  const { data: room } = isValidCode(code)
    ? await supabase.from("rooms").select("id, code, name").eq("code", code).maybeSingle()
    : { data: null };

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

  return <Room room={room} />;
}
