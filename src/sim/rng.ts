/** PRNG con semilla (mulberry32): mismas entradas → mismos resultados. */
export type Rng = () => number;

export function createRng(seed: number): Rng {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Intervalo exponencial para llegadas de Poisson con tasa `rate` (por segundo). */
export function expInterval(rng: Rng, rate: number): number {
  return -Math.log(1 - rng()) / rate;
}
