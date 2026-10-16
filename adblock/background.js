// CookieGuard AdBlock — фоновая часть.
//
// Сетевые запросы блокирует не этот код, а сам браузер: правила
// лежат в rules/*.json и применяются движком declarativeNetRequest.
// Расширение ваших запросов не видит и видеть не может — у него нет
// ни права webRequest, ни доступа к адресам. Строка connect-src 'self'
// в manifest.json запрещает этому коду ходить в сеть вообще.
//
// Здесь только три вещи:
//   — правила пользователя (свои домены и сайты-исключения);
//   — CSS для скрытия рекламных блоков на конкретном сайте;
//   — значок со счётчиком заблокированного.

const CUSTOM_RULE_ID = 1;
const ALLOW_RULE_BASE = 1000;

let cosmetic = null;   // { домен: [селекторы] } — встроенные и из списков

async function loadJson(path) {
  try {
    const r = await fetch(chrome.runtime.getURL(path));
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
  const css = [...new Set(sels)].map(x => x + '{display:none!important}').join('\n');
  return { off: false, css, yt: s.ytEnabled && (hostMatches(host, 'youtube.com')) };
}

chrome.runtime.onMessage.addListener((msg, sender, reply) => {
  if (!msg || typeof msg !== 'object') return false;
  if (msg.t === 'page') {
    pageInfo(msg.host, msg.top).then(reply, () => reply(null));
    return true;
  }
  if (msg.t === 'reload-cosmetic') { cosmetic = null; reply(true); return false; }
  return false;
});

chrome.storage.onChanged.addListener((ch, area) => {
  if (area !== 'local') return;
  if (ch.customDomains || ch.allow) applyDynamicRules();
});

async function init() {
  try { await chrome.declarativeNetRequest.setExtensionActionOptions({ displayActionCountAsBadgeText: true }); } catch (e) { }
  try { await chrome.action.setBadgeBackgroundColor({ color: '#3B9EFF' }); } catch (e) { }
  await applyDynamicRules();
}

chrome.runtime.onInstalled.addListener(init);
chrome.runtime.onStartup.addListener(init);
