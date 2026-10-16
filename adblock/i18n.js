// Тексты страниц расширения берутся из _locales — русские или
// английские, по языку браузера.
const t = (key, ...subs) => chrome.i18n.getMessage(key, subs.map(String)) || key;
document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });
document.querySelectorAll('[data-i18n-ph]').forEach(el => { el.placeholder = t(el.dataset.i18nPh); });
