'use strict';
// =====================================================================
// Interface: HUD, minimap, notifications, menus
// =====================================================================

// ---------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------
function toast(text, col = '#ece6d8', sub = '') {
  if (!run) return;
  run.toasts.push({ text, col, sub, t: 0, life: sub ? 3.2 : 2.4 });
  if (run.toasts.length > 4) run.toasts.shift();
}
function banner(title, desc, col, icon) {
  if (!run) return;
  run.banners.push({ title, desc, col, icon, t: 0, life: 3.6 });
  if (run.banners.length > 2) run.banners.shift();
}
function updateNotices(dt) {
  for (const t of run.toasts) t.t += dt;
  run.toasts = run.toasts.filter(t => t.t < t.life);
  if (run.banners.length) { run.banners[0].t += dt; if (run.banners[0].t > run.banners[0].life) run.banners.shift(); }
}
function drawNotices(ctx) {
  let y = 36;
  for (const t of run.toasts) {
    const a = t.t < 0.2 ? t.t / 0.2 : t.t > t.life - 0.5 ? (t.life - t.t) / 0.5 : 1;
    const w = Math.max(Font.width(t.text), t.sub ? Font.width(t.sub) : 0) + 16;
    ctx.save(); ctx.globalAlpha = a;
    const h = t.sub ? 26 : 15;
    panel(ctx, W / 2 - w / 2, y, w, h, { alpha: 0.88 });
    Font.draw(ctx, t.text, W / 2, y + 4, { align: 'center', color: t.col });
    if (t.sub) Font.draw(ctx, t.sub, W / 2, y + 15, { align: 'center', color: '#a8a0b0' });
    ctx.restore();
    y += h + 3;
  }
  const b = run.banners[0];
  if (b) {
    const a = b.t < 0.25 ? b.t / 0.25 : b.t > b.life - 0.5 ? (b.life - b.t) / 0.5 : 1;
    const w = 240;
    const lines = Font.wrap(b.desc, w - 40);
    const h = 26 + lines.length * 10;
    const x = W / 2 - w / 2, y0 = H - 40 - h;
    ctx.save(); ctx.globalAlpha = a;
    panel(ctx, x, y0, w, h, { hi: b.col });
    if (b.icon) { pxRect(ctx, x + 8, y0 + 8, 18, 18, '#0b0810'); drawSpr(ctx, b.icon, 0, x + 17, y0 + 17); }
    Font.draw(ctx, b.title, x + 32, y0 + 7, { color: b.col });
    lines.forEach((l, i) => Font.draw(ctx, l, x + 32, y0 + 19 + i * 10, { color: '#d8d0c0' }));
    ctx.restore();
  }
}

