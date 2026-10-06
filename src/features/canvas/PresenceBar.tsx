"use client";

import { useMe, usePeople } from "@/features/collab/context";
import { HexAvatar } from "@/components/HexAvatar";

const MAX = 5;

export function PresenceBar() {
  const me = useMe();
  const others = usePeople();
  const shown = others.slice(0, MAX);
  const extra = others.length - shown.length;

  return (
    <div className="flex items-center" aria-label={`${others.length + 1} en la sala`}>
      <ul className="flex -space-x-1.5">
        {shown.map((info) => (
          <li key={info.key}>
            <HexAvatar name={info.name} color={info.color} avatar={info.avatar} size={30} />
          </li>
        ))}
        {extra > 0 && (
          <li className="grid size-[30px] place-items-center text-xs font-semibold text-gris-texto">+{extra}</li>
        )}
        <li>
          <HexAvatar name={me.name} color={me.color} avatar={me.avatar} size={30} title={`${me.name} (tú)`} />
        </li>
      </ul>
    </div>
  );
}
