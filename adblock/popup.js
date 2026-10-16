// Окно по щелчку на значке: выключить или включить блокировку
// на открытом сайте. Адрес вкладки доступен только в момент щелчка
// (право activeTab) — расширение не следит, какие сайты вы открываете.

const $ = (id) => document.getElementById(id);

function siteOf(url) {
  try {
    const u = new URL(url);
    if (!/^https?:$/.test(u.protocol)) return '';
    return u.hostname.replace(/^www\./, '');
  } catch (e) { return ''; }
}

async function main() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const site = tab ? siteOf(tab.url || '') : '';
  $('host').textContent = site || '—';

  let { allow = [] } = await chrome.storage.local.get('allow');
  const isOff = () => allow.some(d => site === d || site.endsWith('.' + d));

  const paint = () => {
    const off = isOff();
    $('state').textContent = off ? t('popupOff') : t('popupOn');
    $('state').className = off ? 'warn' : 'ok';
    $('toggle').textContent = off ? t('popupEnable') : t('popupDisable');
    $('toggle').disabled = !site;
  };
  paint();

  try {
    const n = await chrome.action.getBadgeText({ tabId: tab.id });
    if (n) $('count').textContent = t('popupBlocked', n);
  } catch (e) { }

  $('toggle').addEventListener('click', async () => {
    if (!site) return;
    if (isOff()) allow = allow.filter(d => !(site === d || site.endsWith('.' + d)));
    else allow = [...allow, site];
    await chrome.storage.local.set({ allow });
    paint();
    $('reloadHint').style.display = 'block';
  });
  $('reload').addEventListener('click', () => { if (tab) chrome.tabs.reload(tab.id); window.close(); });
  $('opts').addEventListener('click', () => chrome.runtime.openOptionsPage());

  try {
    const meta = await (await fetch('data/lists-meta.json')).json();
    $('lists').textContent = meta.date
      ? t('popupLists', meta.date, meta.network, meta.cosmetic)
      : t('popupNoLists');
  } catch (e) { $('lists').textContent = t('popupNoLists'); }
}
main();
