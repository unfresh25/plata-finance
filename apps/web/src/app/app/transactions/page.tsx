import { createClient } from '@/lib/supabase/server';
import { formatCurrency, formatDate, monthRange } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react';
import { FilterIcon, SearchIcon } from '@hugeicons/core-free-icons';

export const metadata = { title: 'Movimientos' };

export default async function TransactionsPage({
  searchParams,
}: {
  searchParams: { month?: string; type?: string; category?: string };
}) {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user!.id).single();

  if (!profile || !profile.household_id) return null;

  const { start, end } = monthRange(
    searchParams.month ? new Date(searchParams.month + '-01') : new Date()
  );

  let query = supabase
    .from('transactions')
    .select('*, categories(*), accounts(*), profiles!created_by(name, avatar_url)')
    .eq('household_id', profile!.household_id!)
    .gte('date', start)
    .lte('date', end)
    .order('date', { ascending: false });

  if (searchParams.type && searchParams.type !== 'all') {
    query = query.eq('type', searchParams.type as 'income' | 'expense' | 'transfer');
  }

  const { data: transactions } = await query;
  const { data: categories } = await supabase.from('categories').select('*').eq('household_id', profile!.household_id!);
  const currency = profile?.currency ?? 'USD';

  const income = (transactions ?? []).filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
  const expenses = (transactions ?? []).filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

  // Group by date
  const grouped: Record<string, typeof transactions> = {};
  for (const tx of transactions ?? []) {
    const day = tx.date;
    if (!grouped[day]) grouped[day] = [];
    grouped[day]!.push(tx);
  }

  return (
    <div className="max-w-3xl space-y-5 animate-fade-in">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-text-primary">Movimientos</h1>
        <div className="flex gap-2">
          <button className="btn-secondary flex items-center gap-2 text-sm" id="filter-btn">
            <HugeiconsIcon icon={FilterIcon} className="w-4 h-4" /> Filtrar
          </button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-2 gap-3">
        <div className="card-elevated">
          <p className="text-xs text-muted mb-1">Ingresos</p>
          <p className="text-xl font-bold text-success">+{formatCurrency(income, currency)}</p>
        </div>
        <div className="card-elevated">
          <p className="text-xs text-muted mb-1">Gastos</p>
          <p className="text-xl font-bold text-danger">-{formatCurrency(expenses, currency)}</p>
        </div>
      </div>

      {/* Search */}
      <div className="relative">
        <HugeiconsIcon icon={SearchIcon} className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
        <input className="input pl-9" placeholder="Buscar transacción..." id="tx-search" />
      </div>

      {/* Type tabs */}
      <div className="flex gap-1 p-1 bg-bg-elevated rounded-xl w-fit">
        {[{ key: 'all', label: 'Todos' }, { key: 'expense', label: 'Gastos' }, { key: 'income', label: 'Ingresos' }, { key: 'transfer', label: 'Transferencias' }].map(({ key, label }) => (
          <a
            key={key}
            href={`/app/transactions${key !== 'all' ? `?type=${key}` : ''}`}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium cursor-pointer transition-colors ${
              (searchParams.type ?? 'all') === key
                ? 'bg-bg-surface text-text-primary shadow-sm'
                : 'text-muted hover:text-text-secondary'
            }`}
          >
            {label}
          </a>
        ))}
      </div>

      {/* Transaction list grouped by day */}
      {Object.keys(grouped).length === 0 ? (
        <div className="card py-16 text-center">
          <p className="text-muted">Sin transacciones este mes</p>
          <p className="text-xs text-muted mt-1">Usa el botón + para agregar</p>
        </div>
      ) : (
        <div className="space-y-6">
          {Object.entries(grouped).sort(([a], [b]) => b.localeCompare(a)).map(([date, txs]) => (
            <div key={date}>
              <p className="text-xs font-semibold text-muted uppercase tracking-wide mb-2">{formatDate(date)}</p>
              <div className="card space-y-0 divide-y divide-border">
                {txs!.map(tx => {
                  const cat = (tx as { categories?: { name: string; icon: string; color: string } }).categories;
                  return (
                    <div key={tx.id} className="flex items-center gap-3 py-3 hover:bg-bg-elevated transition-colors cursor-pointer px-1 rounded-lg">
                      <div
                        className="w-9 h-9 rounded-xl flex items-center justify-center text-sm shrink-0"
                        style={{ backgroundColor: `${cat?.color ?? '#3F3F46'}20` }}
                      >
                        {cat?.icon ?? '•'}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-text-primary truncate">{tx.description ?? cat?.name ?? '—'}</p>
                        <p className="text-xs text-muted">{cat?.name} · {(tx as { profiles?: { name: string } }).profiles?.name}</p>
                      </div>
                      <p className={`text-sm font-semibold shrink-0 ${tx.type === 'income' ? 'text-success' : 'text-text-primary'}`}>
                        {tx.type === 'income' ? '+' : '-'}{formatCurrency(tx.amount, currency)}
                      </p>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
