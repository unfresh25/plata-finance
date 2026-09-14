-- =============================================================================
-- JOJO'S FINANCE — Supabase SQL Migration
-- Ejecuta este script en el SQL Editor de tu proyecto Supabase
-- =============================================================================

-- Habilitar la extensión UUID
create extension if not exists "uuid-ossp";

-- =============================================================================
-- 1. INFRASTRUCTURE BASE
-- =============================================================================

-- Households (espacio compartido entre dos usuarios)
create table public.households (
  id         uuid primary key default uuid_generate_v4(),
  name       text not null,
  created_at timestamptz not null default now()
);

-- Profiles (vinculados a auth.users)
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  household_id uuid references public.households(id) on delete set null,
  name         text not null,
  avatar_url   text,
  currency     char(3) not null default 'USD', -- ISO 4217
  created_at   timestamptz not null default now()
);

-- Categories (personalizables por household)
create table public.categories (
  id           uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  name         text not null,
  icon         text not null,
  color        text not null,
  type         text not null check (type in ('income', 'expense'))
);

-- =============================================================================
-- 2. ACCOUNTS & TRANSACTIONS
-- =============================================================================

create table public.accounts (
  id           uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  owner_id     uuid not null references public.profiles(id) on delete cascade,
  name         text not null,
  type         text not null check (type in ('debit', 'credit', 'cash', 'savings')),
  balance      numeric(12,2) not null default 0,
  currency     char(3) not null default 'USD',
  color        text not null,
  icon         text not null
);

