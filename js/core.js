'use strict';
// =====================================================================
//  ULTIMA LANTERNA - core: costanti, utilita', RNG, input
// =====================================================================

const VERSION = 'beta 0.9.0';
const W = 480, H = 270, TS = 16;
const RW = 29, RH = 15;          // dimensioni stanza in tile (muri inclusi)
const RX = 8, RY = 28;           // offset della stanza sullo schermo
const TAU = Math.PI * 2;

const T = { FLOOR: 0, WALL: 1, ROCK: 2, CRACK: 3, SPIKE: 4, BARREL: 5, BRAZIER: 6, DOOR: 7, URN: 8 };

const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const dist = (ax, ay, bx, by) => Math.hypot(bx - ax, by - ay);
const dist2 = (ax, ay, bx, by) => (bx - ax) * (bx - ax) + (by - ay) * (by - ay);
const angTo = (ax, ay, bx, by) => Math.atan2(by - ay, bx - ax);
const rnd = (a = 1, b) => b === undefined ? Math.random() * a : a + Math.random() * (b - a);
const rndi = (a, b) => Math.floor(rnd(a, b + 1));
const pick = arr => arr[Math.floor(Math.random() * arr.length)];
const chance = p => Math.random() < p;
const sign = v => v < 0 ? -1 : v > 0 ? 1 : 0;
function angDiff(a, b) { let d = b - a; while (d > Math.PI) d -= TAU; while (d < -Math.PI) d += TAU; return d; }
function approach(v, t, d) { return v < t ? Math.min(v + d, t) : Math.max(v - d, t); }
function shuffle(arr) { for (let i = arr.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [arr[i], arr[j]] = [arr[j], arr[i]]; } return arr; }
function fmtTime(s) { s = Math.floor(s); const m = Math.floor(s / 60), r = s % 60; return m + ':' + (r < 10 ? '0' : '') + r; }

