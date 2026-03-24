import { createClient } from '@/lib/supabase/server';
import { formatDate, formatCurrency, monthRange } from '@jojos/core';
import { HugeiconsIcon } from '@hugeicons/react';
import { Calendar01Icon } from '@hugeicons/core-free-icons';

export const metadata = { title: 'Calendario' };

export default async function CalendarPage() {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user!.id).single();

  if (!profile || !profile.household_id) return null;

  const hid = profile!.household_id!;
  const currency = profile?.currency ?? 'USD';
  const fmt = (n: number) => formatCurrency(n, currency);

  const { start } = monthRange();

  const { data: recurring } = await supabase
    .from('recurring_events')
    .select('*, categories(*)')
    .eq('household_id', hid)
    .eq('is_active', true)
    .order('next_date');

  const monthLabel = new Intl.DateTimeFormat('es', { month: 'long', year: 'numeric' }).format(new Date());
  const totalUpcoming = (recurring ?? []).reduce((s, e) => s + e.amount, 0);

  return (
    <div className="max-w-3xl space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-text-primary">Calendario</h1>
        <span className="text-sm text-muted capitalize">{monthLabel}</span>
      </div>

      {/* Monthly summary */}
      <div className="card bg-gradient-to-br from-bg-surface to-bg-elevated">
        <p className="text-xs text-muted mb-1">Cobros recurrentes del mes</p>
        <p className="text-3xl font-bold text-danger">-{fmt(totalUpcoming)}</p>
        <p className="text-xs text-muted mt-1">{recurring?.length ?? 0} eventos activos</p>
      </div>

      {/* Upcoming list */}
      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-text-primary mb-3">
          <HugeiconsIcon icon={Calendar01Icon} className="w-4 h-4 text-accent" /> Próximos eventos
        </h2>
        {(!recurring || recurring.length === 0) ? (
          <div className="card py-12 text-center">
            <p className="text-muted text-sm">No hay eventos recurrentes registrados.</p>
            <p className="text-xs text-muted mt-1">Agrega suscripciones, arriendos y servicios.</p>
          </div>
        ) : (
          <div className="space-y-2">
            {recurring.map(ev => {
              const cat = (ev as { categories?: { name: string; icon: string; color: string } }).categories;
              const daysUntil = Math.ceil((new Date(ev.next_date).getTime() - Date.now()) / 86400000);
              const urgency = daysUntil <= 3 ? 'text-danger' : daysUntil <= 7 ? 'text-warning' : 'text-muted';
              return (
                <div key={ev.id} className="card-elevated flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl flex items-center justify-center text-sm shrink-0" style={{ backgroundColor: `${cat?.color ?? '#3F3F46'}20` }}>
                    {cat?.icon ?? '📅'}
                  </div>
                  <div className="flex-1">
                    <p className="text-sm font-medium text-text-primary">{ev.name}</p>
                    <p className="text-xs text-muted">{formatDate(ev.next_date)} · {ev.frequency}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-semibold text-danger">-{fmt(ev.amount)}</p>
                    <p className={`text-xs ${urgency}`}>
                      {daysUntil === 0 ? 'Hoy' : daysUntil < 0 ? 'Vencido' : `en ${daysUntil}d`}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}
