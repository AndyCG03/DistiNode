import { HexAvatar } from "@/components/HexAvatar";

export function UserMenu({ name, avatar, color }: { name: string; avatar?: string; color: string }) {
  return (
    <div className="flex items-center gap-2">
      <HexAvatar name={name} color={color} avatar={avatar} size={30} />
      <span className="hidden text-sm font-semibold sm:inline">{name}</span>
      <form action="/auth/salir" method="post">
        <button
          type="submit"
          className="rounded-full px-3 py-1.5 text-sm text-gris-texto hover:bg-verde-suave hover:text-tinta"
        >
          Salir
        </button>
      </form>
    </div>
  );
}