create table public.transactions (
  id           uuid primary key default uuid_generate_v4(),
  account_id   uuid not null references public.accounts(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  created_by   uuid not null references public.profiles(id) on delete cascade,
  amount       numeric(12,2) not null check (amount > 0),
  type         text not null check (type in ('income', 'expense', 'transfer')),
  category_id  uuid references public.categories(id) on delete set null,
  description  text,
  date         date not null default current_date,
  is_recurring boolean not null default false,
  recurring_id uuid,
  created_at   timestamptz not null default now()
);

-- =============================================================================
-- 3. RECURRING EVENTS & BUDGETS
-- =============================================================================

create table public.recurring_events (
  id           uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  name         text not null,
  amount       numeric(12,2) not null check (amount > 0),
  frequency    text not null check (frequency in ('daily', 'weekly', 'monthly', 'yearly')),
  next_date    date not null,
  category_id  uuid references public.categories(id) on delete set null,
  account_id   uuid references public.accounts(id) on delete set null,
  is_active    boolean not null default true
);

create table public.budgets (
  id           uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  category_id  uuid not null references public.categories(id) on delete cascade,
  amount       numeric(12,2) not null check (amount > 0),
  period       text not null check (period in ('weekly', 'monthly')),
  start_date   date not null default date_trunc('month', current_date)
);

-- =============================================================================
-- 4. DEBTS
-- =============================================================================

create table public.debts (
  id           uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by   uuid not null references public.profiles(id) on delete cascade,
  direction    text not null check (direction in ('owed_to_us', 'we_owe')),
  person_name  text not null,
  amount       numeric(12,2) not null check (amount > 0),
  amount_paid  numeric(12,2) not null default 0,
  due_date     date,
  description  text,
  status       text not null default 'active' check (status in ('active', 'paid')),
  created_at   timestamptz not null default now()
);

create table public.debt_payments (
  id      uuid primary key default uuid_generate_v4(),
  debt_id uuid not null references public.debts(id) on delete cascade,
  amount  numeric(12,2) not null check (amount > 0),
  date    date not null default current_date,
  note    text
);

-- =============================================================================
-- 5. SAVINGS GOALS
-- =============================================================================

create table public.savings_goals (
  id             uuid primary key default uuid_generate_v4(),
  household_id   uuid not null references public.households(id) on delete cascade,
  name           text not null,
  target_amount  numeric(12,2) not null check (target_amount > 0),
  current_amount numeric(12,2) not null default 0,
  deadline       date,
  icon           text not null,
  color          text not null,
  account_id     uuid references public.accounts(id) on delete set null,
  status         text not null default 'active' check (status in ('active', 'completed', 'cancelled')),
  created_at     timestamptz not null default now()
);

create table public.savings_contributions (
  id         uuid primary key default uuid_generate_v4(),
  goal_id    uuid not null references public.savings_goals(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  amount     numeric(12,2) not null check (amount > 0),
  date       date not null default current_date,
  note       text
);

-- =============================================================================
-- 6. FINANCIAL PLANS
-- =============================================================================

create table public.financial_plans (
  id                   uuid primary key default uuid_generate_v4(),
  household_id         uuid not null references public.households(id) on delete cascade,
  name                 text not null,
  type                 text not null check (type in ('debt_payoff', 'savings', 'budget')),
  target_amount        numeric(12,2) not null,
  monthly_contribution numeric(12,2) not null,
  start_date           date not null,
  end_date             date,
  status               text not null default 'active' check (status in ('active', 'completed', 'cancelled')),
  linked_id            uuid -- referencias flexibles a deuda/meta/presupuesto
);

-- =============================================================================
-- 7. SHOPPING
-- =============================================================================

create table public.shopping_lists (
  id              uuid primary key default uuid_generate_v4(),
  household_id    uuid not null references public.households(id) on delete cascade,
  created_by      uuid not null references public.profiles(id) on delete cascade,
  name            text not null,
  store           text,
  estimated_total numeric(12,2),
  actual_total    numeric(12,2),
  status          text not null default 'open' check (status in ('open', 'shopping', 'completed')),
  date            date not null default current_date,
  category_id     uuid references public.categories(id) on delete set null,
  created_at      timestamptz not null default now()
);

create table public.shopping_items (
  id              uuid primary key default uuid_generate_v4(),
  list_id         uuid not null references public.shopping_lists(id) on delete cascade,
  name            text not null,
  quantity        numeric(8,2) not null default 1,
  unit            text,
  estimated_price numeric(12,2),
  actual_price    numeric(12,2),
  is_checked      boolean not null default false,
  added_by        uuid not null references public.profiles(id) on delete cascade,
  category_id     uuid references public.categories(id) on delete set null
);

create table public.shopping_templates (
  id           uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  name         text not null,
  items        jsonb not null default '[]'::jsonb
);

-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Habilitar RLS en todas las tablas
alter table public.households           enable row level security;
alter table public.profiles             enable row level security;
alter table public.categories           enable row level security;
alter table public.accounts             enable row level security;
alter table public.transactions         enable row level security;
alter table public.recurring_events     enable row level security;
alter table public.budgets              enable row level security;
alter table public.debts                enable row level security;
alter table public.debt_payments        enable row level security;
alter table public.savings_goals        enable row level security;
alter table public.savings_contributions enable row level security;
alter table public.financial_plans      enable row level security;
alter table public.shopping_lists       enable row level security;
alter table public.shopping_items       enable row level security;
alter table public.shopping_templates   enable row level security;

-- ─── Helper: obtener el household_id del usuario autenticado ──────────────────
create or replace function public.get_my_household_id()
returns uuid
language sql stable
security definer
as $$
  select household_id from public.profiles where id = auth.uid();
$$;

-- ─── POLICIES ─────────────────────────────────────────────────────────────────

-- households
create policy "household_member_select" on public.households
  for select using (id = public.get_my_household_id());

create policy "household_member_update" on public.households
  for update using (id = public.get_my_household_id());

-- profiles (solo tu propio perfil y el del compañero del mismo household)
create policy "profile_select" on public.profiles
  for select using (household_id = public.get_my_household_id());

create policy "profile_insert" on public.profiles
  for insert with check (id = auth.uid());

create policy "profile_update" on public.profiles
  for update using (id = auth.uid());

-- Macro para tables que solo usan household_id
-- categories, accounts, recurring_events, budgets, savings_goals,
-- financial_plans, shopping_lists, shopping_templates

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'categories', 'accounts', 'recurring_events', 'budgets',
    'savings_goals', 'financial_plans', 'shopping_lists', 'shopping_templates'
  ] loop
    execute format(
      'create policy "%s_household_all" on public.%I
       for all using (household_id = public.get_my_household_id())
       with check (household_id = public.get_my_household_id());',
      tbl, tbl
    );
  end loop;
end;
$$;

-- transactions (household_id)
create policy "transactions_household_all" on public.transactions
  for all using (household_id = public.get_my_household_id())
  with check (household_id = public.get_my_household_id());

-- debts (household_id)
create policy "debts_household_all" on public.debts
  for all using (household_id = public.get_my_household_id())
  with check (household_id = public.get_my_household_id());

-- debt_payments (via debt → household)
create policy "debt_payments_household_all" on public.debt_payments
  for all using (
    exists (
      select 1 from public.debts d
      where d.id = debt_id
        and d.household_id = public.get_my_household_id()
    )
  );

-- savings_contributions (via goal → household)
create policy "savings_contributions_household_all" on public.savings_contributions
  for all using (
    exists (
      select 1 from public.savings_goals g
      where g.id = goal_id
        and g.household_id = public.get_my_household_id()
    )
  );

-- shopping_items (via list → household)
create policy "shopping_items_household_all" on public.shopping_items
  for all using (
    exists (
      select 1 from public.shopping_lists sl
      where sl.id = list_id
        and sl.household_id = public.get_my_household_id()
    )
  );

-- =============================================================================
-- REALTIME
-- =============================================================================
-- Habilitar Realtime en tablas colaborativas
-- (hazlo desde el panel de Supabase → Table Editor → Realtime, o con:)

alter publication supabase_realtime add table public.transactions;
alter publication supabase_realtime add table public.shopping_lists;
alter publication supabase_realtime add table public.shopping_items;

-- =============================================================================
-- TRIGGER: crear profile automáticamente al registrarse
-- =============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, name, currency)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'currency', 'USD')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =============================================================================
-- INDEXES (performance)
-- =============================================================================

