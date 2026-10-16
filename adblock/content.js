// CookieGuard AdBlock — скрытие рекламных блоков на странице.
//
// Этот код только добавляет на страницу стиль «спрятать вот это» и на
// YouTube нажимает «Пропустить». Он ничего не читает со страницы,
// ничего не сохраняет и никуда не отправляет — сетевых вызовов здесь
// нет ни одного.

(() => {
  const root = document.documentElement;
  if (!root) return;

  let top = location.hostname;
  try {
    const anc = location.ancestorOrigins;
    if (anc && anc.length) top = new URL(anc[anc.length - 1]).hostname;
  } catch (e) { }

  const setFlag = (on) => {
    // Флаг для yt.js: он живёт в мире страницы и до настроек
    // расширения не дотягивается. Читается при следующей загрузке.
    try { if (on) localStorage.setItem('cgab-off', '1'); else localStorage.removeItem('cgab-off'); } catch (e) { }
  };

  let reply;
  try {
    chrome.runtime.sendMessage({ t: 'page', host: location.hostname, top }, (r) => {
      void chrome.runtime.lastError;
      reply = r;
      if (!r) return;
      if (r.off) {
        root.setAttribute('data-cgab-off', '');
        setFlag(true);
        return;
      }
      setFlag(false);
      if (r.css) {
        const st = document.createElement('style');
        st.setAttribute('data-cgab', '');
        st.textContent = r.css;
        (document.head || root).appendChild(st);
        // Некоторые сайты пересобирают <head>: возвращаем стиль на место
        new MutationObserver(() => {
          if (!st.isConnected) (document.head || document.documentElement).appendChild(st);
        }).observe(document.documentElement, { childList: true, subtree: false });
      }
      if (r.gen) startGeneric();
      if (r.yt && window === window.top) startYouTube();
    });
  } catch (e) { }

  // ---- Общие правила скрытия ----
  // Списки знают десятки тысяч рекламных классов и id («.ad-banner»,
  // «#sponsored-top»). Все разом на страницу не кладутся: вместо этого
  // страница собирает имена классов и id, которые в ней реально есть,
  // и получает только подходящие правила. Наружу ничего не уходит —
  // только в фоновую часть этого же расширения.
  function startGeneric() {
    const seenC = new Set(), seenI = new Set();
    let newC = [], newI = [], timer = 0, style = null;

    const take = (el) => {
      if (!el || el.nodeType !== 1) return;
      const id = el.id;
      if (id && typeof id === 'string' && !seenI.has(id)) { seenI.add(id); newI.push(id); }
      const cl = el.classList;
      if (cl) for (let i = 0; i < cl.length; i++) {
        const c = cl[i];
        if (!seenC.has(c)) { seenC.add(c); newC.push(c); }
      }
    };
    const scan = (node) => {
      take(node);
      if (node.querySelectorAll) node.querySelectorAll('[id],[class]').forEach(take);
    };
    const flush = () => {
      timer = 0;
      if (!newC.length && !newI.length) return;
      const c = newC, i = newI;
      newC = []; newI = [];
      try {
        chrome.runtime.sendMessage({ t: 'gen', host: location.hostname, c, i }, (css) => {
          void chrome.runtime.lastError;
          if (!css) return;
          if (!style) {
            style = document.createElement('style');
            style.setAttribute('data-cgab-gen', '');
          }
          style.textContent += css + '\n';
          if (!style.isConnected) (document.head || document.documentElement).appendChild(style);
        });
      } catch (e) { }
    };
    const later = () => { if (!timer) timer = setTimeout(flush, 120); };

    const go = () => {
      scan(document.documentElement);
      flush();
      new MutationObserver((muts) => {
        for (const m of muts) {
          if (m.type === 'attributes') take(m.target);
          else for (const n of m.addedNodes) scan(n);
        }
        later();
      }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['class', 'id'] });
    };
    if (document.readyState === 'loading') {
      // до готовности страницы — то, что уже пришло, и ещё раз по готовности
      scan(document.documentElement); later();
      document.addEventListener('DOMContentLoaded', go, { once: true });
    } else go();
  }

  // ---- YouTube: запасной путь, если реклама всё же началась ----
  // Основную работу делает yt.js — вырезает рекламу из ответа сервера
  // ещё до того, как плеер её увидит. Если YouTube поменяет формат и
  // реклама проскочит, здесь её проматывают до конца и жмут «Пропустить».
  function startYouTube() {
    const tick = () => {
      const p = document.querySelector('.html5-video-player.ad-showing, .html5-video-player.ad-interrupting');
      if (p) {
        const v = p.querySelector('video');
        if (v) {
          v.muted = true;
          if (isFinite(v.duration) && v.duration > 0 && v.currentTime < v.duration - 0.2) {
            try { v.currentTime = v.duration; } catch (e) { }
          }
          try { v.playbackRate = 16; } catch (e) { }
        }
        const skip = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, button[id^="skip-button"]');
        if (skip) skip.click();
      }
      const close = document.querySelector('.ytp-ad-overlay-close-button');
      if (close) close.click();
    };
    setInterval(tick, 300);
  }
})();
