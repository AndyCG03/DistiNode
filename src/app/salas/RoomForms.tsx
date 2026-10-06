"use client";

import { useActionState } from "react";
import { createRoom, joinRoom, type FormState } from "./actions";

const initial: FormState = {};

export function CreateRoomForm() {
  const [state, action, pending] = useActionState(createRoom, initial);
  return (
    <form action={action} className="flex flex-col gap-2">
      <label htmlFor="room-name" className="font-semibold">
        Nueva sala
      </label>
      <div className="flex gap-2">
        <input id="room-name" name="name" maxLength={60} placeholder="Práctica 3 — Caché" className="campo" />
        <button type="submit" className="btn btn-primario" disabled={pending}>
          {pending ? "Creando…" : "Crear"}
        </button>
      </div>
      {state.error && (
        <p role="alert" className="text-sm text-rojo">
          {state.error}
        </p>
      )}
    </form>
  );
}

export function JoinRoomForm({ defaultCode = "" }: { defaultCode?: string }) {
  const [state, action, pending] = useActionState(joinRoom, initial);
  return (
    <form action={action} className="flex flex-col gap-2">
      <label htmlFor="room-code" className="font-semibold">
        Unirme con un código
      </label>
      <div className="flex gap-2">
        <input
          id="room-code"
          name="code"
          defaultValue={defaultCode}
          required
          maxLength={8}
          autoComplete="off"
          autoCapitalize="characters"
          spellCheck={false}
          placeholder="K7Q2MX"
          className="campo cifras font-semibold tracking-[0.2em] uppercase"
        />
        <button type="submit" className="btn btn-borde" disabled={pending}>
          {pending ? "Entrando…" : "Unirme"}
        </button>
      </div>
      {state.error && (
        <p role="alert" className="text-sm text-rojo">
          {state.error}
        </p>
      )}
    </form>
  );
}
