-- =============================================================================
-- Migration v5 — SEGURIDAD Y ATOMICIDAD
-- Cierra la cadena de RLS entre hogares, mueve el bootstrap/unión a RPCs
-- SECURITY DEFINER atómicas, ajusta balances de forma transaccional en la BD,
-- y corrige CHECKs inconsistentes.
--
-- Ejecuta este script en el SQL Editor de Supabase (o vía `supabase db push`).
-- Es idempotente: puede correrse más de una vez sin efectos adversos.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Prerrequisitos de columnas (por si alguna migración previa no corrió)
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.households
  add column if not exists invite_code text unique;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. CADENA RLS DE households / profiles
--    Problema: households estaba abierto a todos (select/insert using(true)),
--    exponiendo invite_codes; y profile_update no tenía WITH CHECK, permitiendo
--    reasignar household_id a un hogar ajeno (escalada horizontal).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1a. Eliminar las políticas permisivas introducidas en migration_v2.
drop policy if exists "users can insert households"        on public.households;
drop policy if exists "users can select households"        on public.households;
drop policy if exists "members can update their household" on public.households;
-- Y las del schema base, para redefinirlas de forma estricta.
drop policy if exists "household_member_select" on public.households;
drop policy if exists "household_member_update" on public.households;

-- 1b. households: SELECT/UPDATE solo del hogar propio. NO hay INSERT directo:
--     la creación pasa exclusivamente por la RPC create_household (abajo).
create policy "household_member_select" on public.households
  for select using (id = public.get_my_household_id());

create policy "household_member_update" on public.households
  for update using (id = public.get_my_household_id())
  with check (id = public.get_my_household_id());

-- 1c. profiles.update: añadir WITH CHECK que impide cambiar household_id
--     arbitrariamente desde el cliente. La unión a un hogar se hace por RPC.
drop policy if exists "profile_update" on public.profiles;
create policy "profile_update" on public.profiles
  for update using (id = auth.uid())
  with check (
    id = auth.uid()
    and (
      -- No se toca el household, o se deja en el actual, o se limpia.
      household_id is null
      or household_id = public.get_my_household_id()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RPC create_household — bootstrap atómico y seguro
--    Crea el hogar, vincula el perfil del usuario, y siembra categorías y una
--    cuenta por defecto, todo en una transacción. SECURITY DEFINER para poder
--    insertar en households (que no tiene policy INSERT para el cliente).
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.create_household(p_name text)
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_hh   public.households;
  v_code text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  -- Un usuario no puede crear un hogar si ya pertenece a uno.
  if (select household_id from public.profiles where id = v_uid) is not null then
    raise exception 'Ya perteneces a un hogar';
  end if;

  -- Código de invitación único (6 chars). Reintenta ante colisión improbable.
  loop
    v_code := upper(substr(md5(gen_random_uuid()::text), 1, 6));
    exit when not exists (select 1 from public.households where invite_code = v_code);
  end loop;

  insert into public.households (name, invite_code)
  values (coalesce(nullif(trim(p_name), ''), 'Hogar Principal'), v_code)
  returning * into v_hh;

  update public.profiles set household_id = v_hh.id where id = v_uid;

  -- Categorías por defecto.
  insert into public.categories (household_id, name, icon, color, type) values
    (v_hh.id, 'Alimentación', 'restaurant', '#EF4444', 'expense'),
    (v_hh.id, 'Transporte',   'car',        '#F59E0B', 'expense'),
    (v_hh.id, 'Vivienda',     'home',       '#6366F1', 'expense'),
    (v_hh.id, 'Salario',      'money',      '#22C55E', 'income');

  -- Cuenta por defecto (type válido según el CHECK: 'cash').
  insert into public.accounts (household_id, owner_id, name, type, balance, currency, color, icon)
  values (v_hh.id, v_uid, 'Efectivo Principal', 'cash', 0, 'USD', '#22C55E', 'wallet');

  return v_hh;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RPC join_household — unión por código, validada server-side
--    Reemplaza el select directo a households por invite_code (que la RLS
--    bloqueaba) y el update inseguro de profiles.household_id.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.join_household(p_code text)
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hh  public.households;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if (select household_id from public.profiles where id = v_uid) is not null then
    raise exception 'Ya perteneces a un hogar';
  end if;

  select * into v_hh
  from public.households
  where invite_code = upper(trim(p_code))
  limit 1;

  if v_hh.id is null then
    raise exception 'Código de invitación inválido o vencido';
  end if;

  update public.profiles set household_id = v_hh.id where id = v_uid;
  return v_hh;
end;
$$;

-- Exponer las RPC a usuarios autenticados.
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.join_household(text)   to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. RPC de balance atómico — evita el read-modify-write desde el cliente
--    apply_account_delta ajusta el saldo de una cuenta sumando un delta de
--    forma atómica (UPDATE ... SET balance = balance + delta), validando
--    pertenencia al household del usuario.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.apply_account_delta(p_account_id uuid, p_delta numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_household uuid := public.get_my_household_id();
begin
  if v_household is null then
    raise exception 'Sin hogar';
  end if;

  update public.accounts
    set balance = balance + p_delta
    where id = p_account_id
      and household_id = v_household;

  if not found then
    raise exception 'Cuenta no encontrada en tu hogar';
  end if;
end;
$$;

grant execute on function public.apply_account_delta(uuid, numeric) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Correcciones de CHECK
-- ─────────────────────────────────────────────────────────────────────────────

-- 5a. recurring_events.frequency: el cliente usa 'biweekly' (Quincenal), que
--     el CHECK original no permitía. Ampliar el enum.
alter table public.recurring_events
  drop constraint if exists recurring_events_frequency_check;
alter table public.recurring_events
  add constraint recurring_events_frequency_check
  check (frequency in ('daily', 'weekly', 'biweekly', 'monthly', 'yearly'));

-- 5b. financial_plans: montos deben ser > 0 (faltaban los CHECK que otras
--     tablas monetarias sí tenían).
alter table public.financial_plans
  drop constraint if exists financial_plans_target_amount_check;
alter table public.financial_plans
  add constraint financial_plans_target_amount_check
  check (target_amount > 0);
alter table public.financial_plans
  drop constraint if exists financial_plans_monthly_contribution_check;
alter table public.financial_plans
  add constraint financial_plans_monthly_contribution_check
  check (monthly_contribution >= 0);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Storage RLS de avatars — restringir INSERT/UPDATE/DELETE al owner
--    La policy de INSERT original permitía a cualquier autenticado subir a
--    cualquier path del bucket; la de UPDATE/DELETE ya validaba owner.
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "Avatar Upload Access" on storage.objects;
create policy "Avatar Upload Access"
  on storage.objects for insert
  to authenticated
  with check ( bucket_id = 'avatars' and owner = auth.uid() );
