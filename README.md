# Nodos

App web educativa para diseñar sistemas distribuidos **en equipo** y verlos funcionar **en vivo**.
Cada petición es un tren que recorre un mapa de metro: Cliente → Balanceador → Servidores → Caché → Base de datos.

Identidad visual de la CUJAE. Plan, modelo de datos y sistema de diseño en [`docs/plan.md`](docs/plan.md).

## Stack

Next.js 16 (App Router) · TypeScript · Tailwind CSS 4 · React Flow · Liveblocks · Supabase · Vitest · Vercel.

## Puesta en marcha local

Requisitos: Node.js 20.9 o superior.

```bash
npm install
cp .env.example .env.local   # y rellena las claves (ver abajo)
npm run dev                  # http://localhost:3000
```

Comprobaciones:

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

1. Sube el repositorio a GitHub e impórtalo en [vercel.com/new](https://vercel.com/new) (detecta Next.js solo).
2. En **Settings → Environment Variables** añade las tres variables de `.env.example`.
3. Despliega. Con el dominio final (`https://nodos-xxx.vercel.app` o el tuyo):
   - Supabase → Authentication → URL Configuration: pon ese dominio como *Site URL* y añade
     `https://TU-DOMINIO/auth/callback` a *Redirect URLs*.
   - Google Cloud: no hay que tocar nada (la redirección va a Supabase).

## Seguridad

- RLS en todas las tablas: una sala solo es visible para sus miembros; las membresías, solo para su dueño.
- Crear y unirse se hace con funciones `security definer` que validan la sesión.
- `/api/liveblocks-auth` comprueba la sesión de Supabase y la membresía antes de firmar el acceso a
  `nodos:<id-de-sala>`; el nombre y color que ven los demás los fija el servidor.
