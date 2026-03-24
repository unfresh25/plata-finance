// Database types matching Supabase schema

export type UserId = string;
export type HouseholdId = string;
export type CategoryId = string;
export type AccountId = string;
export type TransactionId = string;

// ─── Household ───────────────────────────────────────────────────────────────

export interface Household {
  id: HouseholdId;
  name: string;
  created_at: string;
}

// ─── Profile ─────────────────────────────────────────────────────────────────

export interface Profile {
  id: UserId;
  household_id: HouseholdId;
  name: string;
  avatar_url: string | null;
  currency: string; // ISO 4217 e.g. 'COP', 'USD', 'MXN'
  created_at: string;
}

// ─── Category ────────────────────────────────────────────────────────────────

export type CategoryType = 'income' | 'expense';

export interface Category {
  id: CategoryId;
  household_id: HouseholdId;
  name: string;
  icon: string;
  color: string;
  type: CategoryType;
}

// ─── Account ─────────────────────────────────────────────────────────────────

export type AccountType = 'debit' | 'credit' | 'cash' | 'savings';

export interface Account {
  id: AccountId;
  household_id: HouseholdId;
  owner_id: UserId;
  name: string;
  type: AccountType;
  balance: number;
  currency: string;
  color: string;
  icon: string;
}

// ─── Transaction ─────────────────────────────────────────────────────────────

export type TransactionType = 'income' | 'expense' | 'transfer';

export interface Transaction {
  id: TransactionId;
  account_id: AccountId;
  household_id: HouseholdId;
  created_by: UserId;
  amount: number;
  type: TransactionType;
  category_id: CategoryId | null;
  description: string | null;
  date: string; // ISO date string
  is_recurring: boolean;
  recurring_id: string | null;
}

// ─── Recurring Events ─────────────────────────────────────────────────────────

export type Frequency = 'daily' | 'weekly' | 'monthly' | 'yearly';

export interface RecurringEvent {
  id: string;
  household_id: HouseholdId;
  name: string;
  amount: number;
  frequency: Frequency;
  next_date: string;
  category_id: CategoryId | null;
  account_id: AccountId | null;
  is_active: boolean;
}

// ─── Budget ───────────────────────────────────────────────────────────────────

export type BudgetPeriod = 'weekly' | 'monthly';

export interface Budget {
  id: string;
  household_id: HouseholdId;
  category_id: CategoryId;
  amount: number;
  period: BudgetPeriod;
  start_date: string;
}

// ─── Debts ────────────────────────────────────────────────────────────────────

export type DebtDirection = 'owed_to_us' | 'we_owe';
export type DebtStatus = 'active' | 'paid';

export interface Debt {
  id: string;
  household_id: HouseholdId;
  created_by: UserId;
  direction: DebtDirection;
  person_name: string;
  amount: number;
  amount_paid: number;
  due_date: string | null;
  description: string | null;
  status: DebtStatus;
}

export interface DebtPayment {
  id: string;
  debt_id: string;
  amount: number;
  date: string;
  note: string | null;
}

// ─── Savings Goals ────────────────────────────────────────────────────────────

export type GoalStatus = 'active' | 'completed' | 'cancelled';

export interface SavingsGoal {
  id: string;
  household_id: HouseholdId;
  name: string;
  target_amount: number;
  current_amount: number;
  deadline: string | null;
  icon: string;
  color: string;
  account_id: AccountId | null;
  status: GoalStatus;
}

export interface SavingsContribution {
  id: string;
  goal_id: string;
  created_by: UserId;
  amount: number;
  date: string;
  note: string | null;
}

// ─── Financial Plans ──────────────────────────────────────────────────────────

export type PlanType = 'debt_payoff' | 'savings' | 'budget';
export type PlanStatus = 'active' | 'completed' | 'cancelled';

export interface FinancialPlan {
  id: string;
  household_id: HouseholdId;
  name: string;
  type: PlanType;
  target_amount: number;
  monthly_contribution: number;
  start_date: string;
  end_date: string | null;
  status: PlanStatus;
  linked_id: string | null;
}

// ─── Shopping ─────────────────────────────────────────────────────────────────

export type ListStatus = 'open' | 'shopping' | 'completed';

export interface ShoppingList {
  id: string;
  household_id: HouseholdId;
  created_by: UserId;
  name: string;
  store: string | null;
  estimated_total: number | null;
  actual_total: number | null;
  status: ListStatus;
  date: string;
  category_id: CategoryId | null;
}

export interface ShoppingItem {
  id: string;
  list_id: string;
  name: string;
  quantity: number;
  unit: string | null;
  estimated_price: number | null;
  actual_price: number | null;
  is_checked: boolean;
  added_by: UserId;
  category_id: CategoryId | null;
}

export interface ShoppingTemplate {
  id: string;
  household_id: HouseholdId;
  name: string;
  items: Array<{
    name: string;
    quantity: number;
    unit: string | null;
    estimated_price: number | null;
  }>;
}

// ─── AI / Predictions ─────────────────────────────────────────────────────────

export interface MonthlyPrediction {
  month: string; // 'YYYY-MM'
  predicted_spend: number;
  actual_spend: number | null;
  confidence: number; // 0-1
}

export interface CategoryPrediction {
  category_id: CategoryId;
  category_name: string;
  predicted_spend: number;
  trend: 'up' | 'down' | 'stable';
}

export interface AIInsight {
  type: 'alert' | 'tip' | 'report';
  message: string;
  related_category?: CategoryId;
  created_at: string;
}


