// Настройки хранятся только в этом браузере (chrome.storage.local) —
// ни синхронизации, ни отправки куда-либо.

const $ = (id) => document.getElementById(id);
const lines = (s) => s.split(/\r?\n/).map(x => x.trim()).filter(Boolean);

async function load() {
  const d = await chrome.storage.local.get(['allow', 'customDomains', 'customCss', 'ytEnabled']);
  $('allow').value = (d.allow || []).join('\n');
  $('domains').value = (d.customDomains || []).join('\n');
  $('css').value = (d.customCss || []).join('\n');
  $('yt').checked = d.ytEnabled !== false;
  try {
    const meta = await (await fetch('data/lists-meta.json')).json();
    $('lists').textContent = meta.date
      ? t('optListsOn', meta.date, meta.network, meta.cosmetic, (meta.sources || []).join(', '))
      : t('optListsOff');
  } catch (e) { $('lists').textContent = t('optListsOff'); }
}

$('save').addEventListener('click', async () => {
  await chrome.storage.local.set({
    allow: lines($('allow').value),
    customDomains: lines($('domains').value),
    customCss: lines($('css').value),
    ytEnabled: $('yt').checked
  });
  try { await chrome.runtime.sendMessage({ t: 'reload-cosmetic' }); } catch (e) { }
  $('saved').style.opacity = 1;
  setTimeout(() => { $('saved').style.opacity = 0; }, 1600);
});

// Списки, обновлённые программой CookieGuard, лежат на диске; браузер
// перечитывает их при перезагрузке расширения.
$('reloadExt').addEventListener('click', () => chrome.runtime.reload());

load();
