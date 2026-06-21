-- Conquistas: progresso agregado e ledger de eventos (append-only).

create table if not exists public.achievement_progress (
  user_id text primary key,
  points_by_trail jsonb not null default '{}'::jsonb,
  unlocked_medal_ids text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table if not exists public.achievement_events (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  trail_id text not null,
  event_key text not null,
  points integer not null default 1 check (points > 0),
  created_at timestamptz not null default now(),
  unique (user_id, event_key)
);

create index if not exists achievement_events_user_id_idx
  on public.achievement_events (user_id, created_at desc);

alter table public.achievement_progress enable row level security;
alter table public.achievement_events enable row level security;

create policy "achievement_progress_select_own"
  on public.achievement_progress for select
  using (auth.jwt() ->> 'sub' = user_id);

create policy "achievement_progress_insert_own"
  on public.achievement_progress for insert
  with check (auth.jwt() ->> 'sub' = user_id);

create policy "achievement_progress_update_own"
  on public.achievement_progress for update
  using (auth.jwt() ->> 'sub' = user_id);

create policy "achievement_events_select_own"
  on public.achievement_events for select
  using (auth.jwt() ->> 'sub' = user_id);

create policy "achievement_events_insert_own"
  on public.achievement_events for insert
  with check (auth.jwt() ->> 'sub' = user_id);

create policy "achievement_events_update_own"
  on public.achievement_events for update
  using (auth.jwt() ->> 'sub' = user_id);

-- Magic Input: flag na tarefa para a trilha de conquistas.
alter table public.tasks
  add column if not exists created_via_magic boolean not null default false;
