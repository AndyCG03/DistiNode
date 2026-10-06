# DistiNode — plan de la v1

App web educativa para diseñar sistemas distribuidos en equipo y verlos funcionar en vivo.
Identidad visual: la de la CUJAE (verde institucional, gris del cubo isométrico, blanco y el hexágono). Nombre: **DistiNode**..

## 1. Stack y decisiones

| Pieza | Elección | Por qué |
| --- | --- | --- |
| Framework | Next.js 16 (App Router) + TypeScript | Pedido. En Next 16 el antiguo `middleware.ts` se llama `proxy.ts`. |
| Estilos | Tailwind CSS 4 + variables CSS | Tokens del sistema de diseño como variables; claro/oscuro sin duplicar clases. |
| Lienzo | `@xyflow/react` (React Flow 12) | Arrastre, zoom, conexiones y selección resueltos. Nodos y aristas propios. |
| Tiempo real | Liveblocks (`@liveblocks/react`, `@liveblocks/node`) | Presencia + almacenamiento CRDT (LiveMap/LiveObject) sin servidor de WebSockets propio. Guarda solo. |
| Auth y salas | Supabase (Auth + Postgres con RLS) | Enlace mágico y Google; tabla de salas con políticas por miembro. |
| Pruebas | Vitest | Motor de simulación en TS puro, probado sin DOM. |
| Despliegue | Vercel | Cero configuración para Next. |

No uso `@liveblocks/react-flow`: necesito control fino sobre el registro de cada nodo (parámetros, nodo caído)
y sobre el borde de selección por usuario, y el mapeo LiveMap ⇄ React Flow es corto.

## 2. Estructura de carpetas

```
docs/plan.md                    este documento
supabase/migrations/0001_init.sql   tablas, RLS y funciones (create_room, join_room)
src/
  proxy.ts                      refresca la sesión de Supabase y protege /salas y /sala
  app/
    layout.tsx                  fuente, tema, metadatos
    page.tsx                    portada
    entrar/page.tsx             enlace mágico + Google
    auth/callback/route.ts      canjea el código / token del correo
    auth/salir/route.ts         cierra sesión
    salas/page.tsx              "Mis salas": crear y unirse por código
    salas/actions.ts            server actions (create_room, join_room)
    sala/[codigo]/page.tsx      comprueba membresía y monta el lienzo
    api/liveblocks-auth/route.ts  token de Liveblocks solo para miembros
  components/                   UI genérica (Logo, Button, ThemeToggle, Avatar…)
  features/
    canvas/                     lienzo colaborativo (React Flow + Liveblocks)
      Room.tsx                  RoomProvider + almacenamiento inicial
      Canvas.tsx                orquestador del lienzo
      StationNode.tsx           nodo "estación"
      MetroEdge.tsx             arista "línea de metro" (45°/90°)
      Palette.tsx               barra lateral de componentes
      PropertiesPanel.tsx       panel de propiedades
      Cursors.tsx, Toasts.tsx, PresenceBar.tsx
      TrafficLayer.tsx          <canvas> con los trenes (60 fps)
      SimControls.tsx, MetricsBar.tsx
      useDiagram.ts             lectura/mutaciones del almacenamiento
      useSimulation.ts          ejecuta el motor local en requestAnimationFrame
      geometry.ts               trazado metro compartido por aristas y trenes
    (futuro) lessons/, missions/, chaos/, chat/, gallery/
  lib/
    supabase/{client,server,proxy}.ts
    liveblocks.config.ts        tipos globales de Presence/Storage/Events
    colors.ts                   color estable por usuario
    room-code.ts                formato y validación del código
  sim/                          MOTOR — TypeScript puro, sin React ni DOM
    types.ts                    grafo, mensajes, métricas
    rng.ts                      PRNG con semilla (mulberry32)
    components.ts               registro de componentes (parámetros por defecto, rótulos)
    engine.ts                   paso fijo, colas, round-robin, chequeo de salud
    engine.test.ts              pruebas Vitest
```

El registro `sim/components.ts` es la única fuente de verdad sobre qué componentes existen: la barra lateral,
el panel de propiedades y el motor leen de ahí. Añadir un componente nuevo (p. ej. "Cola de mensajes") =
una entrada en el registro + su comportamiento en el motor. Las lecciones y misiones serán "escenarios":
un grafo inicial + objetivos evaluados sobre `engine.getMetrics()`; por eso el motor es determinista
(semilla) y ejecutable sin interfaz.