-- profiles → lookup por household (para RLS helper y join de pareja)
create index idx_profiles_household_id on public.profiles (household_id);

-- categories → lookup por household
create index idx_categories_household_id on public.categories (household_id);

-- accounts → lookup por household y por owner
create index idx_accounts_household_id on public.accounts (household_id);
create index idx_accounts_owner_id      on public.accounts (owner_id);

-- transactions → las queries más frecuentes son:
--   WHERE household_id = ? AND date BETWEEN ? AND ?  (dashboard, reportes)
--   WHERE account_id = ?                             (detalle de cuenta)
--   WHERE category_id = ?                            (filtros, presupuesto)
--   WHERE created_by = ?                             (filtro por persona)
create index idx_transactions_household_date
  on public.transactions (household_id, date desc);

create index idx_transactions_account_id
  on public.transactions (account_id, date desc);

create index idx_transactions_category_id
  on public.transactions (category_id);

create index idx_transactions_created_by
  on public.transactions (created_by);

create index idx_transactions_type
  on public.transactions (household_id, type, date desc);

-- Búsqueda de texto en descripción (search bar de transacciones)
-- pg_trgm debe crearse ANTES del índice que usa gin_trgm_ops
create extension if not exists pg_trgm;
create index idx_transactions_description_trgm
  on public.transactions using gin (description gin_trgm_ops);

-- recurring_events → calendar view filtra por is_active y next_date
create index idx_recurring_events_household_active
  on public.recurring_events (household_id, is_active, next_date);

-- budgets → join con categorías por household
create index idx_budgets_household_id  on public.budgets (household_id);
create index idx_budgets_category_id   on public.budgets (category_id);

-- debts → filtro más común: household + status
create index idx_debts_household_status
  on public.debts (household_id, status);

-- debt_payments → lookup por deuda
create index idx_debt_payments_debt_id on public.debt_payments (debt_id);

-- savings_goals → household + status activo
create index idx_savings_goals_household_status
  on public.savings_goals (household_id, status);

-- savings_contributions → lookup por meta
create index idx_savings_contributions_goal_id
  on public.savings_contributions (goal_id);

-- shopping_lists → household + status abierto
create index idx_shopping_lists_household_status
  on public.shopping_lists (household_id, status);

-- shopping_items → lookup por lista (query más frecuente de Realtime)
create index idx_shopping_items_list_id on public.shopping_items (list_id);

-- financial_plans → household + status
create index idx_financial_plans_household_status
  on public.financial_plans (household_id, status);

-- =============================================================================
-- SEED: Categorías por defecto (se insertan al crear un household)
-- Ejecuta esto DESPUÉS de crear tu primer household con el ID correcto:
-- =============================================================================

-- Ejemplo de insert de categorías (reemplaza 'TU_HOUSEHOLD_ID'):
-- insert into public.categories (household_id, name, icon, color, type) values
--   ('TU_HOUSEHOLD_ID', 'Alimentación',  'restaurant',     '#22C55E', 'expense'),
--   ('TU_HOUSEHOLD_ID', 'Transporte',    'car',            '#3B82F6', 'expense'),
--   ('TU_HOUSEHOLD_ID', 'Hogar',         'home',           '#8B5CF6', 'expense'),
--   ('TU_HOUSEHOLD_ID', 'Salud',         'heart',          '#EF4444', 'expense'),
--   ('TU_HOUSEHOLD_ID', 'Entretenimiento','tv',            '#F59E0B', 'expense'),
--   ('TU_HOUSEHOLD_ID', 'Ropa',          'shirt',          '#EC4899', 'expense'),
--   ('TU_HOUSEHOLD_ID', 'Educación',     'book',           '#06B6D4', 'expense'),
--   ('TU_HOUSEHOLD_ID', 'Sueldo',        'money',          '#22C55E', 'income'),
--   ('TU_HOUSEHOLD_ID', 'Freelance',     'laptop',         '#10B981', 'income'),
--   ('TU_HOUSEHOLD_ID', 'Inversiones',   'chart',          '#6366F1', 'income');

-- =============================================================================
-- STORAGE RLS (avatars)
-- =============================================================================

-- Permitir a cualquier usuario ver los avatars (Public)
create policy "Avatar Public Access"
  on storage.objects for select
  using ( bucket_id = 'avatars' );

-- Permitir a usuarios autenticados subir avatars (insert)
create policy "Avatar Upload Access"
  on storage.objects for insert
  to authenticated
  with check ( bucket_id = 'avatars' );

-- Permitir a los usuarios actualizar/eliminar solo sus propios avatars
create policy "Avatar Update Access"
  on storage.objects for update
  to authenticated
  using ( bucket_id = 'avatars' and auth.uid() = owner );

create policy "Avatar Delete Access"
  on storage.objects for delete
  to authenticated
  using ( bucket_id = 'avatars' and auth.uid() = owner );
