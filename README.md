# DistiNode

<img src="public/brand/distinode-original.jpg" alt="Logo de DistiNode" width="120">

App web educativa para diseñar sistemas distribuidos **en equipo** y verlos funcionar **en vivo**.
Cada petición es un tren que recorre un mapa de metro: Cliente → Balanceador → Servidores → Caché → Base de datos.

Identidad visual de la CUJAE. Plan, modelo de datos y sistema de diseño en [`docs/plan.md`](docs/plan.md).

> **Rama `docker-postgres`**: versión autoalojada. Todo corre en tu servidor con `docker compose`:
> PostgreSQL propio, autenticación con Better Auth y tiempo real con el servidor de Liveblocks autoalojado.
> No necesita Supabase, Vercel ni cuentas externas.

## Qué hace

- Entrar con enlace mágico al correo (y con Google, si lo configuras).
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

## Arquitectura en Docker

```
             navegador
                 │  http(s)://tu-dominio
            ┌────▼────┐
            │  caddy  │  HTTPS automático con dominio
            └─┬─────┬─┘
   /v7, /v8   │     │  todo lo demás
   (WebSocket)│     │
   ┌──────────▼─┐ ┌─▼───────┐      ┌──────────┐
   │ liveblocks │ │   app   │─────▶│    db    │  PostgreSQL 17
   │ (tiempo    │◀┤ Next.js │      │ (volumen)│
   │  real)     │ └────┬────┘      └────▲─────┘
   └────────────┘      │ SMTP           │
                  ┌────▼────┐     ┌─────┴────┐
                  │ mailpit │     │ migrate  │  aplica db/migrations y termina
                  └─────────┘     └──────────┘
```