// ---------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------
function drawHUD(ctx) {
  const p = run.player, s = p.stats;
  // top bar
  pxRect(ctx, 0, 0, W, 27, '#0e0a12');
  pxRect(ctx, 0, 26, W, 1, UI_COL.brassD);
  pxRect(ctx, 0, 27, W, 1, '#050308');
  ctx.save(); ctx.globalAlpha = 0.3;
  for (let x = 0; x < W; x += 7) pxRect(ctx, x, 2 + (x * 7 % 5), 3, 1, '#1a141f');
  ctx.restore();

  // health
  drawSpr(ctx, 'heart', 0, 8, 7);
  const hpLow = p.hp / s.maxHp < 0.3;
  bar(ctx, 16, 3, 92, 8, p.hp / s.maxHp, hpLow && Math.sin(Render.time * 8) > 0 ? '#ff6a5a' : '#c0392b', '#2a0d12', '#e87060');
  Font.draw(ctx, Math.ceil(p.hp) + '/' + s.maxHp, 62, 3, { align: 'center', color: '#f2ead8' });
  // oil
  drawSpr(ctx, 'oil', 0, 8, 17);
  const oilF = p.oil / s.maxOil;
  bar(ctx, 16, 15, 92, 4, oilF, p.oil <= 0 ? '#3b3546' : '#d88a28', '#1e140a', '#f6cf57');
  const cx = 16 + Math.round(92 * Math.min(1, s.flareCost / s.maxOil));
  const ready = p.oil >= s.flareCost;
  pxRect(ctx, cx, 13, 1, 8, ready ? '#fff2a8' : '#5a4428');
  if (p.oil <= 0) Font.draw(ctx, 'DARK', 62, 13, { align: 'center', color: Math.sin(Render.time * 6) > 0 ? '#e0574a' : '#8a8294' });
  // experience
  bar(ctx, 16, 23, 92, 1, p.xp / xpNeed(p.level), '#c57ae0', '#1a0d22');

  // consumables
  for (let i = 0; i < 4; i++) {
    const x = 116 + i * 22, y = 3;
    pxRect(ctx, x, y, 20, 20, '#0b0810');
    pxRect(ctx, x + 1, y + 1, 18, 18, '#1f1826');
    pxRect(ctx, x + 1, y + 1, 18, 1, '#2e2436');
    const sl = p.cons[i];
    if (sl) {
      drawSpr(ctx, CONS[sl.id].spr, 0, x + 10, y + 10);
      if (sl.n > 1) Font.draw(ctx, String(sl.n), x + 18, y + 12, { align: 'right', color: '#f2ead8' });
    }
    Font.draw(ctx, String(i + 1), x + 2, y + 1, { color: '#6b6478', shadow: false });
  }
  // coins and keys
  drawSpr(ctx, 'coin', 0, 212, 8);
  Font.draw(ctx, String(p.coins), 220, 4, { color: TEXT_COLORS.y });
  drawSpr(ctx, 'key', 0, 213, 19);
  Font.draw(ctx, String(p.keys), 220, 15, { color: '#e8dcc0' });

  // depth and level
  const bio = biomeOf(run.depth);
  Font.draw(ctx, 'Depth ' + run.depth + (run.depth > 5 ? '' : ' of 5'), 254, 3, { color: '#e8dcc0' });
  Font.draw(ctx, bio.name, 254, 14, { color: '#8a8294' });
  Font.draw(ctx, 'Lv ' + p.level, 388, 3, { align: 'right', color: '#c57ae0' });

  drawMinimap(ctx, 394, 2, false);

  // statuses and curses (below the bar)
  let sx = 6;
  for (const k in p.statuses) {
    const st = STATUS[k];
    if (!st) continue;
    const v = p.statuses[k];
    pxRect(ctx, sx, 31, 11, 13, '#0b0810');
    drawSpr(ctx, st.icon, 0, sx + 5.5, 36);
    const f = clamp(v.t / 6, 0, 1);
    pxRect(ctx, sx + 1, 42, Math.round(9 * f), 1, st.col);
    if (v.stacks > 1) Font.draw(ctx, String(v.stacks), sx + 12, 37, { color: st.col });
    sx += v.stacks > 1 ? 19 : 13;
  }
  if (p.guardUp) { pxRect(ctx, sx, 31, 11, 13, '#0b0810'); drawSpr(ctx, 's_shield', 0, sx + 5.5, 37); sx += 13; }
  for (const c of p.curses) {
    pxRect(ctx, sx, 31, 11, 13, '#1a0d22');
    drawSpr(ctx, 's_curse', 0, sx + 5.5, 37);
    sx += 13;
  }

  // dash charges under the feet
  if (p.dashCharges < s.dashCharges && !p.dead) {
    for (let i = 0; i < s.dashCharges; i++) {
      const x = p.x - (s.dashCharges * 4) / 2 + i * 4;
      pxRect(ctx, x, p.y + 11, 3, 2, i < p.dashCharges ? '#c8f2f5' : '#3b3546');
    }
  }

  // boss bar
  const boss = run.enemies.find(e => e.boss);
  if (boss) {
    const w = 300, x = W / 2 - w / 2, y = H - 14;
    Font.draw(ctx, boss.name, W / 2, y - 10, { align: 'center', color: '#e8dcc0' });
    pxRect(ctx, x - 2, y - 2, w + 4, 9, '#0b0810');
    pxRect(ctx, x - 1, y - 1, w + 2, 7, UI_COL.brassD);
    bar(ctx, x, y, w, 5, boss.hp / boss.maxHp, boss.invuln > 0 ? '#a59fb0' : '#a02a3a', '#200810', '#e0574a');
    // phase ticks
    for (const ph of boss.B.phases) if (ph.at < 1) pxRect(ctx, x + Math.round(w * ph.at), y - 1, 1, 7, '#e8dcc0');
  }
}

