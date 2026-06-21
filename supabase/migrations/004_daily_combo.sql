-- Combo diário: estado atual e histórico de sequências encerradas.

create table if not exists public.daily_combo_state (
  user_id uuid primary key references auth.users (id) on delete cascade,
  current_streak integer not null default 0,
  streak_started_on date,
  last_cleared_on date,
  pending_archive_length integer,
  pending_archive_started_on date,
  pending_archive_broken_on date,
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_combo_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  streak_length integer not null check (streak_length > 0),
  started_on date not null,
  ended_on date not null,
  restarted_on date not null,
  created_at timestamptz not null default now()
);

create index if not exists daily_combo_history_user_id_idx
  on public.daily_combo_history (user_id, created_at desc);

alter table public.daily_combo_state enable row level security;
alter table public.daily_combo_history enable row level security;

create policy "daily_combo_state_select_own"
  on public.daily_combo_state for select
  using (auth.uid() = user_id);

create policy "daily_combo_state_insert_own"
  on public.daily_combo_state for insert
  with check (auth.uid() = user_id);

create policy "daily_combo_state_update_own"
  on public.daily_combo_state for update
  using (auth.uid() = user_id);

create policy "daily_combo_history_select_own"
  on public.daily_combo_history for select
  using (auth.uid() = user_id);

create policy "daily_combo_history_insert_own"
  on public.daily_combo_history for insert
  with check (auth.uid() = user_id);
