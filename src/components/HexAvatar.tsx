import { initials } from "@/lib/user";

const HEX = "polygon(50% 0, 93.3% 25%, 93.3% 75%, 50% 100%, 6.7% 75%, 6.7% 25%)";

/** Avatar hexagonal: foto si la hay, iniciales sobre el color de la persona si no. */
export function HexAvatar({
  name,
  color,
  avatar,
  size = 32,
  title,
}: {
  name: string;
  color: string;
  avatar?: string;
  size?: number;
  title?: string;
}) {
  return (
    <span
      title={title ?? name}
      className="relative inline-grid shrink-0 place-items-center"
      style={{ width: size, height: size, clipPath: HEX, background: color }}
    >
      {avatar ? (
        // eslint-disable-next-line @next/next/no-img-element -- avatares externos de Google, tamaño fijo
        <img
          src={avatar}
          alt=""
          referrerPolicy="no-referrer"
          className="absolute inset-[2px] size-[calc(100%-4px)] object-cover"
          style={{ clipPath: HEX }}
        />
      ) : (
        <span className="text-[0.68rem] leading-none font-bold text-white" style={{ fontSize: size * 0.34 }}>
          {initials(name)}
        </span>
      )}
      <span className="sr-only">{name}</span>
    </span>
  );
}
