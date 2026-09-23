-- v14 — Lista de deseos estilo Dreamboard: tableros (categorías con portada) y
-- deseos (items con foto, precio, link, prioridad).

create table if not exists public.wish_boards (
  id uuid primary key default uuid_generate_v4(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  emoji text,                     -- ícono/emoji de portada (ej. 🏠, 💻)
  cover_url text,                 -- imagen de portada opcional
  sort_index int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.wish_items (
  id uuid primary key default uuid_generate_v4(),
  board_id uuid not null references public.wish_boards(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  image_url text,                 -- foto por URL pegada o subida a storage
  price numeric(14,2),
  currency char(3) not null default 'COP',
  link text,                      -- URL de la tienda
  priority text not null default 'medium'
    check (priority in ('low','medium','high')),
  acquired boolean not null default false,   -- marcado como comprado/logrado
  note text,
  sort_index int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_wish_boards_hh on public.wish_boards (household_id, sort_index);
create index if not exists idx_wish_items_board on public.wish_items (board_id, sort_index);

alter table public.wish_boards enable row level security;
alter table public.wish_items enable row level security;

create policy "wish_boards_household_all" on public.wish_boards
  for all using (household_id = public.get_my_household_id())
  with check (household_id = public.get_my_household_id());

create policy "wish_items_household_all" on public.wish_items
  for all using (household_id = public.get_my_household_id())
  with check (household_id = public.get_my_household_id());

-- Bucket público para las fotos subidas de deseos (como avatares).
insert into storage.buckets (id, name, public)
values ('wishes', 'wishes', true)
on conflict (id) do nothing;

create policy "wishes_read" on storage.objects for select using (bucket_id = 'wishes');
create policy "wishes_write" on storage.objects for insert to authenticated with check (bucket_id = 'wishes');
create policy "wishes_update" on storage.objects for update to authenticated using (bucket_id = 'wishes');
