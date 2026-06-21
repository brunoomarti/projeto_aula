-- Tarefas adiadas (data alterada após 1 h da criação) não contam no combo diário.
alter table public.tasks
  add column if not exists postponed boolean not null default false;
