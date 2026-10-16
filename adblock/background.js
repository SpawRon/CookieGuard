// CookieGuard AdBlock — фоновая часть.
//
// Сетевые запросы блокирует не этот код, а сам браузер: правила
// лежат в rules/*.json и применяются движком declarativeNetRequest.
// Расширение ваших запросов не видит и видеть не может — у него нет
// ни права webRequest, ни доступа к адресам. Строка connect-src 'self'
// в manifest.json запрещает этому коду ходить в сеть вообще.
//
// Здесь только четыре вещи:
//   — правила пользователя (свои домены и сайты-исключения);
//   — CSS для скрытия рекламных блоков на конкретном сайте и общие
//     правила скрытия под классы и id, которые есть на странице;
//   — значок со счётчиком заблокированного;
//   — самообновление: программа CookieGuard кладёт новый код и
//     свежие списки в папку расширения, а расширение замечает это
//     и перезагружается само.

const CUSTOM_RULE_ID = 1;
const ALLOW_RULE_BASE = 1000;

let cosmetic = null;   // { домен: [селекторы] } — встроенные и из списков
let generic = null;    // { cls: {класс: [сел.]}, ids: {id: [сел.]}, exc: {домен: [сел.]}, off: [домены] }

async function loadJson(path) {
  try {
    // no-store: распакованное расширение читает файлы прямо с диска,
    // и свежую отметку сборки нельзя брать из кэша
    const r = await fetch(chrome.runtime.getURL(path), { cache: 'no-store' });
    if (!r.ok) return null;
    return await r.json();
  } catch (e) { return null; }
}

async function getCosmetic() {
  if (cosmetic) return cosmetic;
  const merged = Object.create(null);
  for (const part of [await loadJson('data/cosmetic.json'), await loadJson('data/lists-cosmetic.json')]) {
    if (!part) continue;
    for (const [dom, sels] of Object.entries(part)) {
      if (dom.startsWith('_')) continue;
      (merged[dom] ||= []).push(...sels);
    }
  }
  cosmetic = merged;
  return cosmetic;
}

async function getGeneric() {
  if (generic) return generic;
  const g = await loadJson('data/lists-generic.json') || {};
  generic = {
    cls: g.cls || {}, ids: g.ids || {}, exc: g.exc || {},
    off: new Set(Array.isArray(g.off) ? g.off : [])
  };
  return generic;
}

// Селекторы, которые список отменил на этом сайте (#@#)
function exceptionsFor(host, exc) {
  const out = new Set();
  const parts = host.split('.');
  for (let i = 0; i < parts.length - 1; i++) {
    const list = exc[parts.slice(i).join('.')];
    if (list) for (const x of list) out.add(x);
  }
  return out;
}

