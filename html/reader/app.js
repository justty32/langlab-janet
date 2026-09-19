// app.js：janet-lab 閱讀器。純前端、file:// 直接開；內容來自 content.js（bin/md-bundle.py 產生），
// markdown 用 vendor/marked.min.js 渲染。hash 路由：#docs/01-語言速成.md 或 #docs/01-語言速成.md#錨點。
// 標題錨點 id 的規則（slugify）對齊 wf/tools/check_anchors.py 的 github_heading_slug，
// 所以 md 裡既有的 [x](y.md#錨點) 連結在這裡照樣能跳。
(function () {
  'use strict';
  const DATA = window.JANET_LAB || { sections: [], manifest: [], files: {} };
  const GH_BLOB = 'https://github.com/justty32/langlab-janet/blob/main/';
  const GH_TREE = 'https://github.com/justty32/langlab-janet/tree/main/';
  const byPath = new Map(DATA.manifest.map((m) => [m.path, m]));
  const $ = (id) => document.getElementById(id);
  const els = { tree: $('rd-tree'), doc: $('rd-doc'), toc: $('rd-toc'), tocInline: $('rd-toc-inline'),
    crumb: $('rd-crumb'), pager: $('rd-pager'), results: $('rd-results'), q: $('rd-q') };
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* 隱私模式等情況就不記 */ } },
  };
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  // ---- 路徑 ----
  function dirOf(p) { const i = p.lastIndexOf('/'); return i < 0 ? '' : p.slice(0, i); }
  function resolvePath(dir, rel) {
    const out = dir ? dir.split('/') : [];
    for (const seg of rel.split('/')) {
      if (seg === '' || seg === '.') continue;
      if (seg === '..') { if (out.length && out[out.length - 1] !== '..') out.pop(); else out.push('..'); }
      else out.push(seg);
    }
    return out.join('/');
  }
  function splitFrag(url) { const i = url.indexOf('#'); return i < 0 ? [url, ''] : [url.slice(0, i), url.slice(i + 1)]; }
  function safeDecode(s) { try { return decodeURIComponent(s); } catch (e) { return s; } }

  // ---- 錨點 id：對齊 check_anchors.py 的 github_heading_slug ----
  function slugify(text) {
    let t = text.replace(/!?\[([^\]]*)\]\([^)]+\)/g, '$1').replace(/<[^>]+>/g, '');
    t = t.normalize('NFKC').trim().toLowerCase();
    t = Array.from(t).filter((ch) => /[\p{L}\p{M}\p{N}\-_\s]/u.test(ch)).join('');
    return t.replace(/\s/g, '-');
  }
  function makeSlugger() {
    const seen = new Map();
    return (text) => { const s = slugify(text); const n = seen.get(s) || 0; seen.set(s, n + 1); return n ? s + '-' + n : s; };
  }

  // ---- Janet 上色：註解／字串／關鍵字／數字／:keyword，沿用 style.css 的 .kw .str .cmt .num ----
  const KW = new Set(('def var fn do if while break quote quasiquote unquote splice set upscope defn defn- def- var- ' +
    'varfn defmacro defmacro- let when unless cond case loop seq for forv each eachp eachk generate try defer protect ' +
    'with with-dyns with-syms match import use require default label prompt yield coro if-let when-let if-not when-not ' +
    'defdyn assert error errorf short-fn toggle edefer defglobal varglobal comptime compif compwhen ev/spawn ev/do-thread ' +
    'ev/with-deadline tracev as-> -> ->> -?> -?>> and or not').split(' '));
  const SYM = /^[^\s()\[\]{}"`;#,'~]+/;
  function hlJanet(src) {
    let out = '', i = 0;
    const span = (cls, s) => { out += '<span class="' + cls + '">' + esc(s) + '</span>'; };
    while (i < src.length) {
      const c = src[i];
      if (c === '#') { const e = src.indexOf('\n', i); const end = e < 0 ? src.length : e; span('cmt', src.slice(i, end)); i = end; continue; }
      if (c === '"') {
        let j = i + 1; while (j < src.length && src[j] !== '"') j += src[j] === '\\' ? 2 : 1;
        span('str', src.slice(i, j + 1)); i = j + 1; continue;
      }
      if (c === '`') {
        let r = 0; while (src[i + r] === '`') r++;
        const close = src.indexOf('`'.repeat(r), i + r); const end = close < 0 ? src.length : close + r;
        span('str', src.slice(i, end)); i = end; continue;
      }
      if (c === '(' || c === '[' || c === '{' || c === '@') {
        const m = SYM.exec(src.slice(i + 1));
        if (c === '(' && m && KW.has(m[0])) { span('kw', '(' + m[0]); i += 1 + m[0].length; continue; }
        out += c; i++; continue;
      }
      const m = SYM.exec(src.slice(i));
      if (m) {
        const w = m[0];
        if (w[0] === ':') span('key', w);
        else if (/^[-+]?(\d[\d_]*(\.\d*)?|\.\d+)([eE][-+]?\d+)?$/.test(w) || /^0x[0-9a-fA-F_]+$/.test(w)) span('num', w);
        else out += esc(w);
        i += w.length; continue;
      }
      out += esc(c); i++;
    }
    return out;
  }

  // ---- marked renderer：標題 id、連結改寫、code 上色 ----
  let cur = { path: '', slug: makeSlugger(), heads: [] };
  function rewrite(href) {
    if (/^(https?:|mailto:|data:)/i.test(href)) return { href, ext: true };
    if (href.startsWith('#')) return { href: '#' + cur.path + '#' + safeDecode(href.slice(1)) };
    const [p, frag] = splitFrag(href);
    const target = resolvePath(dirOf(cur.path), safeDecode(p));
    const tail = frag ? '#' + safeDecode(frag) : '';
    if (byPath.has(target)) return { href: '#' + target + tail };
    if (target.startsWith('html/')) return { href: '../' + target.slice(5) + tail, ext: false };
    return { href: (p.endsWith('/') ? GH_TREE : GH_BLOB) + target + tail, ext: true };
  }
  marked.use({
    gfm: true,
    renderer: {
      heading({ tokens, depth, text }) {
        const id = cur.slug(text);
        const inner = this.parser.parseInline(tokens);
        if (depth === 2 || depth === 3) cur.heads.push({ id, depth, html: inner });
        return `<h${depth} id="${esc(id)}">${inner}<a class="anchor" href="#${esc(cur.path)}#${esc(id)}" aria-label="錨點">#</a></h${depth}>\n`;
      },
      link({ href, title, tokens }) {
        const r = rewrite(href);
        const t = title ? ` title="${esc(title)}"` : '';
        const ext = r.ext ? ' target="_blank" rel="noopener"' : '';
        return `<a href="${esc(r.href)}"${t}${ext}>${this.parser.parseInline(tokens)}</a>`;
      },
      image({ href, title, text }) {
        const src = /^(https?:|data:)/i.test(href) ? href : '../../' + resolvePath(dirOf(cur.path), href);
        return `<img src="${esc(src)}" alt="${esc(text)}"${title ? ` title="${esc(title)}"` : ''}>`;
      },
      code({ text, lang }) {
        const l = (lang || '').trim();
        const body = l === 'janet' ? hlJanet(text) : esc(text);
        return `<pre><code${l ? ` class="language-${esc(l)}"` : ''}>${body}</code></pre>\n`;
      },
    },
  });

  // ---- 目錄樹 ----
  function sectionLabel(key) { const s = DATA.sections.find((x) => x.key === key); return s ? s.label : key; }
  function depthOf(m) { const base = m.section ? m.section.split('/').length : 0; return Math.max(0, m.path.split('/').length - 1 - base); }
  function buildTree() {
    const groups = new Map();
    for (const m of DATA.manifest) { if (!groups.has(m.section)) groups.set(m.section, []); groups.get(m.section).push(m); }
    let html = '';
    for (const [key, items] of groups) {
      const open = (store.get('rd-open') || '').split('\n').includes(key) ? ' open' : '';
      html += `<details data-key="${esc(key)}"${open}><summary>${esc(sectionLabel(key))}<span class="cnt">${items.length}</span></summary><ul>`;
      for (const m of items) html += `<li><a href="#${esc(m.path)}" data-path="${esc(m.path)}" style="--d:${depthOf(m)}" title="${esc(m.path)}">${esc(m.title)}</a></li>`;
      html += '</ul></details>';
    }
    els.tree.innerHTML = html;
    els.tree.addEventListener('toggle', () => {
      const open = [...els.tree.querySelectorAll('details[open]')].map((d) => d.dataset.key);
      store.set('rd-open', open.join('\n'));
    }, true);
    els.tree.addEventListener('click', (e) => { if (e.target.closest('a')) document.body.classList.remove('side-open'); });
  }
  function markTree(path) {
    for (const a of els.tree.querySelectorAll('a.here')) a.classList.remove('here');
    const a = els.tree.querySelector(`a[data-path="${CSS.escape(path)}"]`);
    if (!a) return;
    a.classList.add('here');
    a.closest('details').open = true;
    a.scrollIntoView({ block: 'nearest' });
  }

  // ---- 渲染一篇 ----
  let shown = null;
  function decorate(root) {
    for (const t of root.querySelectorAll('table')) { const d = document.createElement('div'); d.className = 'tbl'; t.replaceWith(d); d.appendChild(t); }
    for (const p of root.querySelectorAll('p, li')) {
      const s = p.textContent.trimStart();
      if (s.startsWith('⚠')) p.classList.add('warn'); else if (s.startsWith('★')) p.classList.add('tip');
    }
    for (const pre of root.querySelectorAll('pre')) {
      const b = document.createElement('button'); b.type = 'button'; b.className = 'copy'; b.textContent = '複製';
      b.addEventListener('click', () => {
        const code = pre.querySelector('code'); const text = code ? code.textContent : pre.textContent;
        const done = () => { b.textContent = '已複製'; b.classList.add('ok'); setTimeout(() => { b.textContent = '複製'; b.classList.remove('ok'); }, 1200); };
        if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, () => fallbackCopy(text, done));
        else fallbackCopy(text, done);
      });
      pre.appendChild(b);
    }
  }
  function fallbackCopy(text, done) {
    const ta = document.createElement('textarea'); ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); done(); } catch (e) { /* 沒辦法就算了 */ }
    ta.remove();
  }
  function renderDoc(path) {
    const m = byPath.get(path);
    cur = { path, slug: makeSlugger(), heads: [] };
    els.doc.innerHTML = marked.parse(DATA.files[path]);
    decorate(els.doc);
    shown = path;
    document.title = (m.title || path) + ' · janet-lab';
    const parts = path.split('/');
    els.crumb.innerHTML = parts.map((s, i) => i < parts.length - 1 ? esc(s) + ' /' : `<code>${esc(s)}</code>`).join(' ') +
      ` <a href="${GH_BLOB + esc(path)}" target="_blank" rel="noopener">在 GitHub 看原文 ↗</a>`;
    const toc = cur.heads.map((h) => `<a class="h${h.depth}" href="#${esc(path)}#${esc(h.id)}">${h.html}</a>`).join('');
    els.toc.innerHTML = toc ? '<p class="t">本頁目錄</p>' + toc : '';
    els.tocInline.querySelector('div').innerHTML = toc;
    els.tocInline.hidden = !toc;
    const list = DATA.manifest.filter((x) => x.section === m.section);
    const i = list.findIndex((x) => x.path === path);
    const link = (x, cls, label) => x ? `<a class="${cls}" href="#${esc(x.path)}"><span>${label}</span>${esc(x.title)}</a>` : '<span></span>';
    els.pager.innerHTML = link(list[i - 1], 'prev', '← 上一篇') + link(list[i + 1], 'next', '下一篇 →');
    markTree(path);
  }
  function showMissing(path) {
    shown = null;
    els.doc.innerHTML = `<div class="missing"><p>找不到 <code>${esc(path)}</code>。</p><p>可能是檔案改名了而 <code>content.js</code> 還沒重新產生：跑 <code>python3 bin/md-bundle.py</code>。</p></div>`;
    els.crumb.innerHTML = ''; els.toc.innerHTML = ''; els.tocInline.hidden = true; els.pager.innerHTML = '';
    document.title = 'janet-lab 閱讀器';
  }
  function route() {
    const h = safeDecode(location.hash.slice(1));
    const i = h.indexOf('#');
    const path = (i < 0 ? h : h.slice(0, i)) || 'README.md';
    const frag = i < 0 ? '' : h.slice(i + 1);
    clearSearch();
    if (!byPath.has(path)) return showMissing(path);
    if (path !== shown) renderDoc(path);
    if (frag) { const el = document.getElementById(frag); if (el) el.scrollIntoView(); else window.scrollTo(0, 0); }
    else window.scrollTo(0, 0);
  }

  // ---- 全文搜尋（純前端，子字串、不分大小寫、多詞 AND）----
  const lower = new Map();
  function lowerOf(path) { if (!lower.has(path)) lower.set(path, DATA.files[path].toLowerCase()); return lower.get(path); }
  function headingBefore(text, offset) {
    // 命中位置往前最近的標題（跳過 fence），回它的錨點 id；沒有就空字串
    const slug = makeSlugger(); let fence = null, best = '';
    const lines = text.slice(0, offset).split('\n');
    const all = text.split('\n');
    for (let k = 0; k < all.length; k++) {
      const line = all[k];
      const f = /^\s*(`{3,}|~{3,})/.exec(line);
      if (f) { fence = fence === f[1] ? null : (fence || f[1]); continue; }
      if (fence) continue;
      const hm = /^\s{0,3}#{1,6}\s+(.+?)\s*$/.exec(line);
      if (!hm) continue;
      const id = slug(hm[1].replace(/\s+#+\s*$/, ''));
      if (k < lines.length) best = id;
    }
    return best;
  }
  function snippet(text, at, len) {
    const a = Math.max(0, at - 40), b = Math.min(text.length, at + len + 60);
    return (a > 0 ? '…' : '') + esc(text.slice(a, at)) + '<mark>' + esc(text.slice(at, at + len)) + '</mark>' + esc(text.slice(at + len, b)) + (b < text.length ? '…' : '');
  }
  function search(q) {
    const terms = q.toLowerCase().split(/\s+/).filter(Boolean);
    if (!terms.length) return clearSearch();
    const hits = [];
    for (const m of DATA.manifest) {
      const lo = lowerOf(m.path);
      if (!terms.every((t) => lo.includes(t))) continue;
      const positions = []; let at = -1, count = 0;
      while ((at = lo.indexOf(terms[0], at + 1)) >= 0 && count < 200) { count++; if (positions.length < 3 && (positions.length === 0 || at - positions[positions.length - 1] > 120)) positions.push(at); }
      hits.push({ m, count, positions });
    }
    hits.sort((x, y) => y.count - x.count);
    const text = (p) => DATA.files[p];
    let html = `<p class="sum">${hits.length} 篇命中「${esc(q)}」（依命中次數排）</p>`;
    for (const h of hits.slice(0, 80)) {
      html += `<div class="hit"><b><a href="#${esc(h.m.path)}">${esc(h.m.title)}</a><span class="sec">${esc(h.m.path)} · ${h.count} 處</span></b>`;
      for (const at of h.positions) {
        const id = headingBefore(text(h.m.path), at);
        html += `<a class="snip" href="#${esc(h.m.path)}${id ? '#' + esc(id) : ''}">${snippet(text(h.m.path), at, terms[0].length).replace(/\n/g, ' ')}</a>`;
      }
      html += '</div>';
    }
    els.results.innerHTML = html; els.results.hidden = false;
    els.doc.hidden = true; els.crumb.hidden = true; els.pager.hidden = true; els.tocInline.hidden = true; els.toc.hidden = true;
  }
  function clearSearch() {
    if (els.results.hidden) return;
    els.results.hidden = true; els.results.innerHTML = '';
    els.doc.hidden = false; els.crumb.hidden = false; els.pager.hidden = false; els.toc.hidden = false;
    els.tocInline.hidden = !els.tocInline.querySelector('div').innerHTML;
  }
  let timer = null;
  els.q.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(() => (els.q.value.trim() ? search(els.q.value) : clearSearch()), 160); });
  els.q.addEventListener('keydown', (e) => { if (e.key === 'Escape') { els.q.value = ''; clearSearch(); els.q.blur(); } });
  els.results.addEventListener('click', (e) => { if (e.target.closest('a')) { els.q.value = ''; } });

  // ---- 主題、側欄 ----
  const root = document.documentElement;
  function applyTheme(t) { if (t) root.setAttribute('data-theme', t); else root.removeAttribute('data-theme'); }
  applyTheme(store.get('rd-theme'));
  $('rd-theme').addEventListener('click', () => {
    const dark = root.getAttribute('data-theme') ? root.getAttribute('data-theme') === 'dark' : matchMedia('(prefers-color-scheme:dark)').matches;
    const next = dark ? 'light' : 'dark'; applyTheme(next); store.set('rd-theme', next);
  });
  $('rd-menu').addEventListener('click', () => document.body.classList.toggle('side-open'));
  $('rd-scrim').addEventListener('click', () => document.body.classList.remove('side-open'));
  document.addEventListener('keydown', (e) => { if (e.key === '/' && document.activeElement !== els.q) { e.preventDefault(); els.q.focus(); } });

  buildTree();
  window.addEventListener('hashchange', route);
  route();
  // ?q=詞 可以直接開一個搜尋結果頁（分享用；headless 驗證也靠它）
  const q0 = new URLSearchParams(location.search).get('q');
  if (q0) { els.q.value = q0; search(q0); }
})();
