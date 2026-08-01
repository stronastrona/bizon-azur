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
