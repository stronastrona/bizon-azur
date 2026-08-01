// Czysta logika finansowa kalkulatora - bez zaleznosci od DOM/Supabase,
// zeby dalo sie ja latwo przetestowac w izolacji.

// Przyszla wartosc: kapital poczatkowy rosnacy co miesiac + regularne
// wplaty na koniec kazdego miesiaca (renta zwykla), oprocentowanie
// przeliczone z rocznej stopy na efektywna stopa miesieczna.
export function projectFutureValue({ currentValue = 0, monthlyContribution = 0, annualRatePct = 6, months = 0 }) {
  const i = Math.pow(1 + annualRatePct / 100, 1 / 12) - 1;
  let value = currentValue;
  for (let m = 0; m < months; m++) {
    value = value * (1 + i) + monthlyContribution;
  }
  return value;
}

// Zwraca punkty projekcji co rok (od roku 0 do `years`), dla wykresu/tabeli.
export function projectTimeline({ currentValue = 0, monthlyContribution = 0, annualRatePct = 6, years = 10, alreadyContributed = 0 }) {
  const points = [];
  for (let y = 0; y <= years; y++) {
    const months = y * 12;
    const value = projectFutureValue({ currentValue, monthlyContribution, annualRatePct, months });
    const totalContributed = alreadyContributed + monthlyContribution * months;
    points.push({
      year: y,
      value,
      totalContributed,
      profit: value - totalContributed,
    });
  }
  return points;
}

// Porownanie dwoch scenariuszy wplat (np. "obecne tempo" vs "zwiekszona wplata")
// dla tych samych zalozen startowych i stopy zwrotu.
export function compareScenarios({ currentValue, annualRatePct, years, alreadyContributed, currentMonthly, increasedMonthly }) {
  return {
    current: projectTimeline({ currentValue, monthlyContribution: currentMonthly, annualRatePct, years, alreadyContributed }),
    increased: projectTimeline({ currentValue, monthlyContribution: increasedMonthly, annualRatePct, years, alreadyContributed }),
  };
}

// Szacowana, wygladzona historia wzrostu kapitalu wspolnika miesiac po
// miesiacu. Nie mamy comiesiecznych wycen portfela z przeszlosci (admin
// wpisuje je od czasu do czasu), wiec zamiast pojedynczego punktu
// wyliczamy STALA srednia miesieczna stope zwrotu, ktora - zastosowana do
// realnej historii wplat wspolnika - daje dokladnie jego dzisiejsza,
// prawdziwa wartosc (z silnika jednostek uczestnictwa). To szacunek, nie
// dokladna historia.
export function monthlyGrowthSeries({ contributions, currentValue }) {
  if (!contributions || contributions.length === 0 || currentValue <= 0) return [];

  const byMonth = new Map();
  contributions.forEach((c) => {
    const d = new Date(c.contributed_at);
    const key = d.getFullYear() * 12 + d.getMonth();
    byMonth.set(key, (byMonth.get(key) || 0) + Number(c.amount));
  });

  const keys = [...byMonth.keys()];
  const firstKey = Math.min(...keys);
  const now = new Date();
  const lastKey = now.getFullYear() * 12 + now.getMonth();

  const monthlyAmounts = [];
  for (let k = firstKey; k <= lastKey; k++) monthlyAmounts.push(byMonth.get(k) || 0);

  const simulate = (rate) => {
    let value = 0;
    const series = [];
    monthlyAmounts.forEach((amount) => {
      value = value * (1 + rate) + amount;
      series.push(value);
    });
    return series;
  };

  // Bisekcja: szukamy stalej stopy miesiecznej, ktora daje na koncu
  // dokladnie znana, prawdziwa biezaca wartosc.
  let lo = -0.2;
  let hi = 0.2;
  for (let i = 0; i < 60; i++) {
    const mid = (lo + hi) / 2;
    const end = simulate(mid).pop();
    if (end < currentValue) lo = mid;
    else hi = mid;
  }
  const rate = (lo + hi) / 2;
  const finalSeries = simulate(rate);

  return monthlyAmounts.map((amount, idx) => ({
    monthIndex: idx,
    value: finalSeries[idx],
  }));
}
