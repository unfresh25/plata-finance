-- v11 — Historial de liquidaciones entre la pareja.
-- Cada fila registra que 'from_user' le pagó a 'to_user' un monto, en una fecha.
-- El saldo pendiente = (mitades de gastos compartidos) − (liquidaciones ya hechas).

create table if not exists public.settlements (
  id uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  from_user uuid not null references public.profiles(id) on delete cascade,
  to_user uuid not null references public.profiles(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_settlements_hh on public.settlements (household_id, created_at desc);

alter table public.settlements enable row level security;

create policy "settlements_household_all" on public.settlements
  for all using (household_id = public.get_my_household_id())
  with check (household_id = public.get_my_household_id());
