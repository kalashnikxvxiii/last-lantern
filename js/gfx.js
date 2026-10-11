'use strict';
// =====================================================================
//  Grafica: canvas, sprite pixel-art compilati da stringhe, particelle,
//  pannelli UI disegnati a mano
// =====================================================================

const PAL = {
  k: '#0d0a12', K: '#1f1a26', g: '#3b3546', G: '#6b6478', s: '#a59fb0', w: '#e8e4dc', W: '#ffffff',
  r: '#7e2530', R: '#d04b3c', o: '#b5571f', O: '#f29c38', y: '#f6cf57', Y: '#fff2a8',
  b: '#2b3a67', B: '#4f7ab8', c: '#7fd0e0', C: '#c8f2f5', v: '#4b2a5c', V: '#8a4fb0', p: '#d48fd8',
  e: '#2e4a2a', E: '#4f8a3a', l: '#9fd05a', n: '#4a3020', N: '#8a5a34', t: '#c49a6a', m: '#2a1d18',
  a: '#1f2a36', A: '#33475a', h: '#557086', q: '#5c1f3a', Q: '#a33a5c', i: '#26404a', I: '#3f6d6e',
  u: '#6a5a3a', U: '#9a8250', x: '#c0c8d0', z: '#7a8290'
};
const OUTLINE = '#0b0810';

function makeCanvas(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }

const Gfx = {
  canvas: null, ctx: null, scale: 1,
  init() {
    this.canvas = document.getElementById('game');
    this.canvas.width = W; this.canvas.height = H;
    this.ctx = this.canvas.getContext('2d');
    this.ctx.imageSmoothingEnabled = false;
    this.resize();
    addEventListener('resize', () => this.resize());
  },
  resize() {
    const s = Math.min(innerWidth / W, innerHeight / H);
    this.scale = s >= 1 ? Math.floor(s) : s;
    this.canvas.style.width = Math.floor(W * this.scale) + 'px';
    this.canvas.style.height = Math.floor(H * this.scale) + 'px';
  }
};

// ---------------------------------------------------------------------
//  Sprite
// ---------------------------------------------------------------------
const SPR = {};

function compileRows(rows, pal, sym, outline) {
  if (sym) rows = rows.map(r => r + [...r].reverse().join(''));
  const h = rows.length;
  let w = 0; for (const r of rows) w = Math.max(w, r.length);
  const pad = outline ? 1 : 0;
  const cv = makeCanvas(w + pad * 2, h + pad * 2);
  const c = cv.getContext('2d');
  const solid = [];
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < rows[y].length; x++) {
      const ch = rows[y][x];
      if (ch === '.' || ch === ' ') continue;
      const col = pal[ch] || PAL[ch];
      if (!col) continue;
      solid.push([x, y]);
      c.fillStyle = col;
      c.fillRect(x + pad, y + pad, 1, 1);
    }
  }
  if (outline) {
    const set = new Set(solid.map(([x, y]) => x + ',' + y));
    c.fillStyle = typeof outline === 'string' ? outline : OUTLINE;
    for (const [x, y] of solid) {
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = x + dx, ny = y + dy;
        if (!set.has(nx + ',' + ny)) { c.fillRect(nx + pad, ny + pad, 1, 1); }
      }
    }
    // ridisegna i pixel pieni (l'outline non deve coprirli)
    for (const [x, y] of solid) { c.fillStyle = pal[rows[y][x]] || PAL[rows[y][x]]; c.fillRect(x + pad, y + pad, 1, 1); }
  }
  return cv;
}
function silhouette(src, color) {
  const cv = makeCanvas(src.width, src.height);
  const c = cv.getContext('2d');
  c.drawImage(src, 0, 0);
  c.globalCompositeOperation = 'source-in';
  c.fillStyle = color; c.fillRect(0, 0, cv.width, cv.height);
  return cv;
}
// def: {frames:[[rows]], pal?, sym?, outline? (default true)}
function defSprite(name, def) {
  const pal = def.pal || {};
  const outline = def.outline === undefined ? true : def.outline;
  const frames = def.frames.map(rows => compileRows(rows, pal, def.sym, outline));
  SPR[name] = {
    frames, w: frames[0].width, h: frames[0].height,
    flash: frames.map(f => silhouette(f, '#ffffff')),
    tint: {}
  };
}
function sprTint(name, color) {
  const s = SPR[name];
  if (!s.tint[color]) s.tint[color] = s.frames.map(f => silhouette(f, color));
  return s.tint[color];
}
// disegna centrato su (x,y)
function drawSpr(ctx, name, frame, x, y, o) {
  const s = SPR[name];
  if (!s) return;
  const f = (frame | 0) % s.frames.length;
  let img = s.frames[f];
  if (o && o.flash) img = s.flash[f];
  const sc = (o && o.scale) || 1;
  const w = s.w * sc, h = s.h * sc;
  const dx = Math.round(x - w / 2), dy = Math.round(y - h / 2);
  const alpha = o && o.alpha !== undefined ? o.alpha : 1;
  if (alpha <= 0) return;
  if (alpha !== 1) { ctx.save(); ctx.globalAlpha *= alpha; }
  if (o && o.flip) {
    ctx.save();
    ctx.translate(dx + w, dy); ctx.scale(-1, 1);
    ctx.drawImage(img, 0, 0, w, h);
    if (o.tint) { ctx.globalAlpha *= o.tintA || 0.5; ctx.drawImage(sprTint(name, o.tint)[f], 0, 0, w, h); }
    ctx.restore();
  } else {
    ctx.drawImage(img, dx, dy, w, h);
    if (o && o.tint) { ctx.save(); ctx.globalAlpha *= o.tintA || 0.5; ctx.drawImage(sprTint(name, o.tint)[f], dx, dy, w, h); ctx.restore(); }
  }
  if (alpha !== 1) ctx.restore();
}

