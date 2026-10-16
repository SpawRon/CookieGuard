// CookieGuard AdBlock — реклама в видео YouTube.
//
// Рекламу в ролик подкладывает сам ответ сервера: в описании ролика
// есть поля adPlacements, adSlots и playerAds. Блокировать запрос
// нельзя — в том же ответе само видео. Поэтому поля вырезаются из
// ответа, пока его не прочитал плеер. Тем же способом это делает
// uBlock Origin.
//
// Скрипт работает в мире страницы (иначе до ответа не дотянуться)
// и только удаляет поля. Он ничего не отправляет и ничего не читает
// о вас. Если YouTube сменит формат, сработает запасной путь в
// content.js — проматывание и «Пропустить».

(() => {
  try { if (localStorage.getItem('cgab-off') === '1') return; } catch (e) { }

  const KEYS = ['adPlacements', 'adSlots', 'playerAds', 'adBreakHeartbeatParams'];

  const prune = (o, depth = 0) => {
    if (!o || typeof o !== 'object' || depth > 3) return o;
    for (const k of KEYS) if (k in o) { try { delete o[k]; } catch (e) { } }
    if (o.playerResponse) prune(o.playerResponse, depth + 1);
    if (Array.isArray(o)) for (const x of o) prune(x, depth + 1);
    return o;
  };
  const hasAds = (o) => !!o && typeof o === 'object' &&
    (KEYS.some(k => k in o) || (o.playerResponse && typeof o.playerResponse === 'object') || Array.isArray(o));

  // 1) JSON.parse — так плеер разбирает большинство ответов
  const origParse = JSON.parse;
  JSON.parse = function (...a) {
    const r = origParse.apply(this, a);
    try { if (hasAds(r)) prune(r); } catch (e) { }
    return r;
  };

  // 2) Response.json — ответы /youtubei/v1/player через fetch
  const origJson = Response.prototype.json;
  Response.prototype.json = function () {
    return origJson.call(this).then(r => { try { prune(r); } catch (e) { } return r; });
  };

  // 3) ответ, встроенный прямо в страницу при первой загрузке
  for (const name of ['ytInitialPlayerResponse', 'playerResponse']) {
    let val;
    try {
      Object.defineProperty(window, name, {
        configurable: true,
        get() { return val; },
        set(v) { val = prune(v); }
      });
    } catch (e) { }
  }
})();
