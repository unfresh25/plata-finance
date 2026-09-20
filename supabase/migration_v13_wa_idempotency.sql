-- v13 — Idempotencia del webhook de WhatsApp: no procesar el mismo mensaje 2 veces.
create table if not exists public.whatsapp_processed (
  message_id text primary key,
  processed_at timestamptz not null default now()
);
alter table public.whatsapp_processed enable row level security;
-- Solo el backend (service_role) la usa; sin políticas para el cliente.
