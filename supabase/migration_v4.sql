-- Migration v4: Automated Savings Goals
-- Run this in your Supabase SQL Editor

-- 1. Allow recurring_events to be linked to a specific savings_goal (for automatic goal tracking)
alter table public.recurring_events
  add column if not exists savings_goal_id uuid references public.savings_goals(id) on delete cascade;

-- 2. Allow transactions (payments) to explicitly track which savings goal they contribute to
alter table public.transactions
  add column if not exists savings_goal_id uuid references public.savings_goals(id) on delete cascade;
