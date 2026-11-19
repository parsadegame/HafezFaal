// Functional harness: runs the generated page script against a minimal DOM stub.
// Usage: node tests/page-test.js
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const htmlPath = path.join(__dirname, '..', 'app', 'src', 'main', 'assets', 'hafez-faal.html');

class ClassList {
  constructor() { this.set = new Set(); }
  add(...c) { c.forEach(x => this.set.add(x)); }
  remove(...c) { c.forEach(x => this.set.delete(x)); }
  contains(c) { return this.set.has(c); }
  toggle(c) { this.set.has(c) ? this.set.delete(c) : this.set.add(c); }
}

class El {
  constructor(tag, id) {
    this.tagName = tag; this.id = id || ''; this.nodeType = 1;
    this.children = []; this.parentNode = null;
    this.classList = new ClassList();
    this.attrs = {}; this.listeners = {};
    this.style = { setProperty(k, v) { this[k] = v; } };
    this._text = ''; this._html = '';
  }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; }
  appendChild(child) {
    if (child && child.nodeType === 11) {
      child.children.forEach(c => { c.parentNode = this; this.children.push(c); });
      child.children = [];
    } else {
      child.parentNode = this; this.children.push(child);
    }
    return child;
  }
  addEventListener(t, fn) { (this.listeners[t] = this.listeners[t] || []).push(fn); }
  get textContent() { return this._text; }
  set textContent(v) { this._text = String(v); this.children = []; }
  get innerHTML() { return this._html; }
  set innerHTML(v) { this._html = String(v); if (v === '') { this.children = []; } }
  get className() { return Array.from(this.classList.set).join(' '); }
  set className(v) { this.classList.set = new Set(String(v).split(/\s+/).filter(Boolean)); }
  closest(sel) {
    const cls = sel.replace(/^\./, '');
    let n = this;
    while (n) { if (n.classList.contains(cls)) return n; n = n.parentNode; }
    return null;
  }
  querySelectorAll(sel) {
    const all = [];
    (function walk(node) {
      node.children.forEach(c => { all.push(c); walk(c); });
    })(this);

    let m = sel.match(/^\.([\w-]+)\.([\w-]+)$/);
    if (m) return all.filter(e => e.classList.contains(m[1]) && e.classList.contains(m[2]));

    m = sel.match(/^\.([\w-]+)\[data-index="(\d+)"\]$/);
    if (m) return all.filter(e => e.classList.contains(m[1]) && e.getAttribute('data-index') === m[2]);

    m = sel.match(/^\.([\w-]+)$/);
    if (m) return all.filter(e => e.classList.contains(m[1]));

    return [];
  }
  querySelector(sel) { return this.querySelectorAll(sel)[0] || null; }
  scrollIntoView() {}
}

const byId = new Map();
function el(id) {
  if (!byId.has(id)) byId.set(id, new El('div', id));
  return byId.get(id);
}

const document = {
  documentElement: new El('html'),
  body: new El('body'),
  listeners: {},
  getElementById: el,
  createElement: tag => new El(tag),
  createDocumentFragment: () => ({ nodeType: 11, children: [], appendChild(c) { this.children.push(c); } }),
  addEventListener(t, fn) { (this.listeners[t] = this.listeners[t] || []).push(fn); }
};

const store = {};
const window = {
  listeners: {},
  localStorage: {
    getItem: k => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); }
  },
  addEventListener(t, fn) { (this.listeners[t] = this.listeners[t] || []).push(fn); }
};

const html = fs.readFileSync(htmlPath, 'utf8');
const js = html.match(/<script>([\s\S]*?)<\/script>/)[1];

let failures = 0;
function check(name, ok, detail) {
  if (!ok) { failures++; }
  console.log((ok ? 'PASS  ' : 'FAIL  ') + name + (detail ? '  [' + detail + ']' : ''));
}

const ctx = vm.createContext({ document, window, console, parseInt, isNaN, String, Math, Array });

