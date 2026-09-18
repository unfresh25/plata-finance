-- Migration v6: respuestas del cuestionario de onboarding
-- Guardadas como jsonb en el perfil (se suben tras crear la cuenta).
alter table public.profiles
  add column if not exists onboarding jsonb;
