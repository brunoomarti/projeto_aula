-- Execute APÓS 001 se já rodou o schema antigo, OU use só este bloco em projeto novo.
-- Firebase third-party: UID é texto (não UUID do auth.users).

-- 1) Remove políticas ANTES de alterar os tipos das colunas
--    (Postgres não deixa alterar coluna usada em policy)
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "tasks_select_own" on public.tasks;
drop policy if exists "tasks_insert_own" on public.tasks;
drop policy if exists "tasks_update_own" on public.tasks;
drop policy if exists "tasks_delete_own" on public.tasks;

-- 2) Remove vínculo com auth.users (login é só Firebase)
alter table if exists public.profiles
  drop constraint if exists profiles_id_fkey;

alter table if exists public.tasks
  drop constraint if exists tasks_user_id_fkey;

-- 3) Converte as colunas de uuid -> text (Firebase UID é texto)
alter table if exists public.profiles
  alter column id type text using id::text;

alter table if exists public.tasks
  alter column user_id type text using user_id::text;

-- 4) Remove o trigger que criava perfil a partir de auth.users
drop trigger if exists on_auth_user_created on auth.users;

-- 5) Recria as políticas usando o claim "sub" do JWT do Firebase
--    auth.jwt() ->> 'sub' = Firebase UID (texto)
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.jwt() ->> 'sub' = id);

create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.jwt() ->> 'sub' = id);

create policy "profiles_update_own"
  on public.profiles for update
  using (auth.jwt() ->> 'sub' = id);

create policy "tasks_select_own"
  on public.tasks for select
  using (auth.jwt() ->> 'sub' = user_id);

create policy "tasks_insert_own"
  on public.tasks for insert
  with check (auth.jwt() ->> 'sub' = user_id);

create policy "tasks_update_own"
  on public.tasks for update
  using (auth.jwt() ->> 'sub' = user_id);

create policy "tasks_delete_own"
  on public.tasks for delete
  using (auth.jwt() ->> 'sub' = user_id);
