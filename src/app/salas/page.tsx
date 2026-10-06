import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { SetupNotice } from "@/components/SetupNotice";
import { SiteHeader } from "@/components/SiteHeader";
import { isAuthConfigured } from "@/lib/env";
import { UserMenu } from "@/components/UserMenu";
import { colorFor } from "@/lib/colors";
import { getUser } from "@/lib/auth";
import { listMyRooms } from "@/lib/rooms";
import { avatarUrl, displayName } from "@/lib/user";
import { CreateRoomForm, JoinRoomForm } from "./RoomForms";

export const metadata: Metadata = { title: "Mis salas" };

const dateFmt = new Intl.DateTimeFormat("es", { day: "numeric", month: "short" });

export default async function SalasPage() {
  if (!isAuthConfigured())
    return (
      <SetupNotice
        service="la base de datos (inicio de sesión)"
        vars={["DATABASE_URL", "BETTER_AUTH_SECRET", "BETTER_AUTH_URL", "SMTP_URL"]}
      />
    );
  const user = await getUser();
  if (!user) redirect("/entrar?next=/salas");
  const rooms = await listMyRooms(user.id);
  const name = displayName(user);

  return (
    <>
      <SiteHeader>
        <UserMenu name={name} avatar={avatarUrl(user)} color={colorFor(user.id)} />
      </SiteHeader>
      <main className="mx-auto w-full max-w-3xl flex-1 px-5 pt-8 pb-20">
        <h1 className="text-3xl font-bold tracking-tight">Mis salas</h1>
        <p className="mt-1 text-gris-texto">Cada sala es un lienzo compartido. Invita con su código.</p>

        <div className="mt-8 grid gap-6 md:grid-cols-2">
          <CreateRoomForm />
          <JoinRoomForm />
        </div>

        <section aria-labelledby="lista" className="mt-12">
          <h2 id="lista" className="sr-only">
            Salas
          </h2>
          {rooms.length === 0 ? (
            <div className="rounded-xl border-[1.5px] border-dashed border-linea px-6 py-10 text-center">
              <p className="font-semibold">Todavía no tienes salas</p>
              <p className="mt-1 text-gris-texto">
                Crea la primera arriba o pide a tu equipo el código de 6 caracteres.
              </p>
            </div>
          ) : (
            <ul className="relative">
              <span aria-hidden="true" className="absolute top-6 bottom-6 left-[13px] w-[6px] rounded-full bg-verde" />
              {rooms.map((room) => (
                <li key={room.id}>
                  <Link
                    href={`/sala/${room.code}`}
                    className="group relative flex items-center gap-4 rounded-xl py-3 pr-3 pl-0 hover:bg-papel"
                  >
                    <span
                      aria-hidden="true"
                      className="relative z-10 size-8 shrink-0 rounded-full border-[5px] border-tinta bg-papel group-hover:border-verde"
                    />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-semibold">{room.name}</span>
                      <span className="text-sm text-gris-texto">
                        {room.role === "owner" ? "Creada por ti" : "Te uniste"} · {dateFmt.format(room.joinedAt)}
                      </span>
                    </span>
                    <span className="cifras rounded-md bg-verde-suave px-2 py-1 text-sm font-semibold tracking-[0.15em] text-verde">
                      {room.code}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>
      </main>
    </>
  );
}
