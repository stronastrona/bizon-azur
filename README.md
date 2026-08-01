# Bizon Azur Inwestycje Długoterminowe

Prosta strona informacyjna dla spółki inwestycyjnej. Każdy z 9 wspólników po zalogowaniu widzi ile wpłacił, ile zarobił i ile może teraz wypłacić, oraz kalkulator prognozujący przyszły zysk. Bez wpłat/wypłat online — wyłącznie podgląd.

## Jak to działa

- Frontend to zwykłe strony HTML/CSS/JS (bez build stepu), które można wrzucić na GitHub Pages.
- Dane i logowanie trzyma [Supabase](https://supabase.com) (darmowy plan wystarczy w zupełności).
- Logowanie działa e-mailem **lub nickiem** — Supabase Auth technicznie wymaga e-maila, więc nick jest po prostu tłumaczony na przypisany do niego e-mail przed logowaniem (funkcja `email_for_username` w `schema.sql`).
- Ponieważ wspólnicy wpłacają różne kwoty w różnym czasie, a zarabiają ten sam procent (bo pieniądze są inwestowane wspólnie), rozliczenie liczone jest metodą **jednostek uczestnictwa** — tak jak w funduszu inwestycyjnym. Cała logika siedzi w `schema.sql` (funkcja `compute_fund_ledger`), więc każdy wspólnik zawsze widzi uczciwy, aktualny wynik.

## Konfiguracja (jednorazowo)

1. **Załóż projekt Supabase**: [supabase.com](https://supabase.com) → New project (zapisz hasło do bazy).
2. **Uruchom schemat bazy**: w Supabase → SQL Editor → wklej całą zawartość [`schema.sql`](schema.sql) → Run.
3. **Uzupełnij dane połączenia**: w Supabase → Project Settings → API skopiuj `Project URL` i `anon public key`, wklej je w [`js/supabaseClient.js`](js/supabaseClient.js) w miejsce `TWOJ-PROJEKT` / `TWOJ-ANON-KEY`.
4. **Załóż swoje konto admina** (Supabase → Authentication → Users → Add user):
   - Email: dowolny, którego masz dostęp do skrzynki (Supabase i tak wymaga poprawnego formatu e-maila) — np. Twój prawdziwy e-mail.
   - Password: `admin` (na start — **zalecam zmienić po pierwszym zalogowaniu**, to bardzo słabe hasło do platformy z danymi finansowymi).
   - Skopiuj `User UID` nowo utworzonego konta.
   - W SQL Editorze uruchom:
     ```sql
     insert into public.profiles (id, full_name, username, is_admin)
     values ('WKLEJ-UID', 'Administrator', 'admin', true);
     ```
   - Od teraz logujesz się na stronie wpisując nick `admin` i ustawione hasło.
5. **Załóż konta pozostałych 8 wspólników**: tak samo jak wyżej (Authentication → Users → Add user), ale `is_admin` ustaw na `false` i nadaj każdemu unikalny `username`.
6. **Wdróż na GitHub Pages**: utwórz repozytorium na GitHub, wypchnij ten folder, potem w ustawieniach repo włącz Pages (branch `main`, folder `/`).

## Comiesięczna aktualizacja danych

Zaloguj się jako admin i w [`admin.html`](admin.html):
- dodaj nowe wpłaty poszczególnych wspólników,
- dodaj nową wycenę całego portfela (na podstawie aktualnego wyciągu z konta maklerskiego).

Reszta (zysk każdego wspólnika, wartość do wypłaty, wykres) przeliczy się automatycznie.

## Struktura plików

```
index.html              logowanie (e-mail lub nick)
dashboard.html           panel wspólnika: wpłaty, zysk, wykres, kalkulator
admin.html                panel admina: dodawanie wpłat i wycen
js/supabaseClient.js     konfiguracja połączenia z Supabase
js/auth.js                obsługa sesji/roli
js/calculator.js          logika finansowa kalkulatora
style.css                  style współdzielone (czarno-pomarańczowy motyw)
schema.sql                  schemat bazy danych, RLS, silnik jednostek uczestnictwa, logowanie nickiem
```
