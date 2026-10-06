/**
 * Colores de persona (cursores, avatares, borde de selección).
 * Evitan el verde, ámbar y rojo de estado para no confundirse con la salud de un nodo.
 */
export const PERSON_COLORS = [
  "#2F6FB0", // azul
  "#7B4FA6", // violeta
  "#B0457A", // magenta
  "#0E7C86", // petróleo
  "#4F5BD5", // índigo
  "#8B5E34", // tierra
  "#3E6E8E", // pizarra
  "#A0527D", // ciruela
] as const;

export function colorFor(id: string): string {
  let h = 2166136261;
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return PERSON_COLORS[(h >>> 0) % PERSON_COLORS.length];
}
