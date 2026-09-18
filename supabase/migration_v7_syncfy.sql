-- Migración v7 — Conexión bancaria vía Syncfy (Open Data).
--
-- Persistencia server-side: el backend (service_role) crea/actualiza estas filas
-- tras hablar con Syncfy. La app las LEE vía PostgREST bajo RLS por household.
-- Nunca se guardan credenciales bancarias, OTP ni tokens: solo identificadores
-- de Syncfy (id_credential, id_site, id_account, id_transaction) y los datos ya
-- sincronizados (saldos, movimientos).

-- Cada usuario Plata ↔ un usuario Syncfy (id_user). Se guarda en el perfil.
alter table public.profiles
  add column if not exists syncfy_user_id text;

-- ─── Conexión bancaria (una credencial de Syncfy) ────────────────────────────
create table if not exists public.bank_connections (
  id uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null default 'syncfy',
  provider_credential_id text not null,          -- id_credential de Syncfy
  provider_site_id text not null,                -- id_site
  institution text not null,                     -- nombre del banco/site
  status text not null default 'active'          -- active | requires_reauth | error | syncing
    check (status in ('active', 'requires_reauth', 'error', 'syncing')),
  connected_at timestamptz not null default now(),
  last_sync_at timestamptz,                       -- último intento de sync
  last_successful_sync_at timestamptz,            -- último sync exitoso
  created_at timestamptz not null default now(),
  unique (household_id, provider, provider_credential_id)
);

create index if not exists bank_connections_household_idx
  on public.bank_connections(household_id);

-- ─── Cuenta bancaria sincronizada ────────────────────────────────────────────
create table if not exists public.bank_accounts (
  id uuid primary key default uuid_generate_v4(),
  connection_id uuid not null references public.bank_connections(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  provider_account_id text not null,             -- id_account de Syncfy
  name text not null,
  type text,
  balance numeric(14,2) not null default 0,
  currency char(3),
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  unique (connection_id, provider_account_id)
);

create index if not exists bank_accounts_household_idx
  on public.bank_accounts(household_id);
create index if not exists bank_accounts_connection_idx
  on public.bank_accounts(connection_id);

-- ─── Movimiento bancario sincronizado (idempotente por id_transaction) ───────
create table if not exists public.bank_transactions (
  id uuid primary key default uuid_generate_v4(),
  account_id uuid not null references public.bank_accounts(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  provider_transaction_id text not null,         -- id_transaction de Syncfy
  amount numeric(14,2) not null,
  description text,
  currency char(3),
  transaction_date timestamptz,                  -- dt_transaction
  pending boolean not null default false,        -- is_pending
  provider_refresh_at timestamptz,               -- dt_refresh (para sync incremental)
  created_at timestamptz not null default now(),
  unique (account_id, provider_transaction_id)
);

create index if not exists bank_transactions_household_idx
  on public.bank_transactions(household_id);
create index if not exists bank_transactions_account_idx
  on public.bank_transactions(account_id);

-- ─── RLS: lectura por household (la escritura la hace el backend con service_role,
--     que salta RLS). ───────────────────────────────────────────────────────────
alter table public.bank_connections enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.bank_transactions enable row level security;

create policy "bank_connections_household_select" on public.bank_connections
  for select using (household_id = public.get_my_household_id());
create policy "bank_accounts_household_select" on public.bank_accounts
  for select using (household_id = public.get_my_household_id());
create policy "bank_transactions_household_select" on public.bank_transactions
  for select using (household_id = public.get_my_household_id());
