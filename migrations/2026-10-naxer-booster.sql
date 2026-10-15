-- "NAXER Booster": kwota ustawiana recznie przez admina dla wybranego
-- wspolnika (na polecenie w stylu "/konto Jan Nowak naxer booster 8000zl").
-- Jeden wiersz na wspolnika (partner_id = primary key) - nowe polecenie
-- nadpisuje poprzednia kwote. Zysk i rata 1/12 licza sie w JS z tej samej
-- tabeli progow co w zakladce NAXER (nie trzymamy ich w bazie).
-- Uruchom w Supabase -> SQL Editor. Skrypt mozna bezpiecznie uruchomic ponownie.

create table if not exists public.naxer_boosters (
  partner_id uuid primary key references public.profiles(id) on delete cascade,
  amount_pln numeric(14,2) not null check (amount_pln > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.naxer_boosters enable row level security;

drop policy if exists "naxer_boosters: partner reads own" on public.naxer_boosters;
create policy "naxer_boosters: partner reads own" on public.naxer_boosters
  for select using (partner_id = auth.uid());

drop policy if exists "naxer_boosters: admin reads all" on public.naxer_boosters;
create policy "naxer_boosters: admin reads all" on public.naxer_boosters
  for select using (public.is_admin());

drop policy if exists "naxer_boosters: admin writes" on public.naxer_boosters;
create policy "naxer_boosters: admin writes" on public.naxer_boosters
  for insert to authenticated with check (public.is_admin());

drop policy if exists "naxer_boosters: admin updates" on public.naxer_boosters;
create policy "naxer_boosters: admin updates" on public.naxer_boosters
  for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists "naxer_boosters: admin deletes" on public.naxer_boosters;
create policy "naxer_boosters: admin deletes" on public.naxer_boosters
  for delete using (public.is_admin());

-- ============================================================
-- JAK USTAWIC BOOSTER (to robi Claude na Twoje polecenie "/konto IMIE NAZWISKO
-- naxer booster KWOTAzl" - generuje ponizsze zapytanie z podstawionymi danymi,
-- Ty je uruchamiasz w SQL Editorze):
--
--   insert into public.naxer_boosters (partner_id, amount_pln)
--   values ((select id from public.profiles where full_name = 'Jan Nowak'), 8000)
--   on conflict (partner_id) do update
--     set amount_pln = excluded.amount_pln, updated_at = now();
--
-- Zdjecie boostera (gdy ma zniknac z konta wspolnika):
--   delete from public.naxer_boosters
--   where partner_id = (select id from public.profiles where full_name = 'Jan Nowak');
-- ============================================================