const ROOM_MARK = { boss: '#e0574a', treasure: '#f6cf57', shop: '#c49a6a', shrine: '#c57ae0', elite: '#ff3a5a', secret: '#8a8294', start: '#6b6478' };
function roomKnown(r) {
  if (r.type === 'secret') return r.found || r.mapped || run.player.stats.mapReveal;
  return r.seen || run.player.stats.mapReveal;
}
// Fog hides the rooms on every map, the minimap and the full one alike
function roomsVisible() { return !run.player.stats.hideMap; }
function drawMinimap(ctx, x0, y0, full) {
  if (!roomsVisible()) {
    pxRect(ctx, x0, y0, 80, 23, '#0b0810');
    Font.draw(ctx, 'Fog', x0 + 40, y0 + 8, { align: 'center', color: '#55505e' });
    return;
  }
  const cur = run.room;
  const cw = full ? 22 : 14, ch = full ? 13 : 6, gap = 2;
  let gx0, gy0, nx, ny;
  if (full) { gx0 = 0; gy0 = 0; nx = 9; ny = 8; }
  else { gx0 = cur.gx - 2; gy0 = cur.gy - 1; nx = 5; ny = 3; pxRect(ctx, x0 - 1, y0 - 1, 82, 25, '#0b0810'); }
  for (const r of run.floor.rooms) {
    const gx = r.gx - gx0, gy = r.gy - gy0;
    if (gx < 0 || gy < 0 || gx >= nx || gy >= ny) continue;
    if (!roomKnown(r)) continue;
    const x = x0 + gx * (cw + gap), y = y0 + gy * (ch + gap);
    const isCur = r === cur;
    let fill = r.visited ? '#4a4256' : '#1f1a26';
    if (isCur) fill = '#d8b46a';
    pxRect(ctx, x, y, cw, ch, '#6b6478');
    pxRect(ctx, x + 1, y + 1, cw - 2, ch - 2, fill);
    // corridors
    for (const d in r.doors) {
      const n = r.doors[d];
      if (!doorVisible(r, d) || !roomKnown(n)) continue;
      if (d === 'e') pxRect(ctx, x + cw, y + ch / 2 - 1, gap, 2, '#6b6478');
      if (d === 's') pxRect(ctx, x + cw / 2 - 1, y + ch, 2, gap, '#6b6478');
    }
    const mk = ROOM_MARK[r.type];
    if (mk && r.type !== 'start') {
      const s = full ? 5 : 2;
      pxRect(ctx, x + cw / 2 - s / 2, y + ch / 2 - s / 2, s, s, isCur ? '#0b0810' : mk);
      if (full && r.type === 'treasure' && r.locked) pxRect(ctx, x + cw - 4, y + 1, 3, 3, '#f6cf57');
    }
  }
}

