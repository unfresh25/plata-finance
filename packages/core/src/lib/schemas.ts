import { z } from 'zod';

// ─── Transaction ──────────────────────────────────────────────────────────────

export const transactionSchema = z.object({
  account_id: z.string().uuid(),
  amount: z.number().positive('Amount must be positive'),
  type: z.enum(['income', 'expense', 'transfer']),
  category_id: z.string().uuid().nullable(),
  description: z.string().max(500).nullable(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD format'),
  is_recurring: z.boolean().default(false),
  recurring_id: z.string().uuid().nullable().default(null),
});

export type TransactionInput = z.infer<typeof transactionSchema>;

// ─── Account ─────────────────────────────────────────────────────────────────

export const accountSchema = z.object({
  name: z.string().min(1).max(100),
  type: z.enum(['debit', 'credit', 'cash', 'savings']),
  balance: z.number().default(0),
  currency: z.string().length(3, 'Use ISO 4217 code (e.g. USD)'),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  icon: z.string().min(1),
});

export type AccountInput = z.infer<typeof accountSchema>;

// ─── Budget ───────────────────────────────────────────────────────────────────

export const budgetSchema = z.object({
  category_id: z.string().uuid(),
  amount: z.number().positive(),
  period: z.enum(['weekly', 'monthly']),
  start_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

export type BudgetInput = z.infer<typeof budgetSchema>;

// ─── Savings Goal ─────────────────────────────────────────────────────────────

export const savingsGoalSchema = z.object({
  name: z.string().min(1).max(100),
  target_amount: z.number().positive(),
  current_amount: z.number().min(0).default(0),
  deadline: z.string().nullable().default(null),
  icon: z.string().min(1),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  account_id: z.string().uuid().nullable().default(null),
});

export type SavingsGoalInput = z.infer<typeof savingsGoalSchema>;

// ─── Debt ─────────────────────────────────────────────────────────────────────

export const debtSchema = z.object({
  direction: z.enum(['owed_to_us', 'we_owe']),
  person_name: z.string().min(1).max(100),
  amount: z.number().positive(),
  due_date: z.string().nullable().default(null),
  description: z.string().max(500).nullable().default(null),
});

export type DebtInput = z.infer<typeof debtSchema>;

// ─── Shopping List ────────────────────────────────────────────────────────────

export const shoppingListSchema = z.object({
  name: z.string().min(1).max(100),
  store: z.string().max(100).nullable().default(null),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  category_id: z.string().uuid().nullable().default(null),
});

export type ShoppingListInput = z.infer<typeof shoppingListSchema>;

export const shoppingItemSchema = z.object({
  name: z.string().min(1).max(200),
  quantity: z.number().positive().default(1),
  unit: z.string().max(20).nullable().default(null),
  estimated_price: z.number().min(0).nullable().default(null),
});

export type ShoppingItemInput = z.infer<typeof shoppingItemSchema>;

// ─── Recurring Event ──────────────────────────────────────────────────────────

export const recurringEventSchema = z.object({
  name: z.string().min(1).max(100),
  amount: z.number().positive(),
  frequency: z.enum(['daily', 'weekly', 'monthly', 'yearly']),
  next_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  category_id: z.string().uuid().nullable().default(null),
  account_id: z.string().uuid().nullable().default(null),
});

export type RecurringEventInput = z.infer<typeof recurringEventSchema>;

// ─── Profile ─────────────────────────────────────────────────────────────────

export const profileSchema = z.object({
  name: z.string().min(1).max(100),
  currency: z.string().length(3),
  avatar_url: z.string().url().nullable().default(null),
});

export type ProfileInput = z.infer<typeof profileSchema>;
