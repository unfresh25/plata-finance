-- v12 — Vínculo de WhatsApp con la cuenta del usuario.
-- El usuario genera un código en la app y lo manda por WhatsApp una vez; el
-- webhook lo canjea y guarda el vínculo phone → (user, household).

create table if not exists public.whatsapp_link_codes (
  code text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '15 minutes')
);

create table if not exists public.whatsapp_links (
  phone text primary key,               -- número en formato internacional, solo dígitos
  user_id uuid not null references public.profiles(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- El backend usa service_role (salta RLS). La app solo inserta/lee sus códigos.
alter table public.whatsapp_link_codes enable row level security;
alter table public.whatsapp_links enable row level security;

create policy "wa_codes_own" on public.whatsapp_link_codes
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "wa_links_household_read" on public.whatsapp_links
  for select using (household_id = public.get_my_household_id());
