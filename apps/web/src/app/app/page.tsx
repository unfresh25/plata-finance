import { createClient } from '@/lib/supabase/server';
import { formatCurrency, formatShortDate, monthRange, percentage, budgetStatus } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react';
import {
  Home01Icon,
  Wallet01Icon,
  ArrowUp01Icon,
  ArrowDown01Icon,
  SparklesIcon,
  ArrowRight01Icon,
} from '@hugeicons/core-free-icons';

export const metadata = { title: 'Inicio' };

export default async function DashboardPage() {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('*, households(*)')
    .eq('id', user!.id)
    .single();

  if (!profile || !profile.household_id) return null;

  const { start, end } = monthRange();

  const [{ data: transactions }, { data: accounts }, { data: recurring }, { data: budgets }, { data: categories }] = await Promise.all([
    supabase.from('transactions').select('*').eq('household_id', profile!.household_id!).gte('date', start).lte('date', end).order('date', { ascending: false }),
    supabase.from('accounts').select('*').eq('household_id', profile!.household_id!),
    supabase.from('recurring_events').select('*').eq('household_id', profile!.household_id!).eq('is_active', true).order('next_date').limit(5),
    supabase.from('budgets').select('*').eq('household_id', profile!.household_id!),
    supabase.from('categories').select('*').eq('household_id', profile!.household_id!),
  ]);

  const currency = profile?.currency ?? 'USD';
  const fmt = (n: number) => formatCurrency(n, currency);

  const totalBalance = (accounts ?? []).reduce((s, a) => s + a.balance, 0);
  const income = (transactions ?? []).filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
  const expenses = (transactions ?? []).filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
  const recent = (transactions ?? []).slice(0, 5);

  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Buenos días' : hour < 19 ? 'Buenas tardes' : 'Buenas noches';
  const firstName = profile?.name?.split(' ')[0] ?? '';

  return (
    <div className="space-y-6 max-w-5xl animate-fade-in">
      {/* Greeting */}
      <div>
        <h1 className="text-2xl font-bold text-text-primary">{greeting}, {firstName} 👋</h1>
        <p className="text-text-secondary text-sm mt-0.5">Resumen de {new Intl.DateTimeFormat('es', { month: 'long', year: 'numeric' }).format(new Date())}</p>
      </div>

      {/* Balance hero */}
      <div className="card bg-gradient-to-br from-bg-surface to-bg-elevated relative overflow-hidden">
        <div className="absolute top-0 right-0 w-32 h-32 bg-accent/10 rounded-full blur-2xl -translate-y-6 translate-x-6" />
        <p className="text-text-muted text-sm">Balance total</p>
        <p className="text-4xl font-bold text-text-primary mt-1">{fmt(totalBalance)}</p>
        <div className="flex gap-6 mt-4">
          <div className="flex items-center gap-2">
            <HugeiconsIcon icon={ArrowUp01Icon} className="w-4 h-4 text-success" />
            <div>
              <p className="text-xs text-muted">Ingresos</p>
              <p className="text-sm font-semibold text-success">{fmt(income)}</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <HugeiconsIcon icon={ArrowDown01Icon} className="w-4 h-4 text-danger" />
            <div>
              <p className="text-xs text-muted">Gastos</p>
              <p className="text-sm font-semibold text-danger">{fmt(expenses)}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Accounts horizontal scroll */}
      {accounts && accounts.length > 0 && (
        <div>
          <h2 className="text-base font-semibold text-text-primary mb-3 flex items-center gap-2">
            <HugeiconsIcon icon={Wallet01Icon} className="w-4 h-4 text-accent" /> Cuentas
          </h2>
          <div className="flex gap-3 overflow-x-auto pb-2">
            {accounts.map(acc => (
              <div key={acc.id} className="card-elevated shrink-0 w-44">
                <div className="flex items-center gap-2 mb-2">
                  <div className="w-3 h-3 rounded-full" style={{ backgroundColor: acc.color }} />
                  <span className="text-xs text-muted capitalize">{acc.type}</span>
                </div>
                <p className="text-sm font-medium text-text-primary truncate">{acc.name}</p>
                <p className="text-lg font-bold text-text-primary">{fmt(acc.balance)}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Recent transactions */}
        <div>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-base font-semibold text-text-primary">Últimas transacciones</h2>
            <a href="/app/transactions" className="text-xs text-accent hover:text-accent-hover flex items-center gap-1 cursor-pointer">
              Ver todas <HugeiconsIcon icon={ArrowRight01Icon} className="w-3 h-3" />
            </a>
          </div>
          <div className="card space-y-1">
            {recent.length === 0 ? (
              <p className="text-sm text-muted py-4 text-center">Sin transacciones este mes</p>
            ) : recent.map(tx => {
              const cat = categories?.find(c => c.id === tx.category_id);
              return (
                <div key={tx.id} className="flex items-center justify-between py-2.5 border-b border-border last:border-0">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-xl flex items-center justify-center text-sm" style={{ backgroundColor: `${cat?.color ?? '#3F3F46'}20` }}>
                      {cat?.icon ?? '•'}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-text-primary">{tx.description ?? cat?.name ?? '—'}</p>
                      <p className="text-xs text-muted">{formatShortDate(tx.date)}</p>
                    </div>
                  </div>
                  <p className={`text-sm font-semibold ${tx.type === 'income' ? 'text-success' : 'text-text-primary'}`}>
                    {tx.type === 'income' ? '+' : '-'}{fmt(tx.amount)}
                  </p>
                </div>
              );
            })}
          </div>
        </div>

        {/* Upcoming recurring */}
        <div>
          <h2 className="text-base font-semibold text-text-primary mb-3">Próximos pagos</h2>
          <div className="card space-y-1">
            {(!recurring || recurring.length === 0) ? (
              <p className="text-sm text-muted py-4 text-center">Sin eventos próximos</p>
            ) : recurring.map(ev => (
              <div key={ev.id} className="flex items-center justify-between py-2.5 border-b border-border last:border-0">
                <div>
                  <p className="text-sm font-medium text-text-primary">{ev.name}</p>
                  <p className="text-xs text-muted">{formatShortDate(ev.next_date)} · {ev.frequency}</p>
                </div>
                <p className="text-sm font-semibold text-danger">-{fmt(ev.amount)}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* AI widget placeholder */}
      <div className="card border-accent/20 bg-gradient-to-r from-accent/5 to-transparent">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-accent/20 flex items-center justify-center">
            <HugeiconsIcon icon={SparklesIcon} className="w-4 h-4 text-accent" />
          </div>
          <div>
            <p className="text-sm font-medium text-text-primary">Análisis IA</p>
            <p className="text-xs text-muted">Las predicciones estarán disponibles cuando tengas más transacciones.</p>
          </div>
          <a href="/app/reports" className="ml-auto btn-ghost text-xs whitespace-nowrap">Ver reportes</a>
        </div>
      </div>
    </div>
  );
}
