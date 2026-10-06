import { LogoMark } from "@/components/Logo";

export function EmptyState({ onLoadExample, readOnly }: { onLoadExample: () => void; readOnly: boolean }) {
  return (
    <div className="pointer-events-none absolute inset-0 z-10 grid place-items-center p-6">
      <div className="pointer-events-auto flex max-w-sm flex-col items-center text-center">
        <LogoMark size={44} />
        <h2 className="mt-4 text-xl font-bold">Un lienzo en blanco</h2>
        {readOnly ? (
          <p className="mt-1 text-gris-texto">Abre la sala en un ordenador para diseñar. Aquí verás lo que construya tu equipo.</p>
        ) : (
          <>
            <p className="mt-1 text-gris-texto">
              Arrastra un componente desde la izquierda, o empieza con un sistema mínimo y dale al ▶.
            </p>
            <button type="button" className="btn btn-primario mt-5" onClick={onLoadExample}>
              Cargar ejemplo
            </button>
          </>
        )}
      </div>
    </div>
  );
}
