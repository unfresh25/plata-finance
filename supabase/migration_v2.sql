-- Migration: add invite_code to households, fix budgets/debts/recurring columns
-- Run this in your Supabase SQL Editor

-- 1. Add invite_code to households (unique, optional)
alter table public.households
  add column if not exists invite_code text unique;

-- 2. The budgets table in schema uses amount + period + start_date.
--    We adapt the app code to match. No schema changes needed for budgets.

-- 3. The debts table uses direction (owed_to_us / we_owe) + amount + amount_paid.
--    We adapt the app code. No schema changes needed.

-- 4. recurring_events missing type column (income/expense) — add it
alter table public.recurring_events
  add column if not exists type text not null default 'expense' check (type in ('income', 'expense'));

-- 5. recurring_events missing day_of_month
alter table public.recurring_events
  add column if not exists day_of_month integer check (day_of_month between 1 and 31);

-- 6. shopping_lists: add budget column alias (estimated_total already exists)
--    No change needed — we'll use estimated_total.

-- 7. savings_contributions: missing contributed_at column — it uses "date"
alter table public.savings_contributions
  add column if not exists contributed_at timestamptz; -- nullable fallback; real col is "date"

-- 8. debt_payments: add paid_at column (schema uses "date")
--    No schema change needed — we'll use "date"

-- 9. Ensure RLS policy allows insert on households for authenticated users
drop policy if exists "users can insert households" on public.households;
create policy "users can insert households"
  on public.households
  for insert
  to authenticated
  with check (true);

-- 10. Ensure RLS allows select on households (for invite code lookup)
drop policy if exists "users can select households" on public.households;
create policy "users can select households"
  on public.households
  for select
  to authenticated
  using (true);

-- 11. Allow users to update households they belong to (for invite_code)
drop policy if exists "members can update their household" on public.households;
create policy "members can update their household"
  on public.households
  for update
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where profiles.id = auth.uid()
      and profiles.household_id = households.id
    )
  );
