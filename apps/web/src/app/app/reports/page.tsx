import { createClient } from '@/lib/supabase/server';
import { formatCurrency, monthRange } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react';
import { SparklesIcon, ChartLineData01Icon, PieChart01Icon } from '@hugeicons/core-free-icons';

export const metadata = { title: 'Reportes' };

export default async function ReportsPage() {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user!.id).single();

  if (!profile || !profile.household_id) return null;

  const hid = profile!.household_id!;
  const currency = profile?.currency ?? 'USD';
  const fmt = (n: number) => formatCurrency(n, currency);

  const { start, end } = monthRange();

  const [{ data: transactions }, { data: categories }, { data: budgets }] = await Promise.all([
    supabase.from('transactions').select('*, categories(*)').eq('household_id', hid).gte('date', start).lte('date', end),
    supabase.from('categories').select('*').eq('household_id', hid),
    supabase.from('budgets').select('*, categories(*)').eq('household_id', hid),
  ]);

  // Spend by category
  const byCategory: Record<string, { name: string; color: string; icon: string; total: number; budget?: number }> = {};
  for (const tx of (transactions ?? []).filter(t => t.type === 'expense')) {
    const cat = (tx as { categories?: { id: string; name: string; color: string; icon: string } }).categories;
    if (!cat) continue;
    if (!byCategory[cat.id]) byCategory[cat.id] = { name: cat.name, color: cat.color, icon: cat.icon, total: 0 };
    byCategory[cat.id]!.total += tx.amount;
  }

  // Add budget info
  for (const b of budgets ?? []) {
    const cat = (b as { categories?: { id: string } }).categories;
    if (!cat) continue;
    if (byCategory[cat.id]) byCategory[cat.id]!.budget = b.amount;
  }

  const categoryList = Object.entries(byCategory).sort(([, a], [, b]) => b.total - a.total);
  const totalExpenses = categoryList.reduce((s, [, v]) => s + v.total, 0);

  return (
    <div className="max-w-4xl space-y-6 animate-fade-in">
      <h1 className="text-2xl font-bold text-text-primary">Reportes</h1>

      {/* AI Report */}
      <div className="card border-accent/20 bg-gradient-to-r from-accent/5 to-transparent">
        <div className="flex items-center gap-3 mb-2">
          <HugeiconsIcon icon={SparklesIcon} className="w-5 h-5 text-accent" />
          <p className="font-semibold text-text-primary">Análisis del mes (IA)</p>
        </div>
        <p className="text-sm text-text-secondary">
          El análisis narrativo con Gemma estará disponible cuando tengas al menos 10 transacciones este mes.
        </p>
      </div>

      {/* Spend by category */}
      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-text-primary mb-4">
          <HugeiconsIcon icon={PieChart01Icon} className="w-4 h-4 text-accent" /> Gastos por categoría
        </h2>
        {categoryList.length === 0 ? (
          <p className="text-sm text-muted card py-8 text-center">Sin gastos este mes</p>
        ) : (
          <div className="space-y-3">
            {categoryList.map(([id, cat]) => {
              const pct = totalExpenses > 0 ? Math.round((cat.total / totalExpenses) * 100) : 0;
              const budgetPct = cat.budget ? Math.min(100, Math.round((cat.total / cat.budget) * 100)) : null;
              const budgetColor = budgetPct === null ? '' : budgetPct >= 100 ? 'bg-danger' : budgetPct >= 80 ? 'bg-warning' : 'bg-success';
              return (
                <div key={id} className="card-elevated">
                  <div className="flex items-center gap-3 mb-2">
                    <div className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ backgroundColor: `${cat.color}20` }}>
                      <span className="text-sm">{cat.icon}</span>
                    </div>
                    <div className="flex-1">
                      <div className="flex justify-between">
                        <span className="text-sm font-medium text-text-primary">{cat.name}</span>
                        <span className="text-sm font-semibold text-text-primary">{fmt(cat.total)}</span>
                      </div>
                      {cat.budget && (
                        <p className="text-xs text-muted">Presupuesto: {fmt(cat.budget)} ({budgetPct}%)</p>
                      )}
                    </div>
                  </div>
                  {cat.budget ? (
                    <div className="progress-bar">
                      <div className={`progress-fill ${budgetColor}`} style={{ width: `${budgetPct}%` }} />
                    </div>
                  ) : (
                    <div className="progress-bar">
                      <div className="progress-fill bg-accent/60" style={{ width: `${pct}%` }} />
                    </div>
                  )}
                  <p className="text-xs text-muted mt-1">{pct}% del total de gastos</p>
                </div>
              );
            })}
          </div>
        )}
      </section>

      {/* Predictions placeholder */}
      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-text-primary mb-4">
          <HugeiconsIcon icon={ChartLineData01Icon} className="w-4 h-4 text-accent" /> Predicciones (Prophet)
        </h2>
        <div className="card py-16 text-center">
          <p className="text-muted text-sm">Necesitas al menos 3 meses de historial para activar las predicciones.</p>
        </div>
      </section>
    </div>
  );
}
