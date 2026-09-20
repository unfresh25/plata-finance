-- v10 — División de gastos en pareja.
-- split_mode por transacción de gasto:
--   'shared'   → compartido 50/50 entre los miembros del hogar (default histórico).
--   'personal' → gasto personal de quien lo registró (no entra en el balance común).
-- Los ingresos/transferencias ignoran este campo.

alter table public.transactions
  add column if not exists split_mode text not null default 'shared'
  check (split_mode in ('shared', 'personal'));