## 3. Modelo de datos

### Supabase (Postgres)

```
rooms
  id          uuid pk default gen_random_uuid()
  code        text unique, 6 caracteres de [A-HJ-NP-Z2-9] (sin 0/O/1/I)
  name        text (1–60)
  owner_id    uuid → auth.users
  created_at  timestamptz

room_members
  room_id     uuid → rooms (on delete cascade)
  user_id     uuid → auth.users (on delete cascade)
  role        text 'owner' | 'member'
  joined_at   timestamptz
  pk (room_id, user_id)
```

RLS activada en ambas:
- `rooms` SELECT: solo si existe fila en `room_members` para `auth.uid()`. UPDATE/DELETE: solo el dueño.
- `room_members` SELECT: solo tus propias filas. DELETE: puedes salir (tus filas). Sin INSERT directo.
- Crear y unirse pasan por funciones `security definer` (`create_room(name)`, `join_room(code)`) que
  validan, generan el código único y escriben la membresía de forma atómica.

### Liveblocks (estado compartido de la sala `distinode:<room.id>`)

```ts
Storage {
  nodes: LiveMap<id, LiveObject<{ id, kind, label, x, y, params, down }>>
  edges: LiveMap<id, LiveObject<{ id, source, target }>>
  sim:   LiveObject<{ running: boolean, traffic: number }>   // 1–200 pet/s
}
Presence { cursor: {x,y} | null  (coordenadas del lienzo), selected: string[] }
UserMeta { id, info: { name, color, avatar? } }        // lo firma /api/liveblocks-auth
RoomEvent { type: 'notice', text }                     // "Ana tumbó Servidor 2"
```

Cada campo es un registro independiente en el CRDT: dos personas moviendo nodos distintos o editando
propiedades distintas nunca chocan; en el mismo campo gana la última escritura. El diagrama persiste en
Liveblocks: recargar = recuperar el estado.

### Motor de simulación (local en cada navegador)

- Paso fijo `dt = 10 ms` con acumulador; PRNG con semilla → mismas entradas, mismos resultados.
- Entradas: grafo (nodos con parámetros y `down`, aristas con `travelTime`), tráfico total en pet/s.
- Cada **mensaje** viaja por una arista (petición hacia delante, respuesta de vuelta por la misma ruta).
- **Servidor / Base de datos**: `capacidad` (pet/s) y `tiempo de proceso`; trabajadores = capacidad × tiempo.
  Cola FIFO limitada; con la cola llena la petición falla. La latencia crece con la espera.
  Estado: verde (ρ < 0,7), ámbar (ρ < 1 o cola > 15 %), rojo (ρ ≥ 1 o cola > 50 % o rechazos).
- **Balanceador**: round-robin entre destinos que considera sanos; chequeo de salud cada 1 s.
  Si un destino cae, las peticiones fallan hasta el siguiente chequeo; luego lo esquiva.
- **Caché**: % de aciertos configurable; acierto = responde ya; fallo = pregunta aguas abajo.
- **Cliente**: el tráfico total se reparte entre clientes.
- Métricas (ventana de 2 s): completadas/s, latencia media (ms de espera + proceso en los componentes) y % de errores.
- La interfaz dibuja como máximo ~250 trenes por fotograma (muestreo estable por id) para mantener 60 fps.

## 4. Sistema de diseño

Marca: el logo de DistiNode (`public/brand/distinode-original.jpg`, recreado en SVG en
`src/components/Logo.tsx`): cuatro cubos isométricos —el cubo gris, blanco y verde de la CUJAE— unidos por un
hexágono abierto, es decir, nodos de un sistema distribuido. Palabra "DistiNode" con "Disti" en verde.
Metáfora de la interfaz: **mapa de metro**. Las conexiones son líneas verdes gruesas con
tramos a 0°/45°; los nodos son estaciones blancas con anillo; las peticiones son trenes cortos.

### Colores (6)

