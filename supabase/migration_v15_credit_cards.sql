-- Tarjetas de crédito con cupo rotativo.
--
-- Convención: para una cuenta type='credit', `balance` representa la DEUDA usada
-- (positivo = lo que debes). El disponible = credit_limit - balance.
--  · Un gasto con la tarjeta AUMENTA balance (usa cupo).
--  · Un pago a la tarjeta DISMINUYE balance (libera cupo).
-- Para el resto de cuentas (debit/cash/savings) `balance` sigue siendo el dinero
-- disponible, sin cambios.

-- 1) Cupo de la tarjeta (NULL para cuentas que no son de crédito).
alter table public.accounts
  add column if not exists credit_limit numeric(14,2);

-- 2) Pago de tarjeta atómico: mueve dinero de una cuenta origen a la tarjeta.
--    Baja el saldo de la cuenta origen por (amount + fees) y reduce la deuda de la
--    tarjeta por amount (los intereses/adicionales NO reducen la deuda).
--    Registra además una transacción de gasto en la cuenta origen para el historial.
create or replace function public.pay_credit_card(
  p_card_id uuid,
  p_source_account_id uuid,
  p_amount numeric,
  p_fees numeric default 0,
  p_date date default current_date,
  p_category_id uuid default null,
  p_description text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_household uuid := public.get_my_household_id();
  v_user uuid := auth.uid();
  v_total numeric := coalesce(p_amount, 0) + coalesce(p_fees, 0);
begin
  if v_household is null then
    raise exception 'Sin hogar';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Monto inválido';
  end if;

  -- Ambas cuentas deben pertenecer al hogar.
  if not exists (select 1 from public.accounts where id = p_card_id and household_id = v_household and type = 'credit') then
    raise exception 'Tarjeta no encontrada en tu hogar';
  end if;
  if not exists (select 1 from public.accounts where id = p_source_account_id and household_id = v_household) then
    raise exception 'Cuenta de origen no encontrada en tu hogar';
  end if;

  -- Descuenta de la cuenta origen el total pagado (monto + intereses/adicionales).
  update public.accounts
    set balance = balance - v_total
    where id = p_source_account_id and household_id = v_household;

  -- Reduce la deuda de la tarjeta solo por el monto (no por los fees).
  update public.accounts
    set balance = balance - p_amount
    where id = p_card_id and household_id = v_household;

  -- Historial: un gasto en la cuenta origen (descripción: pago de tarjeta).
  insert into public.transactions (account_id, household_id, created_by, amount, type, category_id, description, date)
  values (
    p_source_account_id, v_household, v_user, v_total, 'expense', p_category_id,
    coalesce(p_description, 'Pago de tarjeta'), p_date
  );
end;
$$;
