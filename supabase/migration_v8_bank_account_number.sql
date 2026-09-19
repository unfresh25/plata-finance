-- v8 — número de cuenta bancaria (enmascarado) para mostrar en la card.
alter table public.bank_accounts add column if not exists number text;
