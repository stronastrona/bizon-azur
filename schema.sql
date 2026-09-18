-- Platforma spolki inwestycyjnej - schemat Supabase (Postgres)
-- Uruchom caly ten plik w Supabase: Dashboard -> SQL Editor -> New query -> Run

-- ============================================================
-- 1. PROFILE (jeden wiersz per wspolnik, powiazany z auth.users)
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  username text unique,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Pomocnicza funkcja SECURITY DEFINER do sprawdzania czy caller jest adminem.
-- WAZNE: polityka RLS na tabeli profiles NIE MOZE odpytywac wprost tabeli
-- profiles w swoim "using" (np. `exists (select 1 from public.profiles ...)`),
-- bo taki podzapytanie samo podlega RLS na profiles, co wywoluje te sama
-- polityke ponownie -> nieskonczona rekurencja ("infinite recursion detected
-- in policy for relation profiles"). Funkcja SECURITY DEFINER omija RLS
-- (dziala z uprawnieniami wlasciciela funkcji), wiec nie ma tego problemu.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

grant execute on function public.is_admin() to authenticated;

create policy "profiles: user reads own row"
  on public.profiles for select
  using (id = auth.uid());

create policy "profiles: admin reads all rows"
  on public.profiles for select
  using (public.is_admin());

-- ============================================================
-- 2. WPLATY
-- ============================================================
create table if not exists public.contributions (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  contributed_at date not null,
  created_at timestamptz not null default now()
);

alter table public.contributions enable row level security;

create policy "contributions: partner reads own"
  on public.contributions for select
  using (partner_id = auth.uid());

create policy "contributions: admin reads all"
  on public.contributions for select
  using (public.is_admin());

create policy "contributions: admin writes"
  on public.contributions for insert
  with check (public.is_admin());

create policy "contributions: admin updates"
  on public.contributions for update
  using (public.is_admin());

create policy "contributions: admin deletes"
  on public.contributions for delete
  using (public.is_admin());

-- ============================================================
-- 3. WYCENY PORTFELA (calosc puli, wpisywana recznie przez admina)
-- ============================================================
create table if not exists public.portfolio_valuations (
  id uuid primary key default gen_random_uuid(),
  valuation_date date not null,
  total_value numeric(14,2) not null check (total_value >= 0),
  created_at timestamptz not null default now()
);

alter table public.portfolio_valuations enable row level security;

create policy "valuations: any logged-in partner reads"
  on public.portfolio_valuations for select
  using (auth.uid() is not null);

create policy "valuations: admin writes"
  on public.portfolio_valuations for insert
  with check (public.is_admin());

create policy "valuations: admin updates"
  on public.portfolio_valuations for update
  using (public.is_admin());

create policy "valuations: admin deletes"
  on public.portfolio_valuations for delete
  using (public.is_admin());

-- ============================================================
-- 4. SILNIK JEDNOSTEK UCZESTNICTWA (NAV) - SECURITY DEFINER
--
-- Kazda wplata i kazda wycena to zdarzenie w czasie. Odtwarzamy je
-- chronologicznie: wplata kupuje jednostki po biezacej cenie (NAV),
-- wycena aktualizuje NAV na podstawie faktycznej wartosci portfela.
-- Dzieki temu kazda zlotowka zarabia ten sam % zwrotu, niezaleznie
-- od tego kto i kiedy ja wplacil.
-- ============================================================
create or replace function public.compute_fund_ledger()
returns table (
  partner_id uuid,
  total_contributed numeric,
  units numeric,
  current_nav numeric,
  current_value numeric,
  profit numeric,
  return_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  ev record;
  nav numeric := 100;              -- cena startowa jednostki
  total_units numeric := 0;
  units_map jsonb := '{}'::jsonb;  -- partner_id (text) -> units (numeric)
  contributed_map jsonb := '{}'::jsonb;
  key text;
  cur_units numeric;
  cur_contributed numeric;
begin
  for ev in (
    select 'contribution'::text as kind, c.partner_id, c.amount, null::numeric as total_value, c.contributed_at as event_date, c.created_at
    from public.contributions c
    union all
    select 'valuation'::text as kind, null::uuid, null::numeric, v.total_value, v.valuation_date as event_date, v.created_at
    from public.portfolio_valuations v
    order by 5, 6
  )
  loop
    if ev.kind = 'contribution' then
      key := ev.partner_id::text;
      if nav <= 0 then
        nav := 100;
      end if;
      cur_units := coalesce((units_map ->> key)::numeric, 0) + (ev.amount / nav);
      units_map := jsonb_set(units_map, array[key], to_jsonb(cur_units));
      cur_contributed := coalesce((contributed_map ->> key)::numeric, 0) + ev.amount;
      contributed_map := jsonb_set(contributed_map, array[key], to_jsonb(cur_contributed));
      total_units := total_units + (ev.amount / nav);
    else
      if total_units > 0 then
        nav := ev.total_value / total_units;
      end if;
    end if;
  end loop;

  for key in select jsonb_object_keys(units_map)
  loop
    partner_id := key::uuid;
    units := (units_map ->> key)::numeric;
    total_contributed := (contributed_map ->> key)::numeric;
    current_nav := nav;
    current_value := units * nav;
    profit := current_value - total_contributed;
    return_pct := case when total_contributed > 0 then (profit / total_contributed) * 100 else 0 end;
    return next;
  end loop;
end;
$$;

-- ============================================================
-- 5. WIDOK partner_summary - kazdy wspolnik widzi tylko siebie,
--    admin widzi wszystkich (filtr w funkcji ponizej, nie w widoku,
--    bo SECURITY DEFINER omija RLS wewnatrz compute_fund_ledger).
-- ============================================================
create or replace function public.partner_summary()
returns table (
  partner_id uuid,
  full_name text,
  total_contributed numeric,
  current_value numeric,
  profit numeric,
  return_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  is_caller_admin boolean;
begin
  select coalesce(p.is_admin, false) into is_caller_admin
  from public.profiles p where p.id = auth.uid();

  return query
  select l.partner_id, pr.full_name, l.total_contributed, l.current_value, l.profit, l.return_pct
  from public.compute_fund_ledger() l
  join public.profiles pr on pr.id = l.partner_id
  where is_caller_admin or l.partner_id = auth.uid();
end;
$$;

grant execute on function public.partner_summary() to authenticated;
grant execute on function public.compute_fund_ledger() to authenticated;

-- ============================================================
-- 6. LOGOWANIE NICKIEM - Supabase Auth wymaga e-maila do logowania,
--    ale wspolnicy moga zamiast e-maila wpisac swoj "nick" (username).
--    Ta funkcja, wywolywana z ekranu logowania PRZED zalogowaniem
--    (wiec dziala dla roli anon), zwraca e-mail powiazany z nickiem,
--    zeby front mogl nim podmienic pole i zalogowac sie normalnie.
--    Nie ujawnia niczego wiecej niz sam e-mail dla istniejacego nicku.
-- ============================================================
create or replace function public.email_for_username(uname text)
returns text
language sql
security definer
set search_path = public, auth
stable
as $$
  select u.email
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(p.username) = lower(uname)
  limit 1;
$$;

grant execute on function public.email_for_username(text) to anon, authenticated;

-- ============================================================
-- 7. Po utworzeniu kont wspolnikow w Supabase Auth (Dashboard ->
--    Authentication -> Users -> Add user), dodaj dla kazdego profil:
--
--    insert into public.profiles (id, full_name, username, is_admin) values
--      ('<uuid-uzytkownika>', 'Jan Kowalski', 'jankowalski', false);
--
--    Dla siebie (admina) ustaw is_admin = true, np. username = 'admin'.
-- ============================================================

-- ============================================================
-- 8. KANTOR KRYPTO (podgladowy) - to samo co migrations/2026-09-kantor.sql
-- ============================================================
-- Kantor krypto (podgladowy): zapisane adresy portfeli + zlecenia zakupu.
-- Uruchom w Supabase -> SQL Editor. Skrypt mozna bezpiecznie uruchomic ponownie.
-- Przez strone nic sie nie kupuje - zlecenie realizuje recznie pracownik.

-- Adresy portfeli wspolnika (osobny adres dla kazdej waluty).
-- Osobna tabela, a nie kolumna w profiles: gdyby wspolnik mial prawo edytowac
-- swoj wiersz w profiles, moglby nadac sobie is_admin.
create table if not exists public.partner_wallets (
  partner_id uuid not null references public.profiles(id) on delete cascade,
  coin text not null,
  network text,
  address text not null check (char_length(address) between 14 and 128 and address !~ '\s'),
  updated_at timestamptz not null default now(),
  primary key (partner_id, coin)
);
alter table public.partner_wallets enable row level security;

drop policy if exists "wallets: partner reads own" on public.partner_wallets;
create policy "wallets: partner reads own" on public.partner_wallets
  for select using (partner_id = auth.uid());
drop policy if exists "wallets: admin reads all" on public.partner_wallets;
create policy "wallets: admin reads all" on public.partner_wallets
  for select using (public.is_admin());
drop policy if exists "wallets: partner inserts own" on public.partner_wallets;
create policy "wallets: partner inserts own" on public.partner_wallets
  for insert with check (partner_id = auth.uid());
drop policy if exists "wallets: partner updates own" on public.partner_wallets;
create policy "wallets: partner updates own" on public.partner_wallets
  for update using (partner_id = auth.uid()) with check (partner_id = auth.uid());

-- Zlecenia zakupu. Kurs to kurs POGLADOWY z chwili zlecenia.
create table if not exists public.crypto_orders (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.profiles(id) on delete cascade,
  coin text not null check (coin in ('BTC','ETH','USDT','BNB','XRP','SOL','USDC','DOGE','TRX','ADA')),
  network text,
  amount_pln numeric(14,2) not null check (amount_pln > 0),
  rate_pln numeric(20,8) not null check (rate_pln > 0),
  amount_coin numeric(28,12) not null check (amount_coin > 0),
  wallet_address text not null check (char_length(wallet_address) between 14 and 128 and wallet_address !~ '\s'),
  status text not null default 'nowe' check (status in ('nowe','zrealizowane','anulowane')),
  created_at timestamptz not null default now()
);
alter table public.crypto_orders enable row level security;

drop policy if exists "orders: partner reads own" on public.crypto_orders;
create policy "orders: partner reads own" on public.crypto_orders
  for select using (partner_id = auth.uid());
drop policy if exists "orders: admin reads all" on public.crypto_orders;
create policy "orders: admin reads all" on public.crypto_orders
  for select using (public.is_admin());
drop policy if exists "orders: partner creates own" on public.crypto_orders;
create policy "orders: partner creates own" on public.crypto_orders
  for insert with check (partner_id = auth.uid() and status = 'nowe');
drop policy if exists "orders: admin updates" on public.crypto_orders;
create policy "orders: admin updates" on public.crypto_orders
  for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists "orders: admin deletes" on public.crypto_orders;
create policy "orders: admin deletes" on public.crypto_orders
  for delete using (public.is_admin());