function cleanDomain(s) {
  s = String(s || '').trim().toLowerCase();
  if (!s || s.startsWith('#') || s.startsWith('!')) return '';
  s = s.replace(/^[a-z]+:\/\//, '').replace(/^\|\|/, '').replace(/[\^\/].*$/, '').replace(/^\*\./, '').replace(/^www\./, '');
  return /^[a-z0-9.-]+\.[a-z0-9-]+$/.test(s) ? s : '';
}

async function getSettings() {
  const d = await chrome.storage.local.get(['customDomains', 'allow', 'customCss', 'ytEnabled']);
  return {
    customDomains: Array.isArray(d.customDomains) ? d.customDomains : [],
    allow: Array.isArray(d.allow) ? d.allow : [],
    customCss: Array.isArray(d.customCss) ? d.customCss : [],
    ytEnabled: d.ytEnabled !== false
  };
}

// Свои домены и исключения — динамические правила: их можно менять
// без перезагрузки расширения.
async function applyDynamicRules() {
  const s = await getSettings();
  const old = await chrome.declarativeNetRequest.getDynamicRules();
  const add = [];
  const block = s.customDomains.map(cleanDomain).filter(Boolean);
  if (block.length) {
    add.push({ id: CUSTOM_RULE_ID, priority: 1, action: { type: 'block' },
               condition: { requestDomains: [...new Set(block)] } });
  }
  s.allow.map(cleanDomain).filter(Boolean).slice(0, 4000).forEach((d, i) => {
    add.push({ id: ALLOW_RULE_BASE + i, priority: 100, action: { type: 'allowAllRequests' },
               condition: { requestDomains: [d], resourceTypes: ['main_frame', 'sub_frame'] } });
  });
  await chrome.declarativeNetRequest.updateDynamicRules({ removeRuleIds: old.map(r => r.id), addRules: add });
}

function hostMatches(host, dom) {
  return host === dom || host.endsWith('.' + dom);
}

async function pageInfo(host, topHost) {
  host = String(host || '').toLowerCase();
  topHost = String(topHost || host).toLowerCase();
  const s = await getSettings();
  const off = s.allow.map(cleanDomain).some(d => d && (hostMatches(topHost, d) || hostMatches(host, d)));
  if (off) return { off: true };

  const c = await getCosmetic();
  const sels = [];
  // ищем по всем суффиксам: m.vk.com → m.vk.com, vk.com, com
  const parts = host.split('.');
  for (let i = 0; i < parts.length - 1; i++) {
    const dom = parts.slice(i).join('.');
    if (c[dom]) sels.push(...c[dom]);
  }
  const g = await getGeneric();
  const exc = exceptionsFor(host, g.exc);
  for (const line of s.customCss) {
    const t = String(line || '').trim();
    if (!t || t.startsWith('!')) continue;
    const at = t.indexOf('##');
    if (at < 0) { sels.push(t); continue; }
    const doms = t.slice(0, at).split(',').map(x => x.trim().toLowerCase()).filter(Boolean);
    const sel = t.slice(at + 2).trim();
    if (!sel) continue;
    if (!doms.length || doms.some(d => hostMatches(host, d))) sels.push(sel);
  }
  // По одному правилу на селектор: ошибка в одном не выключает остальные
  const css = [...new Set(sels)].filter(x => !exc.has(x)).map(x => x + '{display:none!important}').join('\n');
  const gen = ![...g.off].some(d => hostMatches(host, d) || hostMatches(topHost, d));
  return { off: false, css, gen, yt: s.ytEnabled && (hostMatches(host, 'youtube.com')) };
}

// Общие правила под классы и id, которые страница нашла у себя
async function genericFor(host, cls, ids) {
  const g = await getGeneric();
  host = String(host || '').toLowerCase();
  const exc = exceptionsFor(host, g.exc);
  const out = new Set();
  for (const c of (Array.isArray(cls) ? cls : []).slice(0, 4000)) {
    const l = g.cls[c]; if (l) for (const x of l) if (!exc.has(x)) out.add(x);
  }
  for (const i of (Array.isArray(ids) ? ids : []).slice(0, 4000)) {
    const l = g.ids[i]; if (l) for (const x of l) if (!exc.has(x)) out.add(x);
  }
  return [...out].map(x => x + '{display:none!important}').join('\n');
}

chrome.runtime.onMessage.addListener((msg, sender, reply) => {
  if (!msg || typeof msg !== 'object') return false;
  if (msg.t === 'page') {
    pageInfo(msg.host, msg.top).then(reply, () => reply(null));
    return true;
  }
  if (msg.t === 'gen') {
    genericFor(msg.host, msg.c, msg.i).then(reply, () => reply(''));
    return true;
  }
  if (msg.t === 'reload-cosmetic') { cosmetic = null; generic = null; reply(true); return false; }
  return false;
});

chrome.storage.onChanged.addListener((ch, area) => {
  if (area !== 'local') return;
  if (ch.customDomains || ch.allow) applyDynamicRules();
});

// ---- Самообновление ----
// data/build.json пишет программа CookieGuard каждый раз, когда меняет
// код расширения или списки. Расширение запоминает отметку, с которой
// загрузилось, и раз в минуту сверяет её с той, что на диске.
async function diskStamp() {
  const b = await loadJson('data/build.json');
  return (b && b.stamp) || '';
}

async function rememberStamp() {
  await chrome.storage.local.set({ loadedStamp: await diskStamp() });
}

async function checkForUpdate() {
  const now = await diskStamp();
  if (!now) return;
  const { loadedStamp = '' } = await chrome.storage.local.get('loadedStamp');
  if (now === loadedStamp) return;
  await chrome.storage.local.set({ loadedStamp: now });
  chrome.runtime.reload();
}

async function init() {
  try { await chrome.declarativeNetRequest.setExtensionActionOptions({ displayActionCountAsBadgeText: true }); } catch (e) { }
  try { await chrome.action.setBadgeBackgroundColor({ color: '#3B9EFF' }); } catch (e) { }
  await applyDynamicRules();
  await rememberStamp();
  try { await chrome.alarms.create('cg-update', { periodInMinutes: 1 }); } catch (e) { }
}

chrome.runtime.onInstalled.addListener(init);
chrome.runtime.onStartup.addListener(init);
chrome.alarms.onAlarm.addListener((a) => { if (a.name === 'cg-update') checkForUpdate(); });
// Будильник мог не пережить перезагрузку расширения — заводим при
// каждом пробуждении фоновой части, если его нет.
chrome.alarms.get('cg-update', (a) => { if (!a) chrome.alarms.create('cg-update', { periodInMinutes: 1 }); });