| Token | Claro | Oscuro | Uso |
| --- | --- | --- | --- |
| `--verde` | `#00704F` | `#2BA77B` | Marca, líneas de metro, acción principal, estado sano |
| `--gris` | `#A6A6A6` | `#A6A6A6` | Cara del cubo, líneas inactivas, trenes de respuesta (oscurecido a `#7A7F7C` en claro para contraste) |
| `--tinta` | `#14211C` | `#E8EEEB` | Texto |
| `--papel` | `#FFFFFF` / fondo `#F3F6F4` | `#16201C` / fondo `#0D1512` | Superficies |
| `--ambar` | `#B86E00` | `#F0A93A` | Saturación |
| `--rojo` | `#C2362F` | `#F06A60` | Caído, errores |

Contraste (texto sobre fondo): tinta/papel > 15:1; verde `#00704F` sobre blanco 6,1:1 (AA texto normal);
verde `#2BA77B` sobre `#0D1512` 6,0:1. Ámbar y rojo de texto superan 4,5:1 en su modo.
Los colores de usuario (cursores y bordes de selección) son 8 tonos distintos de verde/ámbar/rojo para no
confundirse con el estado.

### Tipografía

**Source Sans 3** (400/600/700). Es humanista, de la misma familia de diseño que Myriad —la letra del
logotipo "cujae"—, legible en tamaños pequeños y con cifras tabulares para las métricas
(`font-variant-numeric: tabular-nums`). Una sola familia; la jerarquía sale del peso y el tamaño.

### Forma

- El **hexágono** es la firma: logo, iconos de componentes en la barra lateral, avatares.
- Esquinas: 10 px en paneles, cápsula en botones y estaciones. Sin sombras grises genéricas: separación por
  borde de 1 px (`--linea`) y, en flotantes, una sombra corta teñida de verde.
- Sin degradados decorativos, sin etiquetas en mayúsculas.

### Layout de la sala

```
┌──────────────────────────────────────────────────────────────────┐
│ ⬢ DistiNode /  Nombre de sala  · ABC123 ⧉        ⬢⬢⬢ avatares  ◐   │  56 px
├────────┬─────────────────────────────────────────────┬───────────┤
│ Compo- │                                             │ Propieda- │
│ nentes │        lienzo (rejilla de puntos suave)     │ des (solo │
│ 5 hexá-│                                             │ con algo  │
│ gonos  │                                             │ seleccio- │
│ 208 px │   ▶ ─── tráfico ───  │ 42/s · 85 ms · 0 %   │ nado)     │
└────────┴─────────────────────────────────────────────┴───────────┘
```

- Controles de simulación y métricas: una sola barra flotante abajo al centro, discreta.
- Avisos: esquina inferior izquierda del lienzo, 3,5 s.
- Móvil (< 768 px): solo lectura; se ocultan barra lateral y panel, el lienzo se puede mover y ver.

### Accesibilidad y movimiento

- Foco visible: anillo de 2 px `--verde` con 2 px de separación en todo elemento interactivo.
- `prefers-reduced-motion`: los trenes no se desplazan; las líneas con tráfico se marcan con un pulso estático
  (grosor/intensidad) y el resto de animaciones se desactivan.
- Atajos: **Espacio** ▶/⏸, **Supr/Delete/Retroceso** borra lo seleccionado (fuera de campos de texto).
- Tooltips con `title` + `aria-describedby`; estados vacíos con una acción clara.

## 5. Etapas

1. Base + auth + salas.
2. Lienzo colaborativo.
3. Motor de simulación con pruebas.
4. Pulido visual.

## 6. Variante autoalojada (rama `docker-postgres`)

| Pieza | Rama principal | `docker-postgres` |
| --- | --- | --- |
| Auth | Supabase Auth | Better Auth (enlace mágico + Google) sobre PostgreSQL |
| Salas | Supabase (Postgres + RLS) | PostgreSQL 17 propio + RLS con `app.user_id` por transacción |
| Tiempo real | Liveblocks (nube) | Servidor de Liveblocks autoalojado (o la nube, configurable) |
| Despliegue | Vercel | `docker compose` (db, migrate, app, liveblocks, caddy, mailpit) |

El lienzo, el motor y la demo son idénticos en las dos ramas. Las tablas de Better Auth (`user`, `session`,
`account`, `verification`) están en `db/migrations/0001_auth.sql`; `rooms` y `room_members` con sus políticas,
en `0002_rooms.sql`.
