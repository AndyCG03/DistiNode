# DistiNode

<img src="public/brand/distinode-original.jpg" alt="Logo de DistiNode" width="120">

App web educativa para diseñar sistemas distribuidos **en equipo** y verlos funcionar **en vivo**.
Cada petición es un tren que recorre un mapa de metro: Cliente → Balanceador → Servidores → Caché → Base de datos.

Identidad visual de la CUJAE. Plan, modelo de datos y sistema de diseño en [`docs/plan.md`](docs/plan.md). Presentación en PDF (identidad y funcionalidades): [`docs/DistiNode-dossier.pdf`](docs/DistiNode-dossier.pdf).

## Qué hace

- Entrar con enlace mágico al correo o con Google.
- Salas: crear, unirse con un código de 6 caracteres (o con el enlace de invitación) y "Mis salas".
- Lienzo compartido en tiempo real: cursores y avatares de quien está, borde con el color de quien selecciona,
  avisos breves ("Ana tumbó Servidor 2"). Se guarda solo.
- **9 componentes** en tres familias: Cliente, CDN, API Gateway, Balanceador (por turnos o menos conexiones),
  Servidor (también en modo microservicio: llama en paralelo a lo que tiene detrás), Worker, Caché,
  Cola de mensajes y Base de datos.
- **Simulación realista**: colas y saturación verde → ámbar → rojo, tiempos de espera y reintentos con espera
  exponencial (tormentas de reintentos incluidas), límite de ritmo, trabajo asíncrono con reentrega, latencia
  de red por línea y métricas en vivo con gráficas del último minuto: completadas/s, latencia p95, errores,
  reintentos y trabajo en segundo plano.
- **Fallos**: tumbar, degradar (lento) y cortar conexiones a mano; modo **Caos** (caídas, lentitud y cortes al
  azar que se recuperan solos) y **caídas por sobrecarga** con reinicio automático. Compartidos por toda la sala.
- **14 plantillas** listas para darle al ▶. Patrones: lo esencial, alta disponibilidad, web a gran escala,
  trabajo en segundo plano, microservicios y tormenta de reintentos. Sistemas reales: tienda online, streaming
  de vídeo, mensajería, pasarela de pagos, red social, sensores IoT, app de viajes y dos regiones.
- **Proyectos**: exportar el diagrama como imagen PNG, guardarlo en un archivo `.distinode.json` e importarlo.
- **Guía** en la app (`/guia`): componentes con sus equivalentes reales, métricas, fallos, plantillas, retos
  para clase y glosario. Documentación técnica del motor en [`docs/motor.md`](docs/motor.md).
- **También en el móvil**: botón + para añadir componentes y plantillas, propiedades en una hoja inferior y
  «Conectar con…» para unir estaciones sin arrastrar. **Demo sin cuenta** (`/demo`), guardada en el navegador.

## App para Windows, Linux y Android (sin cuentas)

