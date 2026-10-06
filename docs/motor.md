# El motor de simulación

Documentación técnica de `src/sim/`. Para la guía de uso, abre `/guia` en la app.

## Archivos

| Archivo | Qué contiene |
| --- | --- |
| `components.ts` | Registro de los 9 componentes: parámetros, valores por defecto, textos de ayuda y documentación (la guía de la app se genera desde aquí). |
| `engine.ts` | La clase `Engine`: paso fijo, colas, enrutado, fallos y métricas. |
| `templates.ts` | Plantillas de sistemas como datos puros (rejilla columna/fila). |
| `types.ts` | Tipos públicos: grafo, trenes, estadísticas, métricas. |
| `rng.ts` | PRNG con semilla (mulberry32). |
| `*.test.ts` | Pruebas con Vitest (`npm test`). |

## API

```ts
const e = new Engine({ seed: 1, dt: 0.01 });
e.setGraph({ nodes, edges });   // se puede llamar en cualquier momento; conserva el estado de lo que sigue
e.setTraffic(80);               // pet/s totales, repartidas entre los clientes
e.advance(segundosReales);      // pasos fijos con acumulador (máximo 0,25 s por llamada)
e.trains();                     // mensajes en tránsito con su progreso 0..1 (para dibujar)
e.nodeStats(id);                // llegadas, rechazos, cola, carga, estado, sobrecarga sostenida
e.metrics();                    // completadas/s, latencia media y p95, errores, reintentos, segundo plano
```

El motor no sabe nada de React, del DOM ni de Liveblocks. La interfaz (`src/features/canvas/simRuntime.ts`)
lo alimenta con el diagrama compartido y lo avanza en cada fotograma.

## Modelo

### Dos relojes

- **Tiempo de pared** (`now`): lo que tarda un tren en recorrer una línea (`travelTime`, ~0,3 s). Es cámara
  lenta para que el tráfico se vea.
- **Tiempo simulado** (`Request.sim`): espera en colas + proceso + latencia de red (1 ms por salto + la latencia
  añadida de la línea). Es lo que miden las métricas y lo que agota los tiempos de espera de los clientes.

### Peticiones

Una petición guarda su camino (`path`): la lista de saltos que ha dado. La respuesta deshace ese camino.
Hay tres tipos:

| Tipo | Nace en | Termina cuando vuelve a… |
| --- | --- | --- |
| `client` | un Cliente | el cliente: éxito o error, con reintentos |
| `child` | un Servidor en modo «a todos» (fan-out) | el servidor, que espera a todos sus hijos |
| `async` | una Cola de mensajes | la cola: si falló, se reentrega |

Un cliente agrupa sus intentos en una petición lógica (`Logical`). Si un intento falla (rechazo, nodo caído,
línea cortada) o supera el tiempo de espera, reintenta con espera exponencial (100 ms × 2ⁿ con ±20 %) hasta
agotar los reintentos. El intento abandonado sigue su camino y consume capacidad: así aparecen las tormentas
de reintentos.

### Componentes

| Componente | Comportamiento |
| --- | --- |
| Cliente | Emite a ritmo regular con variación (intervalo × U[0,5; 1,5]). |
| CDN, Caché | Acierto con probabilidad `hitRate`: responde. Fallo: reenvía (round-robin). |
| API Gateway | Cubo de fichas de `rateLimit` por segundo. Sin ficha: rechazo inmediato. |
| Balanceador | Chequeo de salud cada `healthCheckMs` (nodo encendido y línea sin cortar). Round-robin o menos conexiones (peticiones enviadas sin respuesta). |
| Servidor, Worker, Base de datos | `workers = round(capacidad × proceso)` trabajadores; cada trabajo dura `workers / capacidad` (×4 si está degradado). Cola FIFO de `queueMax`; llena, rechaza. Tras procesar llama a un destino (o a todos en modo fan-out). |
| Cola de mensajes | Guarda el mensaje y confirma al momento. Entrega a cada consumidor hasta `trabajadores + cola local + capacidad × viaje` mensajes sin procesar (el hueco se libera cuando el consumidor termina). Si el consumidor falla, el mensaje vuelve al principio de la cola. Si la cola cae, conserva sus mensajes. |

Un trabajador que termina toma el siguiente de la cola **en el instante exacto** en que acabó, no al final del
paso de 10 ms; si no, la discretización le robaría hasta un paso por trabajo a la capacidad.

### Estados

`nodeStats().status` (lo que pinta el borde de la estación):

- `down`: caído.
- `idle`: sin tráfico.
- `hot` (rojo): rechazando, cola por encima del 50 %, o carga ≥ 100 %.
- `warn` (ámbar): cola por encima del 15 %, carga ≥ 80 %, o degradado.
- `ok` (verde).

`overloadFor` cuenta los segundos seguidos rechazando o con la cola por encima del 80 %. Lo usa el supervisor.

## Fallos compartidos: el supervisor

El motor es determinista y local: cada navegador simula por su cuenta. Las caídas automáticas no pueden decidirse
en cada navegador (serían distintas), así que las decide uno solo, el **líder** (la conexión con el id más bajo de
la sala, o el propio navegador en la demo), en `src/features/canvas/Supervisor.tsx`:

1. Revive lo que tenga `downUntil` / `slowUntil` vencido.
2. Con «Sobrecarga tumba», cae lo que lleve 5 s con `overloadFor` y lo reinicia a los `restartSec` segundos.
3. Con «Caos», cada segundo hay un 15 % de probabilidad de un evento: caída (55 %), degradación (25 %) o corte de
   una línea (20 %), con como mucho dos caídas de caos a la vez.

Los cambios se escriben en el estado compartido (Liveblocks o la demo local) y todos los motores los reciben como
un grafo nuevo.

## Añadir un componente

1. Añade su `kind` a `ComponentKind` y su entrada en `COMPONENTS` (parámetros, valores por defecto, `docs`).
2. Añade su comportamiento en `Engine.process()` (y, si hace cola, en `hasCapacity`).
3. Añade su icono en `src/features/canvas/icons.tsx` y su resumen en `StationNode.tsx`.
4. Escribe una prueba en `engine.test.ts`.

La barra lateral, el panel de propiedades y la guía lo recogen solos.
