import { format, formatDistanceToNow, parseISO, isAfter, isBefore, addDays, addMonths, startOfMonth, endOfMonth } from 'date-fns';
import { enUS, es } from 'date-fns/locale';

type Locale = 'es' | 'en';

const LOCALES = { es, en: enUS };

// ─── Currency ─────────────────────────────────────────────────────────────────

export const SUPPORTED_CURRENCIES = [
  { code: 'COP', name: 'Peso colombiano', symbol: '$' },
  { code: 'MXN', name: 'Peso mexicano', symbol: '$' },
  { code: 'USD', name: 'US Dollar', symbol: '$' },
  { code: 'EUR', name: 'Euro', symbol: '€' },
  { code: 'ARS', name: 'Peso argentino', symbol: '$' },
  { code: 'BRL', name: 'Real brasileiro', symbol: 'R$' },
] as const;

export type CurrencyCode = typeof SUPPORTED_CURRENCIES[number]['code'];

export function formatCurrency(
  amount: number,
  currency: string = 'USD',
  locale: Locale = 'es'
): string {
  return new Intl.NumberFormat(locale === 'es' ? 'es-CO' : 'en-US', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(amount);
}

export function formatCompactCurrency(amount: number, currency: string = 'USD'): string {
  if (amount >= 1_000_000) return `${(amount / 1_000_000).toFixed(1)}M`;
  if (amount >= 1_000) return `${(amount / 1_000).toFixed(1)}K`;
  return `${amount}`;
}

// ─── Dates ────────────────────────────────────────────────────────────────────

export function formatDate(date: string | Date, locale: Locale = 'es'): string {
  const d = typeof date === 'string' ? parseISO(date) : date;
  return format(d, 'dd MMM yyyy', { locale: LOCALES[locale] });
}

export function formatShortDate(date: string | Date, locale: Locale = 'es'): string {
  const d = typeof date === 'string' ? parseISO(date) : date;
  return format(d, 'dd MMM', { locale: LOCALES[locale] });
}

export function formatRelativeDate(date: string | Date, locale: Locale = 'es'): string {
  const d = typeof date === 'string' ? parseISO(date) : date;
  return formatDistanceToNow(d, { addSuffix: true, locale: LOCALES[locale] });
}

export function formatMonthYear(date: string | Date, locale: Locale = 'es'): string {
  const d = typeof date === 'string' ? parseISO(date) : date;
  return format(d, 'MMMM yyyy', { locale: LOCALES[locale] });
}

export function today(): string {
  return format(new Date(), 'yyyy-MM-dd');
}

export function monthRange(date: Date = new Date()): { start: string; end: string } {
  return {
    start: format(startOfMonth(date), 'yyyy-MM-dd'),
    end: format(endOfMonth(date), 'yyyy-MM-dd'),
  };
}

export { addDays, addMonths, isAfter, isBefore, parseISO };

// ─── Numbers ─────────────────────────────────────────────────────────────────

export function percentage(partial: number, total: number): number {
  if (total === 0) return 0;
  return Math.min(100, Math.round((partial / total) * 100));
}

export function budgetStatus(spent: number, limit: number): 'safe' | 'warning' | 'danger' {
  const pct = percentage(spent, limit);
  if (pct >= 100) return 'danger';
  if (pct >= 80) return 'warning';
  return 'safe';
}