function drawFullMap(ctx) {
  ctx.save(); ctx.globalAlpha = 0.85; pxRect(ctx, 0, 0, W, H, '#050308'); ctx.restore();
  const w = 9 * 24 + 30, h = 8 * 15 + 70;
  const x = W / 2 - w / 2, y = H / 2 - h / 2;
  panel(ctx, x, y, w, h);
  Font.draw(ctx, 'Map - ' + biomeOf(run.depth).name, W / 2, y + 8, { align: 'center', color: '#e8dcc0' });
  if (!roomsVisible()) { Font.draw(ctx, 'Fog', W / 2, y + h / 2 - 4, { align: 'center', color: '#55505e' }); return; }
  drawMinimap(ctx, x + 15, y + 24, true);
  const leg = [['boss', 'Warden'], ['treasure', 'Treasure'], ['shop', 'Merchant'], ['shrine', 'Shrine'], ['elite', 'Challenge'], ['secret', 'Secret']];
  leg.forEach(([k, n], i) => {
    const lx = x + 14 + (i % 3) * 82, ly = y + h - 28 + Math.floor(i / 3) * 11;
    pxRect(ctx, lx, ly + 2, 4, 4, ROOM_MARK[k]);
    Font.draw(ctx, n, lx + 7, ly, { color: '#a8a0b0' });
  });
}

// ---------------------------------------------------------------------
// Generic menu (keyboard, mouse, gamepad)
// ---------------------------------------------------------------------
class Menu {
  constructor(items, o = {}) { this.items = items; this.sel = 0; this.rects = []; this.o = o; this.lastMx = -1; this.lastMy = -1; }
  current() { return this.items[this.sel]; }
  update() {
    const n = this.items.length;
    const step = d => {
      for (let k = 0; k < n; k++) {
        this.sel = (this.sel + d + n) % n;
        if (!this.items[this.sel].disabled || this.o.allowDisabled) break;
      }
      Sound.play('select');
    };
    if (Act.up()) step(-1);
    if (Act.down()) step(1);
    const it = this.items[this.sel];
    if (it && it.adjust) {
      if (Act.left()) { it.adjust(-1); Sound.play('select'); }
      if (Act.right()) { it.adjust(1); Sound.play('select'); }
    }
    // mouse
    const moved = Input.mx !== this.lastMx || Input.my !== this.lastMy;
    this.lastMx = Input.mx; this.lastMy = Input.my;
    for (let i = 0; i < this.rects.length; i++) {
      const r = this.rects[i];
      if (!r) continue;
      if (Input.mx >= r.x && Input.mx < r.x + r.w && Input.my >= r.y && Input.my < r.y + r.h) {
        if (moved && this.sel !== i && (!this.items[i].disabled || this.o.allowDisabled)) { this.sel = i; Sound.play('select'); }
        if (Input.mLp) {
          if (this.items[i].adjust) { this.items[i].adjust(Input.mx > r.x + r.w / 2 ? 1 : -1); Sound.play('select'); }
          else if (!this.items[i].disabled && this.items[i].action) { Sound.play('confirm'); this.items[i].action(); }
          return;
        }
      }
    }
    if (Act.confirm() && it && !it.disabled && it.action) { Sound.play('confirm'); it.action(); }
  }
  draw(ctx, x, y, o = {}) {
    const lh = o.lineH || 14;
    const align = o.align || 'center';
    this.rects = [];
    this.items.forEach((it, i) => {
      const sel = i === this.sel;
      let label = typeof it.label === 'function' ? it.label() : it.label;
      if (it.value) label += '   ' + it.value();
      const col = it.disabled ? '#55505e' : sel ? UI_COL.sel : '#c8c0d0';
      const w = Font.width(label);
      const lx = align === 'center' ? x - w / 2 : x;
      const yy = y + i * lh;
      this.rects.push({ x: lx - 14, y: yy - 3, w: w + 28, h: lh });
      if (sel) {
        // small flame next to the selected entry
        const fx = lx - 9, fy = yy + 4;
        pxRect(ctx, fx, fy - 2, 3, 4, '#f29c38'); pxRect(ctx, fx + 1, fy - 3 - (Math.floor(Render.time * 8) % 2), 1, 2, '#f6cf57');
        pxRect(ctx, fx + 1, fy, 1, 1, '#fff2a8');
        if (align === 'center') { pxRect(ctx, lx + w + 6, fy - 2, 3, 4, '#f29c38'); pxRect(ctx, lx + w + 7, fy - 3 - (Math.floor(Render.time * 8 + 1) % 2), 1, 2, '#f6cf57'); }
      }
      Font.draw(ctx, label, lx, yy, { color: col });
    });
  }
}

