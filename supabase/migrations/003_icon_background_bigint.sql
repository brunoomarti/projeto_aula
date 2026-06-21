-- O app envia a cor de fundo do ícone como ARGB de 32 bits (Color.toARGB32()).
-- Cores opacas (alpha = 0xFF) geram valores > 2.147.483.647, que estouram o
-- tipo `integer` do Postgres. Usamos `bigint` para comportar o valor.

alter table if exists public.tasks
  alter column icon_background_argb type bigint;