// ---------------------------------------------------------------------
//  Primitive pixel
// ---------------------------------------------------------------------
function pxRect(ctx, x, y, w, h, c) { ctx.fillStyle = c; ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
function pxCircle(ctx, cx, cy, r, c) {
  ctx.fillStyle = c;
  cx = Math.round(cx); cy = Math.round(cy); r = Math.max(0.5, r);
  const ri = Math.ceil(r);
  for (let y = -ri; y <= ri; y++) {
    const hw = Math.floor(Math.sqrt(Math.max(0, r * r - y * y)));
    if (hw <= 0 && Math.abs(y) >= r) continue;
    ctx.fillRect(cx - hw, cy + y, hw * 2 + 1, 1);
  }
}
function pxRing(ctx, cx, cy, r, c, thick = 1) {
  ctx.strokeStyle = c; ctx.lineWidth = thick;
  ctx.beginPath(); ctx.arc(Math.round(cx) + 0.5, Math.round(cy) + 0.5, Math.max(0.5, r), 0, TAU); ctx.stroke();
}
function shadow(ctx, x, y, w) {
  ctx.fillStyle = 'rgba(5,3,8,0.45)';
  ctx.beginPath(); ctx.ellipse(Math.round(x), Math.round(y), w, Math.max(1.5, w * 0.38), 0, 0, TAU); ctx.fill();
}
function glow(ctx, x, y, r, color, a = 0.35) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, color); g.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = a;
  ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
  ctx.restore();
}

// ---------------------------------------------------------------------
//  Pannelli UI "fatti a mano": legno scuro con rifiniture in ottone
// ---------------------------------------------------------------------
const UI_COL = {
  bg: '#16111c', bg2: '#1f1826', edge: '#0a070d', brass: '#9a7a44', brassL: '#d8b46a', brassD: '#5a4428',
  ink: '#ece6d8', dim: '#8a8294', sel: '#f6cf57'
};
function panel(ctx, x, y, w, h, o = {}) {
  x = Math.round(x); y = Math.round(y); w = Math.round(w); h = Math.round(h);
  const a = (o.alpha === undefined ? 0.94 : o.alpha) * ctx.globalAlpha;
  ctx.save(); ctx.globalAlpha = a;
  pxRect(ctx, x + 2, y + 2, w, h, 'rgba(0,0,0,0.45)');
  pxRect(ctx, x, y, w, h, UI_COL.edge);
  pxRect(ctx, x + 1, y + 1, w - 2, h - 2, o.border || UI_COL.brassD);
  pxRect(ctx, x + 2, y + 2, w - 4, h - 4, o.bg || UI_COL.bg);
  // venature del "legno"
  ctx.globalAlpha = a * 0.25;
  for (let yy = y + 5; yy < y + h - 4; yy += 6) pxRect(ctx, x + 3, yy, w - 6, 1, UI_COL.bg2);
  ctx.globalAlpha = a;
  // filo d'ottone
  pxRect(ctx, x + 2, y + 2, w - 4, 1, o.hi || UI_COL.brass);
  pxRect(ctx, x + 2, y + h - 3, w - 4, 1, UI_COL.brassD);
  // borchie agli angoli
  const st = o.hi || UI_COL.brassL;
  for (const [sx, sy] of [[x + 3, y + 3], [x + w - 5, y + 3], [x + 3, y + h - 5], [x + w - 5, y + h - 5]]) {
    pxRect(ctx, sx, sy, 2, 2, st);
    pxRect(ctx, sx + 1, sy + 1, 1, 1, UI_COL.brassD);
  }
  ctx.restore();
}
// tasto disegnato come un piccolo tasto meccanico
function keycap(ctx, x, y, label, o = {}) {
  const w = Math.max(9, Font.width(label) + 5);
  x = Math.round(x); y = Math.round(y);
  pxRect(ctx, x, y + 1, w, 10, '#0a070d');
  pxRect(ctx, x, y, w, 9, o.pressed ? '#5a4428' : '#3a3044');
  pxRect(ctx, x + 1, y + 1, w - 2, 6, o.pressed ? '#9a7a44' : '#5c5068');
  Font.draw(ctx, label, x + Math.floor(w / 2), y + 1, { align: 'center', color: '#f2ead8', shadow: false });
  return w;
}
function bar(ctx, x, y, w, h, frac, col, bg = '#120d16', hi) {
  frac = clamp(frac, 0, 1);
  pxRect(ctx, x - 1, y - 1, w + 2, h + 2, '#0a070d');
  pxRect(ctx, x, y, w, h, bg);
  if (frac > 0) {
    pxRect(ctx, x, y, Math.max(1, Math.round(w * frac)), h, col);
    pxRect(ctx, x, y, Math.max(1, Math.round(w * frac)), 1, hi || 'rgba(255,255,255,0.25)');
  }
}

