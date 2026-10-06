/// PRNG con semilla (mulberry32): mismas entradas → mismos resultados.
/// Misma secuencia que `src/sim/rng.ts` (aritmética de 32 bits sin signo).
library;

typedef Rng = double Function();

const int _m32 = 0xFFFFFFFF;

int _imul(int a, int b) => ((a & _m32) * (b & _m32)) & _m32;

Rng createRng(int seed) {
  var a = seed & _m32;
  return () {
    a = (a + 0x6d2b79f5) & _m32;
    var t = a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & _m32)) & _m32;
    return ((t ^ (t >> 14)) & _m32) / 4294967296.0;
  };
}