En [`app/`](app/) está DistiNode en Flutter: todas las funciones de diseño y simulación de la web, pero
**totalmente local** (sin registro, sin servidor y sin conexión). Los proyectos se guardan como archivos
`.distinode.json`, compatibles con la web. Descárgala desde
[Releases](https://github.com/AndyCG03/web-sistemas-distribuidos/releases): instalador para Windows, `.deb` y
`.tar.gz` para Linux y `.apk` para Android. Detalles en [`app/README.md`](app/README.md).

## Stack

Next.js 16 (App Router) · TypeScript · Tailwind CSS 4 · React Flow · Liveblocks · Supabase · Vitest · Vercel.

## Puesta en marcha local

Requisitos: Node.js 20.9 o superior.

```bash
npm install
cp .env.example .env.local   # y rellena las claves (ver abajo)
npm run dev                  # http://localhost:3000
```

### Sin cuentas: Liveblocks en local

Para desarrollar el lienzo sin crear un proyecto en Liveblocks puedes usar su servidor local:

```bash
npx liveblocks dev            # http://localhost:1153
```

y en `.env.local`:

```bash
LIVEBLOCKS_SECRET_KEY=sk_localdev
LIVEBLOCKS_BASE_URL=http://localhost:1153
NEXT_PUBLIC_LIVEBLOCKS_BASE_URL=http://localhost:1153
```

Las dos variables `*_BASE_URL` son opcionales: si no están, se usa el servicio real de Liveblocks.
Supabase sigue haciendo falta para entrar y crear salas.

### Comprobaciones

```bash
npm run lint        # ESLint
npm run typecheck   # tipos de rutas + tsc
npm test            # pruebas del motor de simulación (Vitest)
```

## Claves

`.env.example` lista todas las variables. Ningún valor viene de serie: cada uno sale de tu cuenta.

### Supabase (autenticación y salas)

1. Crea un proyecto en [supabase.com](https://supabase.com/dashboard).
2. **Project Settings → API** (o el botón **Connect**):
   - `NEXT_PUBLIC_SUPABASE_URL` = *Project URL*.
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` = la clave **publishable** (`sb_publishable_…`).
     La clave *anon* heredada también sirve. Nunca uses la *service_role* / *secret* aquí.
3. **SQL Editor**: pega y ejecuta [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql).
   Crea `rooms` y `room_members` con RLS activada, y las funciones `create_room` y `join_room`.
4. **Authentication → URL Configuration**:
   - *Site URL*: `http://localhost:3000` en desarrollo (luego, tu dominio de Vercel).
   - *Redirect URLs*: añade `http://localhost:3000/auth/callback` y `https://TU-DOMINIO/auth/callback`.
5. **Enlace mágico**: viene activado (Authentication → Providers → Email). El enlace funciona en el mismo
   navegador donde lo pediste. Para que funcione en cualquiera, cambia la plantilla *Magic Link* para que apunte a
   `{{ .SiteURL }}/auth/callback?token_hash={{ .TokenHash }}&type=email`.
   El correo de pruebas de Supabase tiene un límite bajo de envíos por hora; para clase configura un SMTP propio
   (Authentication → Emails → SMTP Settings).
6. **Google**:
   1. En [Google Cloud Console](https://console.cloud.google.com/apis/credentials) crea un *OAuth client ID*
      de tipo *Web application*.
   2. *Authorized redirect URI*: la que te muestra Supabase en Authentication → Providers → Google
      (`https://<tu-proyecto>.supabase.co/auth/v1/callback`).
   3. Copia *Client ID* y *Client secret* en ese mismo formulario de Supabase y actívalo.

### Liveblocks (tiempo real)

1. Crea un proyecto en [liveblocks.io](https://liveblocks.io/dashboard).
2. **API keys** → copia la **secret key** (`sk_…`) en `LIVEBLOCKS_SECRET_KEY`.
   Es solo de servidor: la usa `/api/liveblocks-auth` para emitir tokens únicamente a miembros de la sala.
   La clave pública no hace falta.

## Desplegar en Vercel

La app se puede desplegar **sin ninguna variable**: la portada y la demo (`/demo`) funcionan enteras, y
"Entrar", "Mis salas" y las salas muestran un aviso de qué falta en lugar de fallar. Con las claves se activan
el inicio de sesión, las salas y la colaboración en tiempo real.

1. Importa el repositorio en [vercel.com/new](https://vercel.com/new) (detecta Next.js solo; no hace falta
   cambiar ningún comando). Si la rama de trabajo no es `main`, elígela como *Production Branch* en
   Settings → Git, o fusiónala en `main`.
2. Cuando tengas las claves, en **Settings → Environment Variables** añade las tres variables de `.env.example`
   (para *Production* y *Preview*) y vuelve a desplegar (Deployments → ⋯ → Redeploy). Las `NEXT_PUBLIC_*` se
   incrustan al compilar, así que hay que redesplegar tras cambiarlas.
3. Con el dominio final (`https://distinode-xxx.vercel.app` o el tuyo):
   - Supabase → Authentication → URL Configuration: pon ese dominio como *Site URL* y añade
     `https://TU-DOMINIO/auth/callback` a *Redirect URLs*.
   - Google Cloud: no hay que tocar nada (la redirección va a Supabase).

## Cómo comprobar la v1

1. Abre la app en dos navegadores (o uno normal y otro privado) con dos usuarios distintos.
2. Usuario A: crea una sala y copia el enlace (botón junto al código). Usuario B: ábrelo y pulsa "Unirme".
3. Mueve el ratón y un nodo en A: B ve el cursor con nombre y el cambio al momento.
4. En la sala vacía, "Cargar ejemplo" y ▶ (o Espacio): los trenes empiezan a circular.
5. Sube el tráfico a ~70 pet/s: Servidor 1 se pone rojo, sube la latencia y aparecen errores.
6. Arrastra otro Servidor, conecta Balanceador → Servidor 2 → Base de datos: los dos vuelven a verde.
7. Selecciona un servidor y pulsa "Tumbar": aparecen errores (trenes rojos) y, tras el chequeo de salud
   (1 s por defecto), el balanceador deja de enviarle tráfico.
8. Recarga: el diagrama sigue ahí.

## Arquitectura (y lo que viene)

- `src/sim/` es el motor: TypeScript puro, paso fijo, semilla y pruebas. No sabe nada de React.
- `src/sim/components.ts` es el registro de componentes: añadir uno (p. ej. "Cola de mensajes") es una entrada
  ahí + su comportamiento en `engine.ts`; la barra lateral y el panel de propiedades se generan solos.
- Lecciones y misiones: un escenario = grafo inicial + objetivos evaluados sobre `engine.metrics()`; al ser
  determinista se puede comprobar sin interfaz.
- Modo caos, chat y galería encajan como eventos de sala (`RoomEvent`) y nuevas claves del almacenamiento
  de Liveblocks; la galería, como una tabla más en Supabase con RLS.
- Móvil: por debajo de 768 px la barra lateral y el panel se convierten en hojas inferiores (`useIsMobile`).

## Seguridad

- RLS en todas las tablas: una sala solo es visible para sus miembros; las membresías, solo para su dueño.
- Crear y unirse se hace con funciones `security definer` que validan la sesión.
- `/api/liveblocks-auth` comprueba la sesión de Supabase y la membresía antes de firmar el acceso a
  `distinode:<id-de-sala>`; el nombre y color que ven los demás los fija el servidor.
