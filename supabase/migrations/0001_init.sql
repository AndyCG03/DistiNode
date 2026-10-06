-- Nodos v1 — salas y miembros, con RLS.
-- Ejecuta este archivo en el editor SQL de Supabase (o con `supabase db push`).

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  owner_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_id uuid not null references public.rooms (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create index if not exists room_members_user_idx on public.room_members (user_id, joined_at desc);

alter table public.rooms enable row level security;
alter table public.room_members enable row level security;

-- Cada persona ve solo sus propias membresías.
drop policy if exists "miembros: ver las mías" on public.room_members;
create policy "miembros: ver las mías" on public.room_members
  for select to authenticated
  using (user_id = (select auth.uid()));

-- Cada persona puede salir de una sala.
drop policy if exists "miembros: salir" on public.room_members;
create policy "miembros: salir" on public.room_members
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- Una sala solo es visible para sus miembros.
drop policy if exists "salas: ver si soy miembro" on public.rooms;
create policy "salas: ver si soy miembro" on public.rooms
  for select to authenticated
  using (
    exists (
      select 1 from public.room_members m
      where m.room_id = rooms.id and m.user_id = (select auth.uid())
    )
  );

-- Solo el dueño renombra o borra.
drop policy if exists "salas: el dueño edita" on public.rooms;
create policy "salas: el dueño edita" on public.rooms
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

drop policy if exists "salas: el dueño borra" on public.rooms;
create policy "salas: el dueño borra" on public.rooms
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- No hay políticas de INSERT: crear y unirse pasan por estas funciones.

create or replace function public.create_room(p_name text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_room uuid;
  v_name text := btrim(coalesce(p_name, ''));
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if v_name = '' then
    v_name := 'Sala sin nombre';
  end if;
  v_name := left(v_name, 60);

  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    begin
      insert into public.rooms (code, name, owner_id)
      values (v_code, v_name, v_uid)
      returning id into v_room;
      exit;
    exception when unique_violation then
      -- código repetido: probamos otro
    end;
  end loop;

  insert into public.room_members (room_id, user_id, role) values (v_room, v_uid, 'owner');
  return v_code;
end;
$$;

create or replace function public.join_room(p_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_room uuid;
  v_code text := upper(btrim(coalesce(p_code, '')));
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;

  select id into v_room from public.rooms where code = v_code;
  if v_room is null then
    return null;
  end if;

  insert into public.room_members (room_id, user_id, role)
  values (v_room, v_uid, 'member')
  on conflict (room_id, user_id) do nothing;

  return v_code;
end;
$$;

revoke all on function public.create_room(text) from public, anon;
revoke all on function public.join_room(text) from public, anon;
grant execute on function public.create_room(text) to authenticated;
grant execute on function public.join_room(text) to authenticated;
