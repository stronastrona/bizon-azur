-- Zapytania z kalkulatora NAXER ("Wyslij zapytanie" -> podajesz e-mail,
-- docelowo dostajesz mailem szczegoly historyczne). System mailowy nie
-- istnieje jeszcze - to tylko zapisuje zapytanie do bazy, zeby nic nie
-- zginelo, dopoki wysylka nie zostanie zbudowana.
-- Uruchom w Supabase -> SQL Editor. Skrypt mozna bezpiecznie uruchomic ponownie.

create table if not exists public.naxer_requests (
  id uuid primary key default gen_random_uuid(),
  email text not null check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  amount_pln numeric(14,2) not null check (amount_pln > 0),
  rate_pct numeric(6,2) not null check (rate_pct > 0),
  status text not null default 'nowe' check (status in ('nowe','wyslane')),
  created_at timestamptz not null default now()
);
alter table public.naxer_requests enable row level security;

-- Strona NAXER jest publiczna (bez logowania) - kazdy moze wyslac zapytanie,
-- ale odczyt/edycja tylko dla admina zalogowanego do BizON.
drop policy if exists "naxer_requests: anyone can insert" on public.naxer_requests;
create policy "naxer_requests: anyone can insert" on public.naxer_requests
  for insert to anon, authenticated with check (true);

drop policy if exists "naxer_requests: admin reads" on public.naxer_requests;
create policy "naxer_requests: admin reads" on public.naxer_requests
  for select using (public.is_admin());

drop policy if exists "naxer_requests: admin updates" on public.naxer_requests;
create policy "naxer_requests: admin updates" on public.naxer_requests
  for update using (public.is_admin()) with check (public.is_admin());