// Generatore pseudo-casuale con seme (mulberry32)
class RNG {
  constructor(seed) { this.s = (seed >>> 0) || 1; }
  next() {
    let t = this.s = (this.s + 0x6D2B79F5) >>> 0;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  range(a, b) { return a + this.next() * (b - a); }
  int(a, b) { return a + Math.floor(this.next() * (b - a + 1)); }
  pick(arr) { return arr[Math.floor(this.next() * arr.length)]; }
  chance(p) { return this.next() < p; }
  shuffle(arr) { for (let i = arr.length - 1; i > 0; i--) { const j = Math.floor(this.next() * (i + 1)); [arr[i], arr[j]] = [arr[j], arr[i]]; } return arr; }
  weighted(list, wf) {
    let tot = 0; for (const it of list) tot += wf(it);
    let r = this.next() * tot;
    for (const it of list) { r -= wf(it); if (r <= 0) return it; }
    return list[list.length - 1];
  }
}
function weightedPick(list, wf) {
  let tot = 0; for (const it of list) tot += wf(it);
  let r = Math.random() * tot;
  for (const it of list) { r -= wf(it); if (r <= 0) return it; }
  return list[list.length - 1];
}

// =====================================================================
//  Input: tastiera, mouse, gamepad
// =====================================================================
const Input = {
  down: Object.create(null), pressed: Object.create(null),
  mx: W / 2, my: H / 2, mL: false, mR: false, mLp: false, mRp: false,
  mouseMovedAt: 0, wheel: 0,
  pad: null, padPrev: [], padPressed: [], axes: [0, 0, 0, 0],
  lastDevice: 'kb',
  canvas: null,

  init(canvas) {
    this.canvas = canvas;
    const block = ['Tab', 'Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Backspace'];
    addEventListener('keydown', e => {
      if (!this.down[e.code]) this.pressed[e.code] = true;
      this.down[e.code] = true;
      this.lastDevice = 'kb';
      if (block.includes(e.code)) e.preventDefault();
      Sound.unlock();
    });
    addEventListener('keyup', e => { this.down[e.code] = false; });
    addEventListener('blur', () => { this.down = Object.create(null); this.mL = this.mR = false; });
    const pos = e => {
      const r = canvas.getBoundingClientRect();
      this.mx = (e.clientX - r.left) / r.width * W;
      this.my = (e.clientY - r.top) / r.height * H;
    };
    addEventListener('mousemove', e => { pos(e); this.mouseMovedAt = performance.now(); this.lastDevice = 'mouse'; });
    canvas.addEventListener('mousedown', e => {
      pos(e); Sound.unlock(); this.lastDevice = 'mouse';
      if (e.button === 0) { this.mL = true; this.mLp = true; }
      if (e.button === 2) { this.mR = true; this.mRp = true; }
      e.preventDefault();
    });
    addEventListener('mouseup', e => { if (e.button === 0) this.mL = false; if (e.button === 2) this.mR = false; });
    canvas.addEventListener('contextmenu', e => e.preventDefault());
    canvas.addEventListener('wheel', e => { this.wheel += Math.sign(e.deltaY); e.preventDefault(); }, { passive: false });
  },

  pollPad() {
    let pads = [];
    try { pads = navigator.getGamepads ? navigator.getGamepads() || [] : []; } catch (e) { pads = []; }
    let gp = null;
    for (const p of pads) if (p && p.connected) { gp = p; break; }
    if (!gp) { this.pad = null; this.axes = [0, 0, 0, 0]; return; }
    const btn = gp.buttons.map(b => b.pressed || b.value > 0.5);
    btn.forEach((b, i) => { if (b && !this.padPrev[i]) { this.padPressed[i] = true; this.lastDevice = 'pad'; } });
    this.padPrev = btn;
    this.pad = gp;
    this.axes = [0, 1, 2, 3].map(i => { const v = gp.axes[i] || 0; return Math.abs(v) < 0.22 ? 0 : v; });
    if (this.axes.some(a => a !== 0)) this.lastDevice = 'pad';
  },
  key(c) { return !!this.down[c]; },
  hit(c) { return !!this.pressed[c]; },
  btn(i) { return !!(this.pad && this.padPrev[i]); },
  btnHit(i) { return !!this.padPressed[i]; },
  endFrame() { this.pressed = Object.create(null); this.padPressed = []; this.mLp = false; this.mRp = false; this.wheel = 0; },
  clearAll() { this.pressed = Object.create(null); this.padPressed = []; this.mLp = this.mRp = false; }
};

// Azioni semantiche
const Act = {
  move() {
    let x = 0, y = 0;
    if (Input.key('KeyA')) x -= 1;
    if (Input.key('KeyD')) x += 1;
    if (Input.key('KeyW')) y -= 1;
    if (Input.key('KeyS')) y += 1;
    x += Input.axes[0]; y += Input.axes[1];
    const l = Math.hypot(x, y);
    if (l > 1) { x /= l; y /= l; }
    return { x, y };
  },
  arrowAim() {
    let x = 0, y = 0;
    if (Input.key('ArrowLeft')) x -= 1;
    if (Input.key('ArrowRight')) x += 1;
    if (Input.key('ArrowUp')) y -= 1;
    if (Input.key('ArrowDown')) y += 1;
    if (x || y) return Math.atan2(y, x);
    const ax = Input.axes[2], ay = Input.axes[3];
    if (Math.hypot(ax, ay) > 0.4) return Math.atan2(ay, ax);
    return null;
  },
  firing() {
    return Input.mL || Act.arrowAim() !== null || Input.btn(7);
  },
  dash() { return Input.hit('Space') || Input.hit('ShiftLeft') || Input.hit('ShiftRight') || Input.btnHit(0) || Input.btnHit(4); },
  flare() { return Input.mRp || Input.hit('KeyF') || Input.btnHit(1) || Input.btnHit(5); },
  interact() { return Input.hit('KeyE') || Input.btnHit(2); },
  pause() { return Input.hit('Escape') || Input.hit('KeyP') || Input.btnHit(9); },
  map() { return Input.hit('Tab') || Input.hit('KeyM') || Input.btnHit(8); },
  slot() {
    for (let i = 0; i < 4; i++) if (Input.hit('Digit' + (i + 1)) || Input.hit('Numpad' + (i + 1))) return i;
    const dp = [12, 15, 13, 14];
    for (let i = 0; i < 4; i++) if (Input.btnHit(dp[i])) return i;
    return -1;
  },
  up() { return Input.hit('ArrowUp') || Input.hit('KeyW') || Input.btnHit(12); },
  down() { return Input.hit('ArrowDown') || Input.hit('KeyS') || Input.btnHit(13); },
  left() { return Input.hit('ArrowLeft') || Input.hit('KeyA') || Input.btnHit(14); },
  right() { return Input.hit('ArrowRight') || Input.hit('KeyD') || Input.btnHit(15); },
  confirm() { return Input.hit('Enter') || Input.hit('Space') || Input.hit('KeyE') || Input.btnHit(0); },
  back() { return Input.hit('Escape') || Input.hit('Backspace') || Input.btnHit(1); },
};

// =====================================================================
//  Salvataggio
// =====================================================================
const Save = {
  KEY: 'ultimaLanterna.v1',
  data: null,
  defaults() {
    return {
      settings: { music: 0.5, sfx: 0.7, shake: true, numbers: true, fullscreenHint: true },
      stats: { runs: 0, wins: 0, bestDepth: 0, kills: 0, bossKills: 0, bestTime: 0, maxArdoreWon: -1 },
      unlocks: { lanterns: ['custode'], ardore: 0 },
      seen: {}
    };
  },
  load() {
    let d = null;
    try { d = JSON.parse(localStorage.getItem(this.KEY)); } catch (e) { d = null; }
    const def = this.defaults();
    if (!d || typeof d !== 'object') d = def;
    d.settings = Object.assign(def.settings, d.settings || {});
    d.stats = Object.assign(def.stats, d.stats || {});
    d.unlocks = Object.assign(def.unlocks, d.unlocks || {});
    if (!Array.isArray(d.unlocks.lanterns)) d.unlocks.lanterns = ['custode'];
    d.seen = d.seen || {};
    this.data = d;
  },
  write() { try { localStorage.setItem(this.KEY, JSON.stringify(this.data)); } catch (e) { /* storage non disponibile */ } },
  unlockLantern(id) {
    if (!this.data.unlocks.lanterns.includes(id)) { this.data.unlocks.lanterns.push(id); this.write(); return true; }
    return false;
  }
};