// Seed initial classes declared in the markup (the stub does not parse HTML).
const tagRe = /<[a-zA-Z0-9]+\b[^>]*\bid="([^"]+)"[^>]*>/g;
let tagMatch;
while ((tagMatch = tagRe.exec(html))) {
  const id = tagMatch[1];
  const cls = tagMatch[0].match(/\bclass="([^"]*)"/);
  if (cls) {
    el(id).classList.set = new Set(cls[1].split(/\s+/).filter(Boolean));
  }
}

vm.runInContext(js, ctx);
(window.listeners.load || []).forEach(fn => fn());

const list = el('poemList');
const items = list.querySelectorAll('.poem-item');
const meta = el('poemMeta');
const poemBox = el('poemBox');
const interp = el('interpretationBox');
const menu = el('menu');
const overlay = el('overlay');
const intro = el('intro');
const result = el('result');
const rootStyle = document.documentElement.style;

check('menu lists all 495 poems', items.length === 495, 'got ' + items.length);
check('count label is Persian', el('menuCount').textContent === '۴۹۵ فال', el('menuCount').textContent);
check('poem hidden before pressing', result.classList.contains('is-hidden'));
check('intro shown before pressing', !intro.classList.contains('is-hidden'));
check('no poem text before pressing', poemBox.textContent === '');

el('faalBtn').listeners.click[0]();
check('button reveals the result', !result.classList.contains('is-hidden'));
check('button hides the intro', intro.classList.contains('is-hidden'));
check('result animates in', result.classList.contains('reveal'));
check('a poem is shown after pressing', poemBox.textContent.length > 20);
check('poem meta has a number', meta.innerHTML.indexOf('فال شمارهٔ') >= 0);
check('exactly one active item', list.querySelectorAll('.poem-item.active').length === 1);

el('menuBtn').listeners.click[0]();
check('hamburger opens drawer', menu.classList.contains('open') && overlay.classList.contains('show'));
check('body scroll locked', document.body.classList.contains('menu-open'));

const target = list.querySelector('.poem-item[data-index="99"]');
list.listeners.click[0]({ target });
check('selecting poem shows text', poemBox.textContent.length > 20);
check('selecting poem updates number', meta.innerHTML.indexOf('۱۰۰') >= 0);
check('interpretation is shown', interp.textContent.length > 10);
check('drawer closes after selection', !menu.classList.contains('open'));
check('body scroll restored', !document.body.classList.contains('menu-open'));
check('selected item highlighted', list.querySelectorAll('.poem-item.active')[0].getAttribute('data-index') === '99');

const poemRule = html.match(/\.poem\s*\{[^}]*font-size:\s*var\(--font-size\)/);
const interpRule = html.match(/\.interp-text\s*\{[^}]*font-size:\s*var\(--font-size\)/);
check('poem uses the size variable', !!poemRule);
check('interpretation uses the same size variable', !!interpRule);
check('no separate interpretation size remains', html.indexOf('--interp-size') < 0);
check('poem font var set', rootStyle['--font-size'] === '21px', rootStyle['--font-size']);
check('decorative background pattern present', html.indexOf('data:image/svg+xml') >= 0);
check('hidden-result rule present', /\.result\.is-hidden\s*\{\s*display:\s*none/.test(html));

el('plus-btn').listeners.click[0]();
check('plus grows both (shared var)', rootStyle['--font-size'] === '23px', rootStyle['--font-size']);
check('font size persisted', store['hafez.fontSize'] === '23', store['hafez.fontSize']);

el('minus-btn').listeners.click[0]();
check('minus shrinks both (shared var)', rootStyle['--font-size'] === '21px', rootStyle['--font-size']);

console.log('');
console.log(failures === 0 ? 'ALL CHECKS PASSED' : failures + ' CHECK(S) FAILED');
process.exit(failures === 0 ? 0 : 1);
