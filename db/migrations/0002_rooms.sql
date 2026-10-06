-- Salas y miembros, con RLS. La app fija app.user_id en cada transacción (src/lib/db.ts → withUser).

create or replace function app_user_id() returns text
language sql stable
as $$ select nullif(current_setting('app.user_id', true), '') $$;

create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  owner_id text not null references "user" (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists room_members (
  room_id uuid not null references rooms (id) on delete cascade,
  user_id text not null references "user" (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create index if not exists room_members_user_idx on room_members (user_id, joined_at desc);

alter table rooms enable row level security;
alter table room_members enable row level security;

drop policy if exists "miembros: ver las mías" on room_members;
create policy "miembros: ver las mías" on room_members
  for select to distinode_app using (user_id = app_user_id());

drop policy if exists "miembros: salir" on room_members;
create policy "miembros: salir" on room_members
  for delete to distinode_app using (user_id = app_user_id());

drop policy if exists "salas: ver si soy miembro" on rooms;
create policy "salas: ver si soy miembro" on rooms
  for select to distinode_app
  using (exists (select 1 from room_members m where m.room_id = rooms.id and m.user_id = app_user_id()));

drop policy if exists "salas: el dueño edita" on rooms;
create policy "salas: el dueño edita" on rooms
  for update to distinode_app using (owner_id = app_user_id()) with check (owner_id = app_user_id());

drop policy if exists "salas: el dueño borra" on rooms;
create policy "salas: el dueño borra" on rooms
  for delete to distinode_app using (owner_id = app_user_id());

grant select, update, delete on rooms to distinode_app;
grant select, delete on room_members to distinode_app;

-- Sin INSERT directo: crear y unirse pasan por estas funciones (se ejecutan como el dueño de las tablas).

create or replace function create_room(p_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid text := app_user_id();
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_room uuid;
  v_name text := left(coalesce(nullif(btrim(p_name), ''), 'Sala sin nombre'), 60);
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    begin
      insert into rooms (code, name, owner_id) values (v_code, v_name, v_uid) returning id into v_room;
      exit;
    exception when unique_violation then
      -- código repetido: probamos otro
    end;
  end loop;
  insert into room_members (room_id, user_id, role) values (v_room, v_uid, 'owner');
  return v_code;
end;
$$;

create or replace function join_room(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid text := app_user_id();
  v_room uuid;
  v_code text := upper(btrim(coalesce(p_code, '')));
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  select id into v_room from rooms where code = v_code;
  if v_room is null then
    return null;
  end if;
  insert into room_members (room_id, user_id, role) values (v_room, v_uid, 'member')
  on conflict (room_id, user_id) do nothing;
  return v_code;
end;
$$;

revoke all on function create_room(text) from public;
revoke all on function join_room(text) from public;
grant execute on function create_room(text) to distinode_app;
grant execute on function join_room(text) to distinode_app;
grant execute on function app_user_id() to distinode_app;
