-- Migration v3: Enhanced Debts System
-- Run this in your Supabase SQL Editor

-- 1. Add optional category to debts
alter table public.debts
  add column if not exists category_id uuid references public.categories(id) on delete set null;

-- 2. Allow recurring_events to be linked to a specific debt (for automatic debt tracking)
alter table public.recurring_events
  add column if not exists debt_id uuid references public.debts(id) on delete cascade;

-- 3. Allow transactions (payments) to explicitly track which debt they reduce
alter table public.transactions
  add column if not exists debt_id uuid references public.debts(id) on delete cascade;
