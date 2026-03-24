// Types
export * from './types/database';

// Supabase
export { createSupabaseClient } from './lib/supabase';
export type { SupabaseClient, Database } from './lib/supabase';

// Validation schemas
export * from './lib/schemas';

// Utilities
export * from './utils/format';

// i18n
export { es, en, t, translations, DEFAULT_LOCALE } from './i18n/index';
export type { SupportedLocale } from './i18n/index';
