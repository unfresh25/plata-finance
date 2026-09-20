-- v9 — Resumen semanal generado por IA, cacheado por hogar/semana.
-- El backend (service_role) genera y hace upsert; la app lo lee bajo RLS.

create table if not exists public.weekly_summaries (
  id uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  week_start date not null,            -- lunes ISO de la semana
  week_end date not null,              -- domingo
  summary_text text not null,
  model text not null default 'claude-haiku-4-5',
  currency char(3) not null default 'COP',
  generated_at timestamptz not null default now(),
  unique (household_id, week_start)     -- idempotencia + soporta upsert
);

create index if not exists idx_weekly_summaries_hh_week
  on public.weekly_summaries (household_id, week_start desc);

alter table public.weekly_summaries enable row level security;

create policy "weekly_summaries_household_select" on public.weekly_summaries
  for select using (household_id = public.get_my_household_id());
