-- Campos para regras do combo diário (foguinho).
alter table public.tasks
  add column if not exists schedule_adjusted boolean not null default false;

alter table public.tasks
  add column if not exists completed_at timestamptz;
