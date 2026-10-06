import { LogoMark } from "@/components/Logo";

export function EmptyState({
  onLoadExample,
  canLoad,
  canEdit,
}: {
  onLoadExample: () => void;
  canLoad: boolean;
  canEdit: boolean;
}) {
  return (
    <div className="pointer-events-none absolute inset-0 z-10 grid place-items-center p-6">
      <div className="pointer-events-auto flex max-w-sm flex-col items-center text-center">
        <LogoMark size={56} />
        <h2 className="mt-4 text-xl font-bold">Un lienzo en blanco</h2>
        {canLoad ? (
          <>
            <p className="mt-1 text-gris-texto">
              {canEdit
                ? "Arrastra un componente desde la izquierda, o empieza con un sistema mínimo y dale al ▶."
                : "Carga un sistema mínimo y dale al ▶. Para diseñar el tuyo, ábrelo en un ordenador."}
            </p>
            <button type="button" className="btn btn-primario mt-5" onClick={onLoadExample}>
              Cargar ejemplo
            </button>
          </>
        ) : (
          <p className="mt-1 text-gris-texto">
            Abre la sala en un ordenador para diseñar. Aquí verás lo que construya tu equipo.
          </p>
        )}
      </div>
    </div>
  );
}
