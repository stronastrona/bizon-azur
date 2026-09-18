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
