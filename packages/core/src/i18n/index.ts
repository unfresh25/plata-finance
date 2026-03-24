import { es } from './es';
import { en } from './en';

export { es, en };

export type SupportedLocale = 'es' | 'en';
export const DEFAULT_LOCALE: SupportedLocale = 'es';

export const translations = { es, en } as const;

export function t(locale: SupportedLocale, key: string): string {
  const keys = key.split('.');
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let value: any = translations[locale];
  for (const k of keys) {
    value = value?.[k];
  }
  return typeof value === 'string' ? value : key;
}