| Servicio | Qué es |
| --- | --- |
| `db` | PostgreSQL 17. Datos en el volumen `db-data`. |
| `migrate` | Aplica `db/migrations/*.sql` (una vez cada una) y termina. La app espera a que acabe. |
| `app` | Next.js en modo `standalone`. Se conecta como `distinode_app`, un rol sin privilegios: RLS decide qué salas ve cada persona. |
| `liveblocks` | Servidor de Liveblocks autoalojado (AGPL-3.0, el mismo núcleo que su nube). Diagramas en el volumen `liveblocks-data`. |
| `caddy` | Proxy inverso: un único origen para la web y el WebSocket. Con un dominio, certificado HTTPS automático. |
| `mailpit` | Bandeja de pruebas para los correos del enlace mágico (http://localhost:8025). En producción usa un SMTP real. |

## Puesta en marcha con Docker

Requisitos: Docker con el plugin Compose (Docker Desktop o Docker Engine en Linux).

```bash
git clone https://github.com/andycg03/web-sistemas-distribuidos.git
cd web-sistemas-distribuidos
git checkout docker-postgres

cp .env.docker.example .env
# Rellena en .env: POSTGRES_PASSWORD, APP_DB_PASSWORD y BETTER_AUTH_SECRET
#   openssl rand -base64 32     (una vez por cada valor)

docker compose up -d --build
```

Abre http://localhost. Para entrar: escribe tu correo, abre http://localhost:8025 (Mailpit), pulsa el enlace
del correo y ya estás dentro. Crea una sala y comparte su enlace o su código.

Comandos útiles:

```bash
docker compose ps                 # estado de los servicios
docker compose logs -f app        # registros de la app
docker compose up -d --build      # actualizar tras un git pull (las migraciones nuevas se aplican solas)
docker compose down               # parar (los datos quedan en los volúmenes)
docker compose exec db pg_dump -U distinode distinode > copia.sql   # copia de seguridad
```

### Ponerlo en línea (servidor con dominio)

1. Un servidor Linux con Docker y los puertos 80 y 443 abiertos.
2. Un registro DNS `A` de tu dominio (p. ej. `distinode.midominio.cu`) apuntando a la IP del servidor.
3. En `.env`:
   ```bash
   SITE_ADDRESS=distinode.midominio.cu
   PUBLIC_URL=https://distinode.midominio.cu
   SMTP_URL=smtp://usuario:clave@smtp.tuproveedor.com:587   # para que los correos salgan de verdad
   MAIL_FROM=DistiNode <no-responder@midominio.cu>
   ```
4. `docker compose up -d --build`. Caddy obtiene el certificado HTTPS de Let's Encrypt en el primer acceso.
5. Con SMTP real ya no necesitas Mailpit: quita el servicio o no publiques su puerto (`MAILPIT_PORT`), porque
   su bandeja muestra todos los correos enviados.

Sin dominio también funciona por IP: deja `SITE_ADDRESS=:80` y pon `PUBLIC_URL=http://IP-DEL-SERVIDOR`.

### Google (opcional)

En [Google Cloud Console](https://console.cloud.google.com/apis/credentials) crea un *OAuth client ID* de tipo
*Web application* con la redirect URI `${PUBLIC_URL}/api/auth/callback/google`, y pon `GOOGLE_CLIENT_ID` y
`GOOGLE_CLIENT_SECRET` en `.env`. El botón "Continuar con Google" aparece solo cuando están definidos.

### Liveblocks: propio o en la nube

Por defecto el tiempo real lo da el contenedor `liveblocks`, sin cuentas. Ten en cuenta su modelo de seguridad:
ese servidor **no firma los tokens de acceso**, así que la protección de cada sala se basa en que su
identificador (un UUID aleatorio) solo se entrega a sus miembros, y en que Caddy expone únicamente los WebSocket
(`/v7`, `/v8`) y no su API de administración. Es adecuado para clases y equipos; si necesitas una garantía
estricta, usa la nube de Liveblocks:

```bash
LIVEBLOCKS_SECRET_KEY=sk_...   # de liveblocks.io → tu proyecto → API keys
LIVEBLOCKS_BASE_URL=           # vacío: usar la nube
```

## Desarrollo sin Docker

Requisitos: Node.js 20.9+, un PostgreSQL y (para el lienzo) `npx liveblocks dev`.

```bash
npm install
cp .env.example .env.local        # y rellénalo
# En tu Postgres, crea una vez el rol de la app:
#   create role distinode_app login password 'CLAVE' nosuperuser nobypassrls;
npm run db:migrate                # usa MIGRATION_DATABASE_URL (dueño de las tablas)
npx liveblocks dev                # en otra terminal
npm run dev                       # http://localhost:3000
```

Para ver los correos del enlace mágico sin SMTP real: `docker run -p 8025:8025 -p 1025:1025 axllent/mailpit`.

### Comprobaciones

```bash
npm run lint        # ESLint
npm run typecheck   # tipos de rutas + tsc
npm test            # pruebas del motor de simulación (Vitest)
```

## Cómo comprobar la v1

1. Abre la app en dos navegadores (o uno normal y otro privado) y entra con dos correos distintos.
2. A crea una sala y copia el enlace (junto al código). B lo abre y pulsa "Unirme".
3. Mueve el ratón y un nodo en A: B ve el cursor con nombre y el cambio al momento.
4. En la sala vacía, "Cargar ejemplo" y ▶ (o Espacio): los trenes empiezan a circular.
5. Sube el tráfico a ~70 pet/s: Servidor 1 se pone rojo.
6. Arrastra otro Servidor y conecta Balanceador → Servidor 2 → Base de datos: los dos vuelven a verde.
7. Tumba un servidor: aparecen errores y, tras el chequeo de salud (1 s), el balanceador lo esquiva.
8. Recarga (o reinicia con `docker compose restart`): el diagrama sigue ahí.

## Seguridad

- La app se conecta a Postgres como `distinode_app` (sin superusuario ni `BYPASSRLS`). Cada consulta de salas
  fija `app.user_id` en su transacción y las políticas RLS de `rooms` y `room_members` filtran por él.
- Crear y unirse pasan por funciones `security definer` (`create_room`, `join_room`) que validan la sesión.
- `/api/liveblocks-auth` comprueba la sesión y la membresía antes de firmar el acceso a `distinode:<id-de-sala>`;
  el nombre y color que ven los demás los fija el servidor.
- Enlace mágico: un solo uso, caduca en 15 minutos, máximo 5 envíos por minuto.

## Arquitectura del código (y lo que viene)

- `src/sim/` es el motor: TypeScript puro, paso fijo, semilla y pruebas. No sabe nada de React.
- `src/sim/components.ts` es el registro de componentes: añadir uno es una entrada ahí + su comportamiento en
  `engine.ts`; la barra lateral y el panel se generan solos.
- `src/features/collab/` separa el lienzo del transporte: Liveblocks (salas) o local (demo).
- `db/migrations/` y `scripts/migrate.mjs`: el esquema de Postgres, versionado.
- Lecciones y misiones: un escenario = grafo inicial + objetivos evaluados sobre `engine.metrics()`.
- Móvil: por debajo de 768 px la barra lateral y el panel se convierten en hojas inferiores (`useIsMobile`).
