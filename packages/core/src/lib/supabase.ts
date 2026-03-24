import { createClient } from '@supabase/supabase-js';
import type {
  Household, Profile, Category, Account, Transaction,
  RecurringEvent, Budget, Debt, DebtPayment,
  SavingsGoal, SavingsContribution, FinancialPlan,
  ShoppingList, ShoppingItem, ShoppingTemplate,
} from '../types/database';

export interface Database {
  public: {
    Tables: {
      households: { Row: Household; Insert: Omit<Household, 'id' | 'created_at'>; Update: Partial<Omit<Household, 'id'>> };
      profiles: { Row: Profile; Insert: Omit<Profile, 'created_at'>; Update: Partial<Omit<Profile, 'id'>> };
      categories: { Row: Category; Insert: Omit<Category, 'id'>; Update: Partial<Omit<Category, 'id'>> };
      accounts: { Row: Account; Insert: Omit<Account, 'id'>; Update: Partial<Omit<Account, 'id'>> };
      transactions: { Row: Transaction; Insert: Omit<Transaction, 'id'>; Update: Partial<Omit<Transaction, 'id'>> };
      recurring_events: { Row: RecurringEvent; Insert: Omit<RecurringEvent, 'id'>; Update: Partial<Omit<RecurringEvent, 'id'>> };
      budgets: { Row: Budget; Insert: Omit<Budget, 'id'>; Update: Partial<Omit<Budget, 'id'>> };
      debts: { Row: Debt; Insert: Omit<Debt, 'id'>; Update: Partial<Omit<Debt, 'id'>> };
      debt_payments: { Row: DebtPayment; Insert: Omit<DebtPayment, 'id'>; Update: Partial<Omit<DebtPayment, 'id'>> };
      savings_goals: { Row: SavingsGoal; Insert: Omit<SavingsGoal, 'id'>; Update: Partial<Omit<SavingsGoal, 'id'>> };
      savings_contributions: { Row: SavingsContribution; Insert: Omit<SavingsContribution, 'id'>; Update: Partial<Omit<SavingsContribution, 'id'>> };
      financial_plans: { Row: FinancialPlan; Insert: Omit<FinancialPlan, 'id'>; Update: Partial<Omit<FinancialPlan, 'id'>> };
      shopping_lists: { Row: ShoppingList; Insert: Omit<ShoppingList, 'id'>; Update: Partial<Omit<ShoppingList, 'id'>> };
      shopping_items: { Row: ShoppingItem; Insert: Omit<ShoppingItem, 'id'>; Update: Partial<Omit<ShoppingItem, 'id'>> };
      shopping_templates: { Row: ShoppingTemplate; Insert: Omit<ShoppingTemplate, 'id'>; Update: Partial<Omit<ShoppingTemplate, 'id'>> };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}

export function createSupabaseClient(url: string, anonKey: string) {
  return createClient<any>(url, anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
    },
    realtime: {
      params: { eventsPerSecond: 10 },
    },
  });
}

export type SupabaseClient = ReturnType<typeof createSupabaseClient>;