// ---------------------------------------------------------------------
// Perk choice screen
// ---------------------------------------------------------------------
function drawPerkCards(ctx, choices, sel, title, sub) {
  ctx.save(); ctx.globalAlpha = 0.78; pxRect(ctx, 0, 0, W, H, '#050308'); ctx.restore();
  Font.draw(ctx, title, W / 2, 34, { align: 'center', color: '#f6cf57', scale: 2 });
  Font.draw(ctx, sub, W / 2, 56, { align: 'center', color: '#a8a0b0' });
  const n = choices.length;
  const cw = n >= 4 ? 108 : 132, gap = 8;
  const total = n * cw + (n - 1) * gap;
  const x0 = W / 2 - total / 2, y0 = 74, chh = 150;
  const rects = [];
  const p = run.player;
  choices.forEach((id, i) => {
    const P = PERKS[id];
    const R = RARITY[P.rar];
    const x = x0 + i * (cw + gap);
    const isSel = i === sel;
    const y = y0 - (isSel ? 4 : 0);
    rects.push({ x, y, w: cw, h: chh });
    panel(ctx, x, y, cw, chh, { hi: isSel ? R.col : UI_COL.brass, border: isSel ? R.col : UI_COL.brassD, alpha: 0.97 });
    // icon
    pxRect(ctx, x + cw / 2 - 14, y + 10, 28, 28, '#0b0810');
    pxRect(ctx, x + cw / 2 - 13, y + 11, 26, 26, '#1a141f');
    if (isSel) glow(ctx, x + cw / 2, y + 24, 22, R.col, 0.3);
    drawSpr(ctx, P.icon, 0, x + cw / 2, y + 24, { scale: 2 });
    const nameLines = Font.wrap(P.name, cw - 10);
    nameLines.forEach((l, k) => Font.draw(ctx, l, x + cw / 2, y + 44 + k * 10, { align: 'center', color: R.col }));
    const ny = y + 44 + nameLines.length * 10;
    Font.draw(ctx, R.name, x + cw / 2, ny, { align: 'center', color: '#6b6478' });
    const lines = Font.wrap(P.desc, cw - 12);
    lines.forEach((l, k) => Font.draw(ctx, l, x + 6, ny + 14 + k * 10, { color: '#d8d0c0' }));
    const have = p.perks[id] || 0;
    if (P.max > 1) {
      for (let k = 0; k < P.max; k++) pxRect(ctx, x + cw / 2 - P.max * 3 + k * 6, y + chh - 12, 4, 4, k < have ? '#8a8294' : k === have ? R.col : '#2a2430');
    }
    Font.draw(ctx, String(i + 1), x + 7, y + 6, { color: '#55505e' });
  });
  return rects;
}

