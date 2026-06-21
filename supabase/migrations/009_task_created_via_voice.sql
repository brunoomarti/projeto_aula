-- Tarefas criadas por voz no Magic Input (conquistas lendárias).
alter table public.tasks
  add column if not exists created_via_voice boolean not null default false;
