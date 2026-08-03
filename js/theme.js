// Zwykly (nie-modulowy) skrypt, ladowany synchronicznie w <head> zaraz po
// style.css, zeby motyw byl ustawiony PRZED narysowaniem strony (bez
// mrugniecia zlym kolorem). Wybor trzyma sie w localStorage, wiec dziala
// tak samo na kazdej podstronie.
(function () {
  var THEMES = ['dark-orange', 'light-orange', 'light-pink'];
  var STORAGE_KEY = 'bizon-theme';

  function currentTheme() {
    var stored = localStorage.getItem(STORAGE_KEY);
    return THEMES.indexOf(stored) !== -1 ? stored : 'dark-orange';
  }

  document.documentElement.setAttribute('data-theme', currentTheme());

  function markActiveSwatch() {
    var active = currentTheme();
    document.querySelectorAll('.theme-swatch').forEach(function (el) {
      el.classList.toggle('active', el.getAttribute('data-theme-choice') === active);
    });
  }

  window.setBizonTheme = function (theme) {
    if (THEMES.indexOf(theme) === -1) return;
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem(STORAGE_KEY, theme);
    markActiveSwatch();
  };

  document.addEventListener('DOMContentLoaded', markActiveSwatch);
})();
