// app.js：janet-lab 閱讀器＝整個網站。純前端、file:// 直接開；內容全部來自 content.js（bin/md-bundle.py 打包），
// markdown 用 vendor/marked.min.js 渲染。hash 路由：#docs/01-語言速成.md 或 #docs/01-語言速成.md#錨點；沒有 hash 是首頁。
// 首頁的路線卡片是下面的 HOME_CARDS（bin/md-bundle.py --check 會驗這些 md 存在），各區篇目全由 manifest 產生：
// 新增一篇 md → 跑 python3 bin/md-bundle.py → 首頁、側欄、搜尋自動出現，零手工。
// 標題錨點 id 的規則（slugify）對齊 wf/tools/check_anchors.py 的 github_heading_slug，md 裡既有的 #錨點 連結照樣能跳。
(function () {
  'use strict';
  // ---- 首頁固定路線卡片（唯一手寫的導航；路徑由 md-bundle.py --check 驗證）----
  const HOME_CARDS = [
    { md: 'docs/README.md', title: '教學目錄', blurb: 'docs/ 00 → 47 逐篇遞進；不知道從哪讀起就開這頁' },
    { md: 'docs/路線圖.md', title: '路線圖', blurb: '從零到能寫工具的建議順序' },
    { md: 'docs/怎麼做-X.md', title: '怎麼做 X', blurb: '按任務排的索引，每列給教學／可跑／可抄三欄' },
    { md: 'docs/從別的語言過來-索引.md', title: '從別的語言過來', blurb: 'C／Lua／Go／Python 逐條對照（43–46）' },
    { md: 'docs/47-llm-api-是什麼.md', title: '從零寫 AI agent', blurb: '47–47g 七篇：LLM API → tool loop → 記憶 → 接真後端，離線就能跑' },
    { md: 'reference/README.md', title: 'reference 全表', blurb: '查「有哪些可用」：內建從 root-env 逐一列舉，spork 收常用' },
    { md: 'modules/README.md', title: 'modules', blurb: 'llm-http／agent／pi-shell／aos，真的拿來用的模組' },
    { md: 'cheatsheets/README.md', title: '速查表', blurb: '七頁一眼掃完：核心、資料/IO、PEG、並行、C 互通、env、地雷' },
    { md: 'cheatsheets/地雷.md', title: '地雷', blurb: '「這行為怪怪的，是不是已知的坑？」全部實測過，每條標了出處' },
  ];
  const BLURB = {
    'cheatsheets': '一眼掃完的速查，兩欄卡片版', 'docs': '分篇教學，00 → 47 逐篇遞進；沒篇號的是索引與路線',
    'reference': '查「有哪些可用」：內建的從 root-env 逐一列舉', 'reference/spork': 'spork 常用模組逐一列出函式與簽名',
    'modules': '真的拿來用的小模組，各自有 README 與 doc/', 'examples': '配合 docs 某一篇的可跑範例',
    'snippets': '「我要做 X，抄哪段」的可貼可改片段', 'exercises': '專挑 ⚠ 陷阱的題目，附解答',
    'try': '從零寫一個 LLM 客戶端的過程', '': 'repo 說明與實測筆記（README／FINDINGS）',
  };
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

  // ---- Janet 上色：註解／字串／關鍵字／數字／:keyword（.kw .str .cmt .num .key）----
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
    if (target === 'html/index.html' || target === 'html/' || target === 'html') return { href: '#' };
    if (target.startsWith('html/')) return { href: target.slice(5) + tail, ext: false };
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
        const src = /^(https?:|data:)/i.test(href) ? href : '../' + resolvePath(dirOf(cur.path), href);
        return `<img src="${esc(src)}" alt="${esc(text)}"${title ? ` title="${esc(title)}"` : ''}>`;
      },
      code({ text, lang }) {
        const l = (lang || '').trim();
        const body = l === 'janet' ? hlJanet(text) : esc(text);
        return `<pre><code${l ? ` class="language-${esc(l)}"` : ''}>${body}</code></pre>\n`;
      },
    },
  });

  // ---- 目錄樹（全由 manifest 產生）----
  function sectionLabel(key) { const s = DATA.sections.find((x) => x.key === key); return s ? s.label : key; }
  function depthOf(m) { const base = m.section ? m.section.split('/').length : 0; return Math.max(0, m.path.split('/').length - 1 - base); }
  function groupsOf() {
    const groups = new Map();
    for (const m of DATA.manifest) { if (!groups.has(m.section)) groups.set(m.section, []); groups.get(m.section).push(m); }
    return groups;
  }
  function buildTree() {
    let html = '';
    for (const [key, items] of groupsOf()) {
      const open = (store.get('rd-open') || '').split('\n').includes(key) ? ' open' : '';
      html += `<details data-key="${esc(key)}"${open}><summary>${esc(sectionLabel(key))}<span class="cnt">${items.length}</span></summary><ul>`;
      for (const m of items) html += `<li><a href="#${esc(m.path)}" data-path="${esc(m.path)}" style="--d:${depthOf(m)}" title="${esc(m.path)}">${esc(m.title)}</a></li>`;
      html += '</ul></details>';
    }
    els.tree.innerHTML = html;
    els.tree.addEventListener('toggle', () => {
      store.set('rd-open', [...els.tree.querySelectorAll('details[open]')].map((d) => d.dataset.key).join('\n'));
    }, true);
    els.tree.addEventListener('click', (e) => { if (e.target.closest('a')) document.body.classList.remove('side-open'); });
  }
  function markTree(path) {
    for (const a of els.tree.querySelectorAll('a.here')) a.classList.remove('here');
    const a = path && els.tree.querySelector(`a[data-path="${CSS.escape(path)}"]`);
    if (!a) return;
    a.classList.add('here');
    a.closest('details').open = true;
    a.scrollIntoView({ block: 'nearest' });
  }

  // ---- 渲染一篇 ----
  let shown = null;
  function decorate(root) {
    for (const t of root.querySelectorAll('table')) { const d = document.createElement('div'); d.className = 'tbl'; t.replaceWith(d); d.appendChild(t); }
    for (const p of root.querySelectorAll('p, li, blockquote')) {
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
  function cardify(root) {
    // 速查表：H1 與第一個 H2 之前的東西一張寬卡，之後每個 H2 一張卡
    const grid = document.createElement('div'); grid.className = 'cs-grid';
    let sec = document.createElement('section'); sec.className = 'wide';
    for (const node of [...root.childNodes]) {
      if (node.nodeType === 1 && node.tagName === 'H2') {
        if (sec.childNodes.length) grid.appendChild(sec);
        sec = document.createElement('section');
      }
      sec.appendChild(node);
    }
    if (sec.childNodes.length) grid.appendChild(sec);
    if (grid.children.length === 2) grid.children[1].classList.add('wide');  // 只有一個 H2 的頁不用留半欄空白
    root.appendChild(grid);
  }
  function chrome(on) {
    els.crumb.hidden = !on; els.pager.hidden = !on; els.toc.hidden = !on;
    if (!on) { els.tocInline.hidden = true; els.toc.innerHTML = ''; els.pager.innerHTML = ''; els.crumb.innerHTML = ''; }
  }
  function renderDoc(path) {
    const m = byPath.get(path);
    cur = { path, slug: makeSlugger(), heads: [] };
    els.doc.classList.remove('home');
    els.doc.classList.toggle('cheat', m.section === 'cheatsheets');
    els.doc.innerHTML = marked.parse(DATA.files[path]);
    decorate(els.doc);
    if (m.section === 'cheatsheets') cardify(els.doc);
    shown = path;
    document.title = (m.title || path) + ' · janet-lab';
    chrome(true);
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
  function renderHome() {
    cur = { path: '', slug: makeSlugger(), heads: [] };
    shown = '';
    els.doc.classList.remove('cheat'); els.doc.classList.add('home');
    chrome(false);
    document.title = 'janet-lab';
    let html = '<h1>janet-lab</h1><p class="sub">Janet 語言的遊樂場：教學、速查表、全表、模組、範例、實測筆記——全部在這一頁找得到，上方可全文搜尋。</p>';
    html += '<h2><span class="n">▤</span> 路線</h2><div class="cards">';
    for (const c of HOME_CARDS) {
      const m = byPath.get(c.md);
      html += `<a class="card" href="#${esc(c.md)}"><b>${esc(c.title)}</b><span>${esc(c.blurb)}</span><small>${esc(c.md)}${m ? '' : '（不在 bundle 裡）'}</small></a>`;
    }
    html += '</div>';
    let n = 0;
    for (const [key, items] of groupsOf()) {
      n++;
      html += `<h2><span class="n">${String(n).padStart(2, '0')}</span> ${esc(sectionLabel(key))}<span class="blurb">${esc(BLURB[key] || '')} · ${items.length} 篇</span></h2><div class="list">`;
      for (const m of items) {
        const cls = (m.readme ? 'readme' : '') + (depthOf(m) > 0 && !m.readme ? ' sub' : '');
        const num = m.num ? `<span class="num">${esc(m.num)}</span>` : '';
        html += `<a class="${cls.trim()}" href="#${esc(m.path)}" title="${esc(m.path)}"><b>${num}${esc(m.title)}</b><span>${esc(m.summary)}</span></a>`;
      }
      html += '</div>';
    }
    els.doc.innerHTML = html;
    markTree('');
    window.scrollTo(0, 0);
  }
  function showMissing(path) {
    shown = null;
    els.doc.classList.remove('cheat', 'home');
    chrome(false);
    els.doc.innerHTML = `<div class="missing"><p>找不到 <code>${esc(path)}</code>。</p><p>可能是檔案改名了而 <code>content.js</code> 還沒重新產生：跑 <code>python3 bin/md-bundle.py</code>。</p><p><a href="#">回首頁</a></p></div>`;
    document.title = 'janet-lab';
  }
  function route() {
    const h = safeDecode(location.hash.slice(1));
    const i = h.indexOf('#');
    const path = i < 0 ? h : h.slice(0, i);
    const frag = i < 0 ? '' : h.slice(i + 1);
    clearSearch();
    if (!path) return renderHome();
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
    const upto = text.slice(0, offset).split('\n').length;
    const all = text.split('\n');
    for (let k = 0; k < all.length && k < upto; k++) {
      const line = all[k];
      const f = /^\s*(`{3,}|~{3,})/.exec(line);
      if (f) { fence = fence === f[1] ? null : (fence || f[1]); continue; }
      if (fence) continue;
      const hm = /^\s{0,3}#{1,6}\s+(.+?)\s*$/.exec(line);
      if (hm) best = slug(hm[1].replace(/\s+#+\s*$/, ''));
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
    let html = `<p class="sum">${hits.length} 篇命中「${esc(q)}」（依命中次數排）</p>`;
    for (const h of hits.slice(0, 80)) {
      const text = DATA.files[h.m.path];
      html += `<div class="hit"><b><a href="#${esc(h.m.path)}">${esc(h.m.title)}</a><span class="sec">${esc(h.m.path)} · ${h.count} 處</span></b>`;
      for (const at of h.positions) {
        const id = headingBefore(text, at);
        html += `<a class="snip" href="#${esc(h.m.path)}${id ? '#' + esc(id) : ''}">${snippet(text, at, terms[0].length).replace(/\n/g, ' ')}</a>`;
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

  // ---- 主題、側欄、快捷鍵 ----
  const root = document.documentElement;
  const params = new URLSearchParams(location.search);
  function applyTheme(t) { if (t) root.setAttribute('data-theme', t); else root.removeAttribute('data-theme'); }
  applyTheme(params.get('theme') || store.get('rd-theme'));  // ?theme=dark 可強制（截圖驗證用）
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
  const q0 = params.get('q');  // ?q=詞 直接開搜尋結果（分享用；headless 驗證也靠它）
  if (q0) { els.q.value = q0; search(q0); }
})();
