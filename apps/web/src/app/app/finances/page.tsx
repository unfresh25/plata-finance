import { createClient } from '@/lib/supabase/server';
import { formatCurrency, formatDate } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react';
import { WalletIcon, PiggyBankIcon, MoneyBag01Icon, ShoppingBag01Icon } from '@hugeicons/core-free-icons';

export const metadata = { title: 'Finanzas' };

export default async function FinancesPage() {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user!.id).single();

  if (!profile || !profile.household_id) return null;

  const hid = profile!.household_id!;
  const currency = profile?.currency ?? 'USD';
  const fmt = (n: number) => formatCurrency(n, currency);

  const [{ data: accounts }, { data: goals }, { data: debts }, { data: shopping }] = await Promise.all([
    supabase.from('accounts').select('*').eq('household_id', hid),
    supabase.from('savings_goals').select('*').eq('household_id', hid).eq('status', 'active'),
    supabase.from('debts').select('*').eq('household_id', hid).eq('status', 'active'),
    supabase.from('shopping_lists').select('*').eq('household_id', hid).in('status', ['open', 'shopping']),
  ]);

  const tabs = ['Cuentas', 'Ahorros', 'Deudas', 'Listas'];

  return (
    <div className="max-w-4xl space-y-6 animate-fade-in">
      <h1 className="text-2xl font-bold text-text-primary">Finanzas</h1>

      {/* ─── CUENTAS ─────────────────────────────── */}
      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-text-primary mb-3">
          <HugeiconsIcon icon={WalletIcon} className="w-4 h-4 text-accent" /> Cuentas
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {(accounts ?? []).map(acc => (
            <div key={acc.id} className="card-elevated cursor-pointer hover:border-border-subtle transition-colors">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 rounded-full" style={{ backgroundColor: acc.color }} />
                  <span className="text-xs text-muted capitalize">{acc.type} · {acc.currency}</span>
                </div>
              </div>
              <p className="font-medium text-text-primary">{acc.name}</p>
              <p className="text-2xl font-bold text-text-primary mt-1">{fmt(acc.balance)}</p>
            </div>
          ))}
          <a href="/app/finances/accounts/new" className="card-elevated border-dashed cursor-pointer hover:border-accent/50 hover:bg-accent/5 transition-colors flex items-center justify-center gap-2 text-sm text-muted hover:text-accent h-24">
            + Nueva cuenta
          </a>
        </div>
      </section>

      {/* ─── AHORROS ─────────────────────────────── */}
      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-text-primary mb-3">
          <HugeiconsIcon icon={PiggyBankIcon} className="w-4 h-4 text-success" /> Metas de ahorro
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {(goals ?? []).map(g => {
            const pct = g.target_amount > 0 ? Math.min(100, Math.round((g.current_amount / g.target_amount) * 100)) : 0;
            return (
              <div key={g.id} className="card cursor-pointer">
                <div className="flex items-center gap-3 mb-3">
                  <div className="w-9 h-9 rounded-xl flex items-center justify-center text-base" style={{ backgroundColor: `${g.color}20` }}>
                    {g.icon}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-text-primary">{g.name}</p>
                    {g.deadline && <p className="text-xs text-muted">Vence: {formatDate(g.deadline)}</p>}
                  </div>
                  <span className="ml-auto text-xs font-bold text-success">{pct}%</span>
                </div>
                <div className="progress-bar mb-1">
                  <div className="progress-fill bg-success" style={{ width: `${pct}%` }} />
                </div>
                <div className="flex justify-between text-xs text-muted mt-2">
                  <span>{fmt(g.current_amount)} ahorrado</span>
                  <span>Meta: {fmt(g.target_amount)}</span>
                </div>
              </div>
            );
          })}
          {(!goals || goals.length === 0) && (
            <p className="text-sm text-muted card py-8 text-center col-span-2">Sin metas activas</p>
          )}
        </div>
      </section>

      {/* ─── DEUDAS ──────────────────────────────── */}
      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-text-primary mb-3">
          <HugeiconsIcon icon={MoneyBag01Icon} className="w-4 h-4 text-warning" /> Deudas
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {[
            { label: 'Nos deben', items: (debts ?? []).filter(d => d.direction === 'owed_to_us'), color: 'text-success' },
            { label: 'Debemos', items: (debts ?? []).filter(d => d.direction === 'we_owe'), color: 'text-danger' },
          ].map(({ label, items, color }) => (
            <div key={label} className="card">
              <p className="text-xs font-semibold text-muted uppercase mb-3">{label}</p>
              {items.length === 0 ? (
                <p className="text-sm text-muted py-2">Ninguna</p>
              ) : items.map(d => (
                <div key={d.id} className="flex items-center justify-between py-2 border-b border-border last:border-0">
                  <div>
                    <p className="text-sm font-medium text-text-primary">{d.person_name}</p>
                    {d.due_date && <p className="text-xs text-muted">Vence: {formatDate(d.due_date)}</p>}
                  </div>
                  <p className={`text-sm font-semibold ${color}`}>{fmt(d.amount - d.amount_paid)}</p>
                </div>
              ))}
            </div>
          ))}
        </div>
      </section>

      {/* ─── LISTAS DE COMPRAS ───────────────────── */}
      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-text-primary mb-3">
          <HugeiconsIcon icon={ShoppingBag01Icon} className="w-4 h-4 text-warning" /> Listas de compras activas
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
          {(shopping ?? []).map(sl => (
            <a key={sl.id} href={`/app/finances/shopping/${sl.id}`} className="card cursor-pointer hover:border-border-subtle transition-colors">
              <p className="font-medium text-text-primary">{sl.name}</p>
              {sl.store && <p className="text-xs text-muted mt-0.5">{sl.store}</p>}
              <div className="flex items-center justify-between mt-3">
                <span className={`badge ${sl.status === 'shopping' ? 'badge-warning' : 'badge-muted'}`}>
                  {sl.status === 'shopping' ? 'Comprando' : 'Abierta'}
                </span>
                {sl.estimated_total && (
                  <p className="text-xs text-muted">{fmt(sl.estimated_total)}</p>
                )}
              </div>
            </a>
          ))}
          <a href="/app/finances/shopping/new" className="card border-dashed cursor-pointer hover:border-accent/50 hover:bg-accent/5 transition-colors flex items-center justify-center gap-2 text-sm text-muted hover:text-accent h-20">
            + Nueva lista
          </a>
        </div>
      </section>
    </div>
  );
}
