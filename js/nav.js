// Strzalki w kolkach po lewej od "Wyloguj": dwie zwykle (lewo/prawo) przelaczaja
// miedzy kartami panelu, trzecia - w plomieniach - prowadzi do zupelnie innej strony.
// Karty jeszcze nie istnieja: dopisz je do TABS, a FLAME_TARGET ustaw na adres
// docelowej strony. Strzalka bez celu jest wygaszona i ma podpis "Wkrótce".

const TABS = [
  { href: 'dashboard.html', label: 'Panel wspólnika' },
  { href: 'kantor.html', label: 'Kantor krypto' },
];

const FLAME_TARGET = { href: 'naxer_calculator.html', label: 'NAXER' };

const ARROW_LEFT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 12H5M11 6l-6 6 6 6"/></svg>';
const ARROW_RIGHT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>';

function circleButton({ svg, label, target, extraClass = '' }) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'nav-circle ' + extraClass;
  btn.innerHTML = svg;
  if (target) {
    btn.setAttribute('aria-label', label);
    btn.title = label;
    btn.addEventListener('click', () => { window.location.href = target.href; });
  } else {
    btn.disabled = true;
    btn.setAttribute('aria-label', label + ' (wkrótce)');
    btn.title = label + ' (wkrótce)';
  }
  return btn;
}

function init() {
  const logout = document.getElementById('logout-btn');
  if (!logout) return;

  const current = window.location.pathname.split('/').pop() || 'index.html';
  const idx = TABS.findIndex((t) => t.href === current);
  const prev = idx > 0 ? TABS[idx - 1] : null;
  const next = idx !== -1 && idx < TABS.length - 1 ? TABS[idx + 1] : null;

  const group = document.createElement('div');
  group.className = 'nav-arrows';
  group.appendChild(circleButton({ svg: ARROW_LEFT, label: 'Poprzednia karta', target: prev }));
  group.appendChild(circleButton({ svg: ARROW_RIGHT, label: 'Następna karta', target: next }));
  group.appendChild(circleButton({
    // cale kolko "plonie" (patrz .fire-ring w CSS) - nie potrzeba juz osobnej ikonki plomienia
    svg: ARROW_RIGHT,
    label: FLAME_TARGET ? FLAME_TARGET.label : 'Inna strona',
    target: FLAME_TARGET,
    extraClass: 'nav-flame fire-ring',
  }));

  logout.parentElement.insertBefore(group, logout);
}

init();