// ---------------------------------------------------------------------
// Equipment list (pause)
// ---------------------------------------------------------------------
function buildEntries() {
  const p = run.player;
  const out = [];
  for (const id in p.perks) out.push({ kind: 'perk', icon: PERKS[id].icon, name: PERKS[id].name + (PERKS[id].max > 1 ? '  x' + p.perks[id] : ''), desc: PERKS[id].desc, col: RARITY[PERKS[id].rar].col });
  for (const id of p.relics) out.push({ kind: 'relic', icon: RELICS[id].icon, name: RELICS[id].name, desc: RELICS[id].desc, col: '#f6cf57' });
  for (const id of p.curses) out.push({ kind: 'curse', icon: 's_curse', name: CURSES[id].name, desc: CURSES[id].desc, col: '#c57ae0' });
  return out;
}
function drawBuildPanel(ctx, x, y, w, h, hoverIdx) {
  panel(ctx, x, y, w, h);
  const entries = buildEntries();
  Font.draw(ctx, 'Equipment', x + w / 2, y + 7, { align: 'center', color: '#e8dcc0' });
  if (!entries.length) { Font.draw(ctx, 'Nothing yet. Descend and fight.', x + w / 2, y + 30, { align: 'center', color: '#6b6478' }); return []; }
  const cols = Math.floor((w - 12) / 20);
  const rects = [];
  entries.forEach((e, i) => {
    const cx = x + 8 + (i % cols) * 20, cy = y + 20 + Math.floor(i / cols) * 20;
    pxRect(ctx, cx, cy, 18, 18, i === hoverIdx ? e.col : '#0b0810');
    pxRect(ctx, cx + 1, cy + 1, 16, 16, e.kind === 'curse' ? '#1a0d22' : '#1a141f');
    drawSpr(ctx, e.icon, 0, cx + 9, cy + 9);
    rects.push({ x: cx, y: cy, w: 18, h: 18 });
  });
  const sel = entries[hoverIdx];
  const dy = y + h - 46;
  pxRect(ctx, x + 6, dy - 4, w - 12, 1, UI_COL.brassD);
  if (sel) {
    Font.draw(ctx, sel.name, x + 8, dy, { color: sel.col });
    Font.wrap(sel.desc, w - 16).slice(0, 3).forEach((l, k) => Font.draw(ctx, l, x + 8, dy + 11 + k * 10, { color: '#d8d0c0' }));
  } else Font.drawWrapped(ctx, '^dHover over an icon or open Equipment to read the details.', x + 8, dy, w - 16, {});
  return rects;
}

function drawStatsPanel(ctx, x, y, w, h) {
  const p = run.player, s = p.stats;
  panel(ctx, x, y, w, h);
  Font.draw(ctx, 'Stats', x + w / 2, y + 7, { align: 'center', color: '#e8dcc0' });
  const rows = [
    ['Damage', pDamage(p).toFixed(1)], ['Fire rate', pFireRate(p).toFixed(2) + '/s'], ['Projectiles', s.proj],
    ['Crit', Math.round(s.crit * 100) + '%  x' + s.critMult.toFixed(1)], ['Speed', Math.round(pSpeed(p))], ['Armor', s.armor],
    ['Dodge', Math.round(s.dodge * 100) + '%'], ['Dashes', s.dashCharges], ['Oil', Math.round(p.oil) + '/' + s.maxOil],
    ['Flare cost', Math.round(s.flareCost)], ['Light', Math.round(pLight(p))],
  ];
  rows.forEach(([k, v], i) => {
    Font.draw(ctx, k, x + 8, y + 20 + i * 10, { color: '#8a8294' });
    Font.draw(ctx, String(v), x + w - 8, y + 20 + i * 10, { align: 'right', color: '#e8dcc0' });
  });
}

// big lantern drawing (title and selection)
function drawBigLantern(ctx, x, y, glass, swing, s = 3) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(swing);
  const R = (a, b, c, d, col) => pxRect(ctx, a * s, b * s, c * s, d * s, col);
  // chain
  for (let i = 0; i < 5; i++) R(-0.5, -16 + i * 2, 1, 1, '#6b6478');
  R(-3, -6, 6, 1, '#3b3546'); R(-4, -5, 8, 1, '#6b6478');
  R(-5, -4, 10, 1, '#0b0810');
  R(-4, -3, 8, 9, '#0b0810');
  R(-3, -3, 6, 8, glass);
  R(-1, -2, 2, 5, '#ffffff');
  R(-4, -3, 1, 9, '#3b3546'); R(3, -3, 1, 9, '#3b3546');
  R(-5, 6, 10, 1, '#6b6478'); R(-4, 7, 8, 1, '#3b3546');
  ctx.restore();
  glow(ctx, x, y + 2 * s, 30 * s, glass, 0.18);
}