// ---------------------------------------------------------------------
//  Particelle e testi fluttuanti
// ---------------------------------------------------------------------
const Particles = {
  list: [],
  add(p) {
    if (this.list.length > 900) this.list.shift();
    p.t = 0; p.life = p.life || 0.5; p.size = p.size || 1;
    p.vx = p.vx || 0; p.vy = p.vy || 0; p.drag = p.drag === undefined ? 2 : p.drag;
    this.list.push(p);
    return p;
  },
  burst(x, y, n, color, spd = 60, life = 0.5, o = {}) {
    for (let i = 0; i < n; i++) {
      const a = o.angle !== undefined ? o.angle + rnd(-(o.spread || 0.6), o.spread || 0.6) : rnd(TAU);
      const s = rnd(spd * 0.3, spd);
      this.add({
        x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: rnd(life * 0.6, life),
        color: Array.isArray(color) ? pick(color) : color, size: o.size || (chance(0.3) ? 2 : 1),
        grav: o.grav || 0, drag: o.drag, glow: o.glow, shrink: o.shrink !== false, above: o.above
      });
    }
  },
  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const p = this.list[i];
      p.t += dt;
      if (p.t >= p.life) { this.list.splice(i, 1); continue; }
      p.vx -= p.vx * p.drag * dt; p.vy -= p.vy * p.drag * dt;
      p.vy += (p.grav || 0) * dt;
      p.x += p.vx * dt; p.y += p.vy * dt;
    }
  },
  draw(ctx, above) {
    for (const p of this.list) {
      if (!!p.above !== !!above) continue;
      const k = 1 - p.t / p.life;
      const s = p.shrink ? Math.max(1, Math.round(p.size * (0.4 + k * 0.6))) : p.size;
      ctx.globalAlpha = p.fade === false ? 1 : Math.min(1, k * 1.6);
      pxRect(ctx, p.x - s / 2, p.y - s / 2, s, s, p.color);
    }
    ctx.globalAlpha = 1;
  },
  clear() { this.list.length = 0; }
};

const Floaters = {
  list: [],
  add(x, y, text, color = TEXT_COLORS.w, o = {}) {
    if (this.list.length > 80) this.list.shift();
    this.list.push({ x: x + rnd(-3, 3), y, text: String(text), color, t: 0, life: o.life || 0.8, vy: o.vy || -28, scale: o.scale || 1 });
  },
  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const f = this.list[i];
      f.t += dt; f.y += f.vy * dt; f.vy *= 1 - 2.5 * dt;
      if (f.t > f.life) this.list.splice(i, 1);
    }
  },
  draw(ctx) {
    for (const f of this.list) {
      const a = f.t > f.life * 0.6 ? 1 - (f.t - f.life * 0.6) / (f.life * 0.4) : 1;
      Font.draw(ctx, f.text, f.x, f.y, { align: 'center', color: f.color, alpha: a, scale: f.scale });
    }
  },
  clear() { this.list.length = 0; }
};
