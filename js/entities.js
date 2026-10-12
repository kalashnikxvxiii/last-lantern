'use strict';
// =====================================================================
// Entities: player, enemies, bosses, projectiles, effects, pickups
// =====================================================================

let run = null;
const FX = { shake: 0, hitstop: 0, flash: 0, flashCol: '#ffffff', slow: 0 };

function shake(v) { if (Save.data.settings.shake) FX.shake = Math.max(FX.shake, v); }
function hitstop(t) { FX.hitstop = Math.max(FX.hitstop, t); }
function screenFlash(col, a) { FX.flashCol = col; FX.flash = Math.max(FX.flash, a); }

// per-depth scaling
const depthHp = d => 1 + 0.6 * (d - 1) + 0.08 * (d - 1) * (d - 1);
const depthDmg = d => 1 + 0.2 * (d - 1);
const ardHp = () => run.ardor >= 1 ? 1.25 : 1;
const ardDmg = () => run.ardor >= 2 ? 1.2 : 1;
const xpNeed = L => Math.round(12 + 7 * L + 1.5 * L * L);

// ---------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------
function newPlayer(lanternId) {
  return {
    x: 0, y: 0, vx: 0, vy: 0, r: 4, hp: 1, oil: 1, xp: 0, level: 1, coins: 0, keys: 1,
    aim: 0, fireCd: 0, dashT: 0, dashCd: 0, dashCharges: 1, dashDx: 0, dashDy: 0, inv: 0,
    statuses: {}, perks: {}, relics: [], curses: [], cons: [null, null, null, null],
    shotCount: 0, flareCd: 0, guardT: 0, guardUp: false, secondwindUsed: false, coffinUsed: false,
    tempOrbit: 0, tempOrbitT: 0, orbitA: 0, sunT: 0, stormT: 3, trailT: 0, anim: 0, moving: false,
    lantern: lanternId, stats: baseStats(), dead: false, lastHit: '', facing: 1
  };
}

function recalcStats() {
  const p = run.player, s = baseStats();
  const L = LANTERNS.find(l => l.id === p.lantern) || LANTERNS[0];
  L.apply(s);
  for (const id in p.perks) PERKS[id].apply(s, p.perks[id]);
  for (const id of p.relics) RELICS[id].apply(s);
  for (const id of p.curses) CURSES[id].apply(s);
  s.maxHp += p.baseHpMod || 0;
  if (run.ardor >= 4) s.healMult -= 0.3;
  if (run.ardor >= 5) s.oilDrain *= 1.5;
  s.dmgMult = Math.max(0.2, s.dmgMult);
  s.rateMult = Math.max(0.3, s.rateMult);
  s.speedMult = Math.max(0.5, s.speedMult);
  s.lightMult = Math.max(0.35, s.lightMult);
  s.healMult = Math.max(0.1, s.healMult);
  s.maxHp = Math.max(10, Math.round(s.maxHp));
  s.armor = Math.max(0, s.armor);
  s.dodge = Math.min(0.6, s.dodge);
  s.crit = Math.min(1, s.crit);
  p.stats = s;
  p.hp = Math.min(p.hp, s.maxHp);
  p.oil = Math.min(p.oil, s.maxOil);
  p.dashCharges = Math.min(p.dashCharges, s.dashCharges);
}

function pDamage(p) {
  const s = p.stats;
  let m = s.dmgMult;
  if (p.statuses.rage) m += 0.5;
  if (p.statuses.weak) m -= 0.3;
  if (s.berserk) m += 1 - p.hp / s.maxHp;
  if (s.lowHpDmg && p.hp / s.maxHp < 0.4) m += s.lowHpDmg;
  return s.dmg * Math.max(0.15, m);
}
function pFireRate(p) {
  const s = p.stats;
  let m = s.rateMult;
  if (p.statuses.rage) m += 0.5;
  if (p.statuses.fury) m += s.fury;
  return s.fireRate * Math.max(0.3, m);
}
function pSpeed(p) {
  let m = p.stats.speedMult;
  if (p.statuses.slow) m -= 0.35;
  if (p.statuses.chill) m -= 0.3;
  return p.stats.speed * Math.max(0.35, m);
}
function pLight(p) {
  const s = p.stats;
  const frac = s.maxOil > 0 ? p.oil / s.maxOil : 0;
  let r = s.light * s.lightMult * (0.45 + 0.55 * Math.min(1, frac * 1.3));
  if (p.statuses.blind) r *= 0.45;
  return Math.max(26, r);
}

function healPlayer(v, raw) {
  const p = run.player;
  const amt = raw ? v : v * p.stats.healMult;
  const before = p.hp;
  p.hp = Math.min(p.stats.maxHp, p.hp + amt);
  const got = Math.round(p.hp - before);
  if (got > 0) {
    Floaters.add(p.x, p.y - 12, '+' + got, TEXT_COLORS.g);
    Particles.burst(p.x, p.y, 10, ['#8fd35a', '#d0ffb0'], 40, 0.6, { grav: -40 });
    Sound.play('heal');
  }
}
function addOil(v) {
  const p = run.player;
  p.oil = Math.min(p.stats.maxOil, p.oil + v);
}
function addCoins(v) {
  const p = run.player;
  const n = Math.max(1, Math.round(v * p.stats.coinMult));
  p.coins += n; run.coinsTotal += n;
  return n;
}
function giveCons(id) {
  const p = run.player;
  for (const s of p.cons) if (s && s.id === id && s.n < 3) { s.n++; return true; }
  const i = p.cons.findIndex(s => !s);
  if (i >= 0) { p.cons[i] = { id, n: 1 }; return true; }
  return false;
}
function useCons(i) {
  const p = run.player, s = p.cons[i];
  if (!s) return;
  const C = CONS[s.id];
  if (C.passive) { toast(C.name + ': passive effect', '#8a8294'); Sound.play('deny'); return; }
  if (!C.use(p)) { Sound.play('deny'); return; }
  s.n--;
  if (s.n <= 0) p.cons[i] = null;
}
function cleanse(a) {
  for (const k in a.statuses) if (STATUS[k] && STATUS[k].bad) delete a.statuses[k];
}

function addXP(v) {
  const p = run.player;
  p.xp += v * p.stats.xpMult;
  while (p.xp >= xpNeed(p.level)) {
    p.xp -= xpNeed(p.level);
    p.level++;
    run.pendingLevels++;
    Floaters.add(p.x, p.y - 16, 'LEVEL ' + p.level, TEXT_COLORS.y, { life: 1.4, vy: -20 });
    Particles.burst(p.x, p.y, 24, ['#f6cf57', '#fff2a8', '#f29c38'], 90, 0.8, { grav: -30 });
    Sound.play('levelup');
    healPlayer(6, true);
  }
}

// ---------------------------------------------------------------------
// Status effects
// ---------------------------------------------------------------------
function addStatus(a, name, dur, power = 0) {
  const isP = run && a === run.player;
  if (isP && STATUS[name] && STATUS[name].bad && (a.statuses.immune || a.stats.immune[name])) return;
  if (!isP && a.boss && (name === 'chill')) { dur *= 0.5; }
  let s = a.statuses[name];
  if (!s) s = a.statuses[name] = { t: 0, stacks: 0, tick: 0, power: 0 };
  s.t = Math.max(s.t, dur);
  s.power = Math.max(s.power, power);
  if (name === 'poison') s.stacks = Math.min(isP ? 3 : 5, s.stacks + 1);
  else if (name === 'chill') {
    s.stacks++;
    if (!isP && s.stacks >= 3 && !(a.freezeCd > 0)) {
      if (!a.boss) a.frozen = 1.6; else { a.frozen = 0.5; a.freezeCd = 6; }
      delete a.statuses.chill;
      Sound.play('freeze');
      Particles.burst(a.x, a.y, 10, ['#c8f2f5', '#7fd8e6'], 40, 0.5);
    }
  } else s.stacks = 1;
}
function updateStatuses(a, dt, isP) {
  for (const k in a.statuses) {
    const s = a.statuses[k];
    s.t -= dt;
    if (k === 'burn' || k === 'poison') {
      s.tick += dt;
      if (s.tick >= 0.5) {
        s.tick -= 0.5;
        if (isP) {
          const v = (k === 'burn' ? 2 : 0.8 * s.stacks) * (1 + 0.15 * (run.depth - 1));
          hurtPlayer(v, k === 'burn' ? 'The flames' : 'The poison', { dot: true });
        } else if (!a.dead) {
          const v = s.power * 0.5 * (k === 'poison' ? s.stacks : 1);
          hitEnemy(a, v, { dot: k });
          if (k === 'burn') Particles.add({ x: a.x + rnd(-3, 3), y: a.y - 4, vy: -30, life: 0.4, color: pick(['#f29c38', '#f6cf57']) });
        }
      }
    }
    if (s.t <= 0) delete a.statuses[k];
  }
}

// ---------------------------------------------------------------------
// Collisions with the map
// ---------------------------------------------------------------------
function collides(room, x, y, r, fly) {
  const x0 = Math.floor((x - r - RX) / TS), x1 = Math.floor((x + r - 0.01 - RX) / TS);
  const y0 = Math.floor((y - r - RY) / TS), y1 = Math.floor((y + r - 0.01 - RY) / TS);
  for (let ty = y0; ty <= y1; ty++) for (let tx = x0; tx <= x1; tx++) if (isSolidTile(room, tx, ty, fly)) return true;
  return false;
}
function moveAxis(a, d, axis, fly) {
  if (!d) return false;
  const room = run.room;
  const steps = Math.ceil(Math.abs(d));
  const inc = d / steps;
  for (let i = 0; i < steps; i++) {
    if (axis === 0) a.x += inc; else a.y += inc;
    if (collides(room, a.x, a.y, a.r, fly)) { if (axis === 0) a.x -= inc; else a.y -= inc; return true; }
  }
  return false;
}
function moveActor(a, dx, dy, fly) {
  const hx = moveAxis(a, dx, 0, fly);
  const hy = moveAxis(a, dy, 1, fly);
  return hx || hy;
}
function lineClear(x0, y0, x1, y1) {
  const room = run.room;
  const d = dist(x0, y0, x1, y1), n = Math.ceil(d / 6);
  for (let i = 1; i < n; i++) {
    const x = lerp(x0, x1, i / n), y = lerp(y0, y1, i / n);
    const [tx, ty] = worldToTile(x, y);
    if (blocksShot(room, tx, ty)) return false;
  }
  return true;
}

// flow field toward the player (pathing around obstacles)
function updateFlow() {
  const room = run.room, p = run.player;
  if (!run.flow) run.flow = new Int16Array(RW * RH);
  const f = run.flow;
  f.fill(-1);
  const [px, py] = worldToTile(p.x, p.y);
  if (px < 0 || py < 0 || px >= RW || py >= RH) return;
  const q = [py * RW + px];
  f[py * RW + px] = 0;
  let h = 0;
  while (h < q.length) {
    const k = q[h++], x = k % RW, y = (k / RW) | 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (nx < 1 || ny < 1 || nx >= RW - 1 || ny >= RH - 1) continue;
      const nk = ny * RW + nx;
      if (f[nk] >= 0) continue;
      if (isSolidTile(room, nx, ny, false)) continue;
      f[nk] = f[k] + 1; q.push(nk);
    }
  }
}
function flowAngle(e, tx, ty) {
  const f = run.flow;
  const p = run.player;
  if (!f || dist(e.x, e.y, tx, ty) < 26 || (tx !== p.x)) return angTo(e.x, e.y, tx, ty);
  const [cx, cy] = worldToTile(e.x, e.y);
  const cur = f[cy * RW + cx];
  if (cur <= 0) return angTo(e.x, e.y, tx, ty);
  if (cur <= 2 && lineClear(e.x, e.y, tx, ty)) return angTo(e.x, e.y, tx, ty);
  let best = cur, bx = cx, by = cy;
  for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
    const nx = cx + dx, ny = cy + dy;
    const v = f[ny * RW + nx];
    if (v < 0) continue;
    if (dx && dy && (f[cy * RW + nx] < 0 || f[ny * RW + cx] < 0)) continue;
    if (v < best) { best = v; bx = nx; by = ny; }
  }
  const c = tileCenter(bx, by);
  return angTo(e.x, e.y, c.x, c.y);
}

// ---------------------------------------------------------------------
// Player update
// ---------------------------------------------------------------------
function updatePlayer(dt) {
  const p = run.player, s = p.stats, room = run.room;
  p.anim += dt;
  updateStatuses(p, dt, true);
  if (p.dead) return;
  p.inv = Math.max(0, p.inv - dt);
  p.flareCd = Math.max(0, p.flareCd - dt);

  // aim
  const ka = Act.arrowAim();
  if (ka !== null) p.aim = ka;
  else if (Input.lastDevice === 'mouse' || Input.mL) p.aim = angTo(p.x, p.y - 4, Input.mx, Input.my);
  p.facing = Math.cos(p.aim) >= 0 ? 1 : -1;

  // dash
  if (p.dashCharges < s.dashCharges) {
    p.dashCd -= dt;
    if (p.dashCd <= 0) { p.dashCharges++; p.dashCd = s.dashCd; }
  } else p.dashCd = s.dashCd;
  const mv = Act.move();
  if (Act.dash() && p.dashCharges > 0 && p.dashT <= 0) {
    let dx = mv.x, dy = mv.y;
    if (!dx && !dy) { dx = Math.cos(p.aim); dy = Math.sin(p.aim); }
    const l = Math.hypot(dx, dy); dx /= l; dy /= l;
    p.dashDx = dx; p.dashDy = dy; p.dashT = 0.16 * s.dashDist;
    p.dashCharges--;
    Sound.play('dash');
    Particles.burst(p.x, p.y + 4, 8, ['#8a8294', '#55505e'], 40, 0.4);
    if (s.dashReflect) reflectBullets(p.x, p.y, 34);
  }

  let vx, vy;
  if (p.dashT > 0) {
    p.dashT -= dt;
    vx = p.dashDx * 330; vy = p.dashDy * 330;
    if (Math.random() < 0.7) Particles.add({ x: p.x + rnd(-2, 2), y: p.y + rnd(-4, 4), life: 0.3, color: 'rgba(160,190,210,0.6)', size: 2 });
    if (s.dashfire) { p.trailT -= dt; if (p.trailT <= 0) { p.trailT = 0.035; addFx({ type: 'fire', x: p.x, y: p.y + 3, r: 8, life: 2.2, owner: 'player' }); } }
    if (s.dashReflect) reflectBullets(p.x, p.y, 26);
  } else {
    const sp = pSpeed(p);
    vx = mv.x * sp; vy = mv.y * sp;
  }
  p.moving = Math.hypot(vx, vy) > 5;
  // Devourer's suction
  if (run.pull) { vx += run.pull.x; vy += run.pull.y; }
  const bx = moveAxis(p, vx * dt, 0, false);
  const by = moveAxis(p, vy * dt, 1, false);
  // corner sliding (helps line up with doors)
  if (bx && Math.abs(vy) < 1) nudge(p, 0, vx);
  if (by && Math.abs(vx) < 1) nudge(p, 1, vy);

  // fire
  p.fireCd -= dt;
  if (Act.firing() && p.fireCd <= 0 && !run.lockFire) {
    playerFire(p);
    p.fireCd = 1 / pFireRate(p);
  }
  // flare
  if (Act.flare()) tryFlare(p);
  // consumables
  const sl = Act.slot();
  if (sl >= 0) useCons(sl);
  if (p.echoT > 0) { p.echoT -= dt; if (p.echoT <= 0) fireVolley(p, p.aim, true); }

  // oil
  if (room.combat && !s.noOilDrain) {
    p.oil = Math.max(0, p.oil - 1.05 * s.oilDrain * dt);
  }
  // Warden Light shield
  if (s.guardian && !p.guardUp) { p.guardT -= dt; if (p.guardT <= 0) { p.guardUp = true; Sound.play('shield', 0.5); } }
  // temporary fireflies
  if (p.tempOrbitT > 0) { p.tempOrbitT -= dt; if (p.tempOrbitT <= 0) p.tempOrbit = 0; }
  p.orbitA += dt * 3.2;
  updateOrbitals(p, dt);
  // little sun
  if (s.sun && room.combat) {
    p.sunT -= dt;
    if (p.sunT <= 0) {
      p.sunT = 0.5;
      const R = pLight(p) * 0.45;
      for (const e of run.enemies) if (!e.dead && dist(e.x, e.y, p.x, p.y) < R) { hitEnemy(e, pDamage(p) * 0.35, { dot: 'burn' }); }
    }
  }
  // storm bottle
  if (s.storm && room.combat) {
    p.stormT -= dt;
    if (p.stormT <= 0) {
      p.stormT = 3;
      const targets = run.enemies.filter(e => !e.dead && !e.intangible && !e.spawning);
      if (targets.length) {
        const e = pick(targets);
        addFx({ type: 'bolt', pts: [[e.x + rnd(-10, 10), RY], [e.x, e.y]], life: 0.25 });
        hitEnemy(e, pDamage(p) * 2.5, { crit: false });
        Sound.play('bolt');
      }
    }
  }
  // spikes
  const [tx, ty] = worldToTile(p.x, p.y + 2);
  if (tileAt(room, tx, ty) === T.SPIKE && spikesUp(room) && p.dashT <= 0) hurtPlayer(8 * depthDmg(run.depth), 'The spikes');
}
// corner sliding: if the step is blocked, try moving sideways
function nudge(p, axis, d) {
  const room = run.room;
  const fx = axis === 0 ? sign(d) : 0, fy = axis === 1 ? sign(d) : 0;
  for (let k = 1; k <= 6; k++) for (const s of [1, -1]) {
    const ox = axis === 1 ? s * k : 0, oy = axis === 0 ? s * k : 0;
    if (!collides(room, p.x + ox, p.y + oy, p.r, false) && !collides(room, p.x + ox + fx, p.y + oy + fy, p.r, false)) {
      moveAxis(p, sign(ox) * 0.8, 0, false); moveAxis(p, sign(oy) * 0.8, 1, false);
      return;
    }
  }
}
function playerFire(p) {
  const s = p.stats;
  fireVolley(p, p.aim);
  if (s.echo && Math.random() < s.echo) p.echoT = 0.09;
}
function fireVolley(p, aim, isEcho) {
  const s = p.stats;
  const n = s.proj;
  const spread = n > 1 ? Math.min(0.9, 0.13 * (n - 1)) : 0;
  const dmg = pDamage(p);
  const lx = p.x + Math.cos(aim) * 7, ly = p.y - 3 + Math.sin(aim) * 6;
  p.shotCount++;
  const cometEvery = s.comet >= 2 ? 4 : 6;
  const isComet = s.comet > 0 && p.shotCount % cometEvery === 0 && !isEcho;
  for (let i = 0; i < n; i++) {
    const a = aim + (n > 1 ? -spread / 2 + spread * i / (n - 1) : 0) + rnd(-0.035, 0.035);
    const crit = Math.random() < s.crit;
    run.bullets.push({
      x: lx, y: ly, vx: Math.cos(a) * s.shotSpeed, vy: Math.sin(a) * s.shotSpeed, r: s.shotSize,
      dmg: dmg * (crit ? s.critMult : 1), crit, life: s.range / s.shotSpeed, pierce: s.pierce, bounce: s.bounce,
      hit: new Set(), kind: 'ember', t: 0
    });
  }
  if (isComet) {
    run.bullets.push({
      x: lx, y: ly, vx: Math.cos(aim) * s.shotSpeed * 1.15, vy: Math.sin(aim) * s.shotSpeed * 1.15, r: s.shotSize + 2,
      dmg: dmg * 3, crit: false, life: (s.range * 1.4) / s.shotSpeed, pierce: 99, bounce: 0, hit: new Set(), kind: 'comet', t: 0
    });
  }
  Particles.burst(lx, ly, 3, ['#f6cf57', '#f29c38'], 50, 0.2, { angle: aim, spread: 0.5 });
  Sound.play('shoot');
}

function tryFlare(p) {
  const s = p.stats;
  const cost = s.flareCost;
  if (p.flareCd > 0) return;
  if (p.oil < cost) { Sound.play('deny'); Floaters.add(p.x, p.y - 14, 'Not enough oil', TEXT_COLORS.d, { life: 0.9 }); p.flareCd = 0.4; return; }
  p.oil -= cost;
  p.flareCd = 0.9;
  const R = 64;
  const dmg = pDamage(p) * 3 * s.flareMult;
  for (const e of run.enemies) {
    if (e.dead || e.spawning) continue;
    const d = dist(e.x, e.y, p.x, p.y);
    if (d < R + e.r) {
      hitEnemy(e, dmg, { kx: e.x - p.x, ky: e.y - p.y, kb: 280 });
      addStatus(e, 'burn', 3, pDamage(p) * 0.6 * s.burnMult);
    }
  }
  for (const b of run.ebullets) if (!b.big && dist(b.x, b.y, p.x, p.y) < R + 6) { b.dead = true; Particles.burst(b.x, b.y, 3, '#f6cf57', 30, 0.3); }
  addFx({ type: 'flare', x: p.x, y: p.y, r: R, life: 0.45 });
  run.flashLight = { x: p.x, y: p.y, t: 0.5 };
  Particles.burst(p.x, p.y, 40, ['#fff2a8', '#f6cf57', '#f29c38'], 180, 0.6);
  shake(5); Sound.play('flare');
  p.inv = Math.max(p.inv, 0.25);
}

function reflectBullets(x, y, R) {
  const p = run.player;
  for (const b of run.ebullets) {
    if (b.dead || b.big) continue;
    if (dist(b.x, b.y, x, y) < R) {
      b.dead = true;
      const a = Math.atan2(-b.vy, -b.vx);
      run.bullets.push({ x: b.x, y: b.y, vx: Math.cos(a) * 240, vy: Math.sin(a) * 240, r: 3, dmg: pDamage(p) * 1.5, crit: false, life: 1.2, pierce: 1, bounce: 0, hit: new Set(), kind: 'ember', t: 0 });
      Particles.burst(b.x, b.y, 4, '#c8f2f5', 40, 0.3);
    }
  }
}

function orbitalPositions(p) {
  const n = p.stats.orbit + p.tempOrbit;
  const out = [];
  for (let i = 0; i < n; i++) {
    const a = p.orbitA + i * TAU / n;
    out.push({ x: p.x + Math.cos(a) * 22, y: p.y - 2 + Math.sin(a) * 22 });
  }
  return out;
}
function updateOrbitals(p, dt) {
  const orbs = orbitalPositions(p);
  if (!orbs.length) return;
  const dmg = pDamage(p) * 0.8;
  for (const o of orbs) {
    for (const e of run.enemies) {
      if (e.dead || e.intangible || e.spawning) continue;
      e.orbCd = (e.orbCd || 0);
      if (e.orbCd > 0) continue;
      if (dist2(o.x, o.y, e.x, e.y) < (e.r + 4) ** 2) { hitEnemy(e, dmg, { kx: e.x - p.x, ky: e.y - p.y, kb: 60 }); e.orbCd = 0.35; }
    }
    for (const b of run.ebullets) {
      if (!b.dead && !b.big && dist2(o.x, o.y, b.x, b.y) < (b.r + 4) ** 2) { b.dead = true; Particles.burst(b.x, b.y, 4, '#f6cf57', 40, 0.3); }
    }
  }
}

function hurtPlayer(amount, src, o = {}) {
  const p = run.player;
  if (p.dead || run.victoryT) return false;
  if (!o.dot) {
    if (p.inv > 0 || p.dashT > 0) return false;
    if (Math.random() < p.stats.dodge) {
      Floaters.add(p.x, p.y - 14, 'Dodged', TEXT_COLORS.c); p.inv = 0.35; return false;
    }
    if (p.guardUp) {
      p.guardUp = false; p.guardT = 10; p.inv = 0.7;
      Sound.play('shield'); Particles.burst(p.x, p.y, 20, ['#c8f2f5', '#7fd8e6', '#ffffff'], 90, 0.5);
      return false;
    }
  }
  let dmg = amount * p.stats.dmgTaken * (1 - Math.min(0.6, p.stats.armor * 0.07));
  if (p.statuses.fragile) dmg *= 1.3;
  if (p.oil <= 0) dmg *= 1.25;
  dmg = Math.max(1, Math.round(dmg));
  p.hp -= dmg;
  run.dmgTaken += dmg;
  p.lastHit = src || 'The dark';
  if (!o.dot) {
    p.inv = p.stats.iframes;
    shake(5); hitstop(0.06); screenFlash('#c02020', 0.35);
    Sound.play('hurt');
    Particles.burst(p.x, p.y, 12, ['#d04b3c', '#7e2530'], 70, 0.5);
    Floaters.add(p.x, p.y - 14, '-' + dmg, TEXT_COLORS.r);
    if (p.stats.ashguard) {
      addFx({ type: 'shockwave', x: p.x, y: p.y, r: 4, maxR: 70, spd: 220, owner: 'player', dmg: pDamage(p) * 2, hit: new Set() });
    }
  } else if (Save.data.settings.numbers) {
    Floaters.add(p.x, p.y - 12, '-' + dmg, src === 'The poison' ? TEXT_COLORS.g : TEXT_COLORS.o, { life: 0.5 });
  }
  if (p.hp <= 0) playerDeath();
  return true;
}

function playerDeath() {
  const p = run.player;
  if (p.stats.secondwind && !p.secondwindUsed) {
    p.secondwindUsed = true; p.hp = 1; p.inv = 2;
    toast('Last Breath', '#f6cf57', 'You survived by a breath.');
    Sound.play('shield'); return;
  }
  if (p.stats.revive && !p.coffinUsed) {
    p.coffinUsed = true; p.hp = Math.round(p.stats.maxHp / 2); p.inv = 2.5;
    toast('Coffin Nail', '#f6cf57', 'Death refuses you. For now.');
    reviveBurst(p); return;
  }
  const fi = p.cons.findIndex(s => s && s.id === 'feather');
  if (fi >= 0) {
    p.cons[fi].n--; if (p.cons[fi].n <= 0) p.cons[fi] = null;
    p.hp = Math.round(p.stats.maxHp / 2); p.inv = 2.5;
    toast('Phoenix Feather', '#f29c38', 'Rise from your ashes.');
    reviveBurst(p); return;
  }
  p.hp = 0; p.dead = true;
  run.deathT = 0;
  Sound.play('kill'); Sound.play('descend');
  Particles.burst(p.x, p.y, 40, ['#d04b3c', '#f6cf57', '#33475a'], 120, 1.0);
  shake(10);
}
function reviveBurst(p) {
  Sound.play('flare');
  Particles.burst(p.x, p.y, 50, ['#fff2a8', '#f29c38', '#e0574a'], 160, 1);
  for (const b of run.ebullets) b.dead = true;
  for (const e of run.enemies) if (!e.boss && dist(e.x, e.y, p.x, p.y) < 90) hitEnemy(e, pDamage(p) * 4, { kx: e.x - p.x, ky: e.y - p.y, kb: 300 });
  screenFlash('#fff2a8', 0.6);
}

// ---------------------------------------------------------------------
// Player projectiles
// ---------------------------------------------------------------------
function updateBullets(dt) {
  const room = run.room, p = run.player, s = p.stats;
  for (const b of run.bullets) {
    if (b.dead) continue;
    b.t += dt; b.life -= dt;
    if (b.life <= 0) { b.dead = true; continue; }
    if (s.homing && b.kind !== 'shard') {
      let best = null, bd = 140;
      for (const e of run.enemies) {
        if (e.dead || e.intangible || e.spawning || b.hit.has(e)) continue;
        const d = dist(b.x, b.y, e.x, e.y);
        if (d < bd) { bd = d; best = e; }
      }
      if (best) {
        const a = Math.atan2(b.vy, b.vx), ta = angTo(b.x, b.y, best.x, best.y);
        const na = a + clamp(angDiff(a, ta), -1, 1) * 3.2 * s.homing * dt;
        const sp = Math.hypot(b.vx, b.vy);
        b.vx = Math.cos(na) * sp; b.vy = Math.sin(na) * sp;
      }
    }
    // movement with bounces
    const nx = b.x + b.vx * dt, ny = b.y + b.vy * dt;
    let [tx, ty] = worldToTile(nx, b.y);
    let hitWall = false;
    if (blocksShot(room, tx, ty)) {
      damageTile(tx, ty, b.dmg);
      if (b.bounce > 0) { b.vx = -b.vx; b.bounce--; } else hitWall = true;
    } else b.x = nx;
    [tx, ty] = worldToTile(b.x, ny);
    if (!hitWall && blocksShot(room, tx, ty)) {
      damageTile(tx, ty, b.dmg);
      if (b.bounce > 0) { b.vy = -b.vy; b.bounce--; } else hitWall = true;
    } else if (!hitWall) b.y = ny;
    if (hitWall) {
      b.dead = true;
      Particles.burst(b.x, b.y, 4, ['#f29c38', '#f6cf57'], 40, 0.25);
      if (s.split && b.kind === 'ember') spawnShards(b);
      continue;
    }
    if (b.kind === 'comet' && Math.random() < 0.6) Particles.add({ x: b.x, y: b.y, life: 0.35, color: pick(['#c8f2f5', '#f6cf57']), size: 2 });
    // collision with enemies
    for (const e of run.enemies) {
      if (e.dead || e.intangible || e.spawning || b.hit.has(e)) continue;
      if (e.z > 10) continue;
      const rr = b.r + e.r;
      if (dist2(b.x, b.y, e.x, e.y) > rr * rr) continue;
      // front shield
      if (e.D && e.D.shield && !(e.frozen > 0) && !e.shieldDown) {
        const ab = angTo(e.x, e.y, b.x, b.y);
        if (Math.abs(angDiff(e.facing, ab)) < 1.0) {
          b.dead = true; Sound.play('block');
          Particles.burst(b.x, b.y, 5, ['#e8e4dc', '#a59fb0'], 60, 0.25);
          break;
        }
      }
      bulletHit(b, e);
      b.hit.add(e);
      if (b.pierce > 0) b.pierce--;
      else { b.dead = true; if (s.split && b.kind === 'ember') spawnShards(b); break; }
    }
  }
  run.bullets = run.bullets.filter(b => !b.dead);
}
function spawnShards(b) {
  const a = Math.atan2(b.vy, b.vx);
  for (const da of [-0.6, 0, 0.6]) {
    const aa = a + Math.PI + da + rnd(-0.2, 0.2);
    run.bullets.push({ x: b.x - Math.cos(a) * 3, y: b.y - Math.sin(a) * 3, vx: Math.cos(aa) * 170, vy: Math.sin(aa) * 170, r: 2, dmg: b.dmg * 0.4, crit: false, life: 0.35, pierce: 0, bounce: 0, hit: new Set(b.hit), kind: 'shard', t: 0 });
  }
}
function bulletHit(b, e) {
  const p = run.player, s = p.stats;
  hitEnemy(e, b.dmg, { crit: b.crit, kx: b.vx, ky: b.vy, kb: b.kind === 'comet' ? 160 : 90 });
  const base = pDamage(p);
  if (s.primal || Math.random() < s.burn || (b.crit && s.critBurn)) addStatus(e, 'burn', 3, base * 0.6 * s.burnMult);
  if (Math.random() < s.poison) addStatus(e, 'poison', 4, base * 0.35);
  if (s.chillAll || Math.random() < s.chill) addStatus(e, 'chill', 2.2);
  if (b.crit && s.critHeal) healPlayer(1, true);
  if (s.chain && Math.random() < s.chain) chainLightning(e, base * 0.6);
}
function chainLightning(from, dmg) {
  let cur = from;
  const hit = new Set([from]);
  const pts = [[from.x, from.y]];
  for (let i = 0; i < 3; i++) {
    let best = null, bd = 80;
    for (const e of run.enemies) {
      if (e.dead || hit.has(e) || e.intangible || e.spawning) continue;
      const d = dist(cur.x, cur.y, e.x, e.y);
      if (d < bd) { bd = d; best = e; }
    }
    if (!best) break;
    hit.add(best); pts.push([best.x, best.y]);
    hitEnemy(best, dmg, {});
    cur = best;
  }
  if (pts.length > 1) { addFx({ type: 'bolt', pts, life: 0.2 }); Sound.play('bolt', 0.6); }
}

// ---------------------------------------------------------------------
// Destructible tiles
// ---------------------------------------------------------------------
function damageTile(tx, ty, dmg) {
  const room = run.room;
  const t = tileAt(room, tx, ty);
  const k = ty * RW + tx;
  if (t === T.BARREL) {
    room.tileHp[k] = (room.tileHp[k] || 18) - dmg;
    if (room.tileHp[k] <= 0) explodeBarrel(tx, ty);
  } else if (t === T.URN) breakUrn(tx, ty);
}
function explodeBarrel(tx, ty) {
  const room = run.room;
  if (room.grid[ty][tx] !== T.BARREL) return;
  room.grid[ty][tx] = T.FLOOR; delete room.tileHp[ty * RW + tx];
  const c = tileCenter(tx, ty);
  addFx({ type: 'explosion', x: c.x, y: c.y, r: 36, dmg: 40 + 12 * run.depth, owner: 'neutral', life: 0.4, delay: 0.08 });
}
function breakUrn(tx, ty) {
  const room = run.room;
  room.grid[ty][tx] = T.FLOOR; delete room.tileHp[ty * RW + tx];
  const c = tileCenter(tx, ty);
  Particles.burst(c.x, c.y, 14, ['#9a8250', '#6a5a3a', '#c49a6a'], 70, 0.5, { grav: 120 });
  Sound.play('thud', 0.6);
  const r = Math.random();
  if (r < 0.35) room.pickups.push(makePickup('coin', c.x, c.y));
  else if (r < 0.45) room.pickups.push(makePickup('oil', c.x, c.y, { value: 12 }));
  else if (r < 0.48) room.pickups.push(makePickup('heart', c.x, c.y));
}

// ---------------------------------------------------------------------
// Enemies
// ---------------------------------------------------------------------
function makeEnemy(type, x, y, mod, o = {}) {
  const D = ENEMIES[type];
  const d = run.depth;
  let hp = D.hp * depthHp(d) * ardHp();
  const e = {
    type, D, name: D.name, x, y, vx: 0, vy: 0, r: D.r, hp, maxHp: hp,
    spd: D.spd * (1 + 0.03 * (d - 1)) * run.player.stats.enemySpeed, dmg: D.dmg * depthDmg(d) * ardDmg(),
    ai: D.ai, fly: !!D.fly, st: 0, state: 'idle', shotCd: rnd(0.9, 1.8) + (D.shot ? (D.shot.cd || 2) * 0.4 : 0),
    flash: 0, statuses: {}, frozen: 0, stun: 0.35, facing: 0, anim: rnd(0, 3), mod: mod || null, kbx: 0, kby: 0,
    xp: D.xp * 2 * (1 + 0.15 * (d - 1)), z: 0, alpha: 1, intangible: false, wind: 0, orbCd: 0, t: rnd(0, 5)
  };
  if (mod) {
    e.elite = true; e.hp *= 1.6; e.xp *= 2.2;
    if (mod === 'armored') e.hp *= 1.5;
    if (mod === 'swift') e.spd *= 1.4;
    e.maxHp = e.hp;
  }
  if (o.small) { e.hp *= 0.5; e.maxHp = e.hp; e.noSplit = true; }
  if (run.room && run.player.stats.bellStun && !o.summoned) e.stun = Math.max(e.stun, run.player.stats.bellStun);
  return e;
}

function enemyTarget(e) {
  const p = run.player;
  if (p.statuses.invis) {
    if (!e.wander || e.wanderT <= 0) {
      const tiles = reachTiles(run.room);
      const t = pick(tiles); const c = tileCenter(t[0], t[1]);
      e.wander = c; e.wanderT = rnd(1, 2);
    }
    return e.wander;
  }
  return p;
}

function eShoot(e, ang, spd, o = {}) {
  const ox = e.x + Math.cos(ang) * (e.r * 0.8), oy = e.y + Math.sin(ang) * (e.r * 0.8);
  run.ebullets.push({
    x: ox, y: oy, vx: Math.cos(ang) * spd, vy: Math.sin(ang) * spd, r: o.r || 3,
    dmg: o.dmg || e.dmg * 0.8, life: o.life || 5, kind: o.kind || 'orb', col: o.col || 'violet',
    status: o.status || null, src: e.name, accel: o.accel || 0, curve: o.curve || 0, t: 0, big: !!o.big
  });
}
function shotOpts(e, D) {
  const S = D.shot;
  const o = { kind: S.kind, col: S.col, status: S.status };
  if (e.mod === 'venom') o.status = 'poison';
  return o;
}

const AI = {
  chaser(e, dt, tg, m) {
    let go = true;
    if (e.D.burst) { e.t += dt; go = (e.t % 1.2) < 0.85; }
    const a = e.fly ? angTo(e.x, e.y, tg.x, tg.y) : flowAngle(e, tg.x, tg.y);
    const sp = go ? e.spd * m : 0;
    e.vx = Math.cos(a) * sp; e.vy = Math.sin(a) * sp;
    if (e.D.trail) {
      e.trailT = (e.trailT || 0) - dt;
      if (e.trailT <= 0) { e.trailT = 0.35; addFx({ type: 'fire', x: e.x, y: e.y + 3, r: 7, life: 2.6, owner: 'enemy', dmg: e.dmg * 0.5 }); }
    }
  },
  erratic(e, dt, tg, m) {
    e.t += dt;
    if (!e.jit || e.jitT <= 0) { e.jit = rnd(-1.4, 1.4); e.jitT = rnd(0.3, 0.7); }
    e.jitT -= dt;
    const a = angTo(e.x, e.y, tg.x, tg.y) + e.jit + Math.sin(e.t * 5) * 0.6;
    const d = dist(e.x, e.y, tg.x, tg.y);
    const sp = e.spd * m * (e.D.shot && d < 60 ? -0.6 : 1);
    e.vx = Math.cos(a) * sp; e.vy = Math.sin(a) * sp;
    if (e.D.shot) shooterFire(e, dt, tg);
  },
  shooter(e, dt, tg, m) {
    const d = dist(e.x, e.y, tg.x, tg.y);
    let a = flowAngle(e, tg.x, tg.y), sp = e.spd * m;
    if (d < 70 && lineClear(e.x, e.y, tg.x, tg.y)) { a = angTo(tg.x, tg.y, e.x, e.y); sp *= 0.8; }
    if (e.wind > 0) sp = 0;
    e.vx = Math.cos(a) * sp; e.vy = Math.sin(a) * sp;
    shooterFire(e, dt, tg);
  },
  caster(e, dt, tg, m) {
    const d = dist(e.x, e.y, tg.x, tg.y);
    const keep = e.D.keep || 90;
    let a = angTo(e.x, e.y, tg.x, tg.y), sp = e.spd * m;
    if (d < keep - 20) a += Math.PI;
    else if (d < keep + 30) { a += Math.PI / 2 * (e.orbitDir || (e.orbitDir = chance(0.5) ? 1 : -1)); }
    if (e.wind > 0) sp *= 0.2;
    e.vx = Math.cos(a) * sp; e.vy = Math.sin(a) * sp;
    shooterFire(e, dt, tg);
  },
  charger(e, dt, tg, m) {
    e.st += dt;
    switch (e.state) {
      case 'idle': case 'approach': {
        e.state = 'approach';
        const a = flowAngle(e, tg.x, tg.y);
        e.vx = Math.cos(a) * e.spd * m; e.vy = Math.sin(a) * e.spd * m;
        const d = dist(e.x, e.y, tg.x, tg.y);
        if (e.st > 1.0 && d < 130 && lineClear(e.x, e.y, tg.x, tg.y)) { e.state = 'wind'; e.st = 0; e.chargeA = angTo(e.x, e.y, tg.x, tg.y); }
        break;
      }
      case 'wind':
        e.vx = e.vy = 0;
        e.chargeA = e.chargeA + clamp(angDiff(e.chargeA, angTo(e.x, e.y, tg.x, tg.y)), -2 * dt, 2 * dt);
        e.wind = 0.55 - e.st;
        if (e.st > 0.55) { e.state = 'charge'; e.st = 0; Sound.play('dash', 0.6); }
        break;
      case 'charge': {
        const sp = e.D.chargeSpd * m * (e.mod === 'swift' ? 1.2 : 1);
        e.vx = Math.cos(e.chargeA) * sp; e.vy = Math.sin(e.chargeA) * sp;
        if (Math.random() < 0.5) Particles.add({ x: e.x, y: e.y + 4, life: 0.3, color: '#55505e', size: 2 });
        if (e.hitWall || e.st > 0.85) { e.state = 'recover'; e.st = 0; if (e.hitWall) { shake(2); Sound.play('thud', 0.5); } }
        break;
      }
      case 'recover':
        e.vx = e.vy = 0;
        if (e.st > 0.7) { e.state = 'approach'; e.st = 0; }
        break;
    }
  },
  turret(e, dt, tg, m) {
    e.vx = e.vy = 0;
    shooterFire(e, dt, tg);
  },
  hopper(e, dt, tg, m) {
    e.st += dt;
    if (e.state === 'idle') {
      e.vx = e.vy = 0;
      if (e.st > (e.D.hopCd || 1.6) * (e.mod === 'swift' ? 0.7 : 1)) {
        e.state = 'jump'; e.st = 0;
        const a = angTo(e.x, e.y, tg.x, tg.y), d = Math.min(95, dist(e.x, e.y, tg.x, tg.y));
        e.jx0 = e.x; e.jy0 = e.y;
        let tx = e.x + Math.cos(a) * d, ty = e.y + Math.sin(a) * d;
        e.jx1 = tx; e.jy1 = ty;
      }
    } else if (e.state === 'jump') {
      const T = 0.6, k = Math.min(1, e.st / T);
      const nx = lerp(e.jx0, e.jx1, k), ny = lerp(e.jy0, e.jy1, k);
      e.vx = (nx - e.x) / dt; e.vy = (ny - e.y) / dt;
      e.z = Math.sin(k * Math.PI) * 26;
      if (k >= 1) {
        e.z = 0; e.state = 'idle'; e.st = 0; e.vx = e.vy = 0;
        shake(1.5); Sound.play('thud', 0.4);
        Particles.burst(e.x, e.y + 4, 8, ['#55505e', '#3b3546'], 50, 0.4);
        const n = (e.D.landRing || 0) + (run.depth >= 3 ? 2 : 0);
        if (n && run.depth >= 2) { const off = rnd(TAU); for (let i = 0; i < n; i++) eShoot(e, off + i * TAU / n, 70, { kind: 'spore', status: e.mod === 'venom' ? 'poison' : null }); }
      }
    }
  },
  shielder(e, dt, tg, m) {
    const ta = angTo(e.x, e.y, tg.x, tg.y);
    e.st += dt;
    const d = dist(e.x, e.y, tg.x, tg.y);
    if (e.state === 'wind') {
      // charges the shot: the shield drops
      e.vx = e.vy = 0; e.wind = 0.6 - e.st; e.shieldDown = true;
      if (e.st > 0.6) {
        e.st = 0;
        if (e.D.slam) {
          e.state = 'rest';
          addFx({ type: 'shockwave', x: e.x, y: e.y, r: 4, maxR: 90, spd: 150, owner: 'enemy', dmg: e.dmg * 0.8, src: e.name });
          shake(3); Sound.play('thud');
        } else { e.state = 'lunge'; e.lungeA = ta; Sound.play('dash', 0.5); }
      }
      return;
    }
    if (e.state === 'lunge') {
      e.shieldDown = true;
      e.vx = Math.cos(e.lungeA) * 190 * m; e.vy = Math.sin(e.lungeA) * 190 * m;
      if (e.st > 0.35 || e.hitWall) { e.state = 'rest'; e.st = 0; }
      return;
    }
    if (e.state === 'rest') {
      e.shieldDown = true; e.vx = e.vy = 0;
      if (e.st > 0.7) { e.state = 'idle'; e.st = 0; }
      return;
    }
    e.shieldDown = false;
    e.facing = e.facing + clamp(angDiff(e.facing, ta), -1.0 * dt, 1.0 * dt);
    if (e.st > 2.8 && d < (e.D.slam ? 85 : 95)) { e.state = 'wind'; e.st = 0; e.facing = ta; return; }
    const a = flowAngle(e, tg.x, tg.y);
    e.vx = Math.cos(a) * e.spd * m; e.vy = Math.sin(a) * e.spd * m;
  },
  kamikaze(e, dt, tg, m) {
    if (e.state === 'fuse') {
      e.st += dt; e.vx *= 0.9; e.vy *= 0.9; e.wind = 0.45 - e.st;
      if (e.st > 0.45) {
        addFx({ type: 'explosion', x: e.x, y: e.y, r: 26, dmg: e.dmg, owner: 'enemy', life: 0.35, src: e.name });
        e.noDrops = false; killEnemy(e, { silent: true });
      }
      return;
    }
    const d = dist(e.x, e.y, tg.x, tg.y);
    const ta = angTo(e.x, e.y, tg.x, tg.y);
    e.ha = e.ha === undefined ? ta : e.ha + clamp(angDiff(e.ha, ta), -3 * dt, 3 * dt);
    e.vx = Math.cos(e.ha) * e.spd * m; e.vy = Math.sin(e.ha) * e.spd * m;
    if (d < 22) { e.state = 'fuse'; e.st = 0; Sound.play('warn'); }
  },
  phaser(e, dt, tg, m) {
    e.st += dt;
    const cyc = [['solid', 2.2], ['fadeout', 0.4], ['phased', 1.6], ['fadein', 0.4]];
    if (!e.ph) { e.ph = 0; }
    const [nm, du] = cyc[e.ph];
    if (e.st > du) { e.st = 0; e.ph = (e.ph + 1) % 4; }
    const cur = cyc[e.ph][0];
    e.intangible = cur === 'phased';
    e.alpha = cur === 'solid' ? 1 : cur === 'phased' ? 0.2 : cur === 'fadeout' ? 1 - e.st / 0.4 * 0.8 : 0.2 + e.st / 0.4 * 0.8;
    const a = angTo(e.x, e.y, tg.x, tg.y);
    const sp = e.spd * m * (cur === 'phased' ? 1.5 : 1);
    e.vx = Math.cos(a) * sp; e.vy = Math.sin(a) * sp;
    void nm;
  },
  dasher(e, dt, tg, m) {
    e.st += dt;
    switch (e.state) {
      case 'idle':
        e.vx = Math.sin(e.st * 12) * 10; e.vy = 0;
        if (e.st > 0.8) { e.state = 'aim'; e.st = 0; }
        break;
      case 'aim':
        e.vx = e.vy = 0; e.wind = 0.4 - e.st;
        e.dashA = angTo(e.x, e.y, tg.x, tg.y);
        if (e.st > 0.4) { e.state = 'dash'; e.st = 0; }
        break;
      case 'dash': {
        const sp = 260 * m * (e.mod === 'swift' ? 1.2 : 1);
        e.vx = Math.cos(e.dashA) * sp; e.vy = Math.sin(e.dashA) * sp;
        if (e.st > 0.45 || e.hitWall) { e.state = 'idle'; e.st = 0; }
        break;
      }
    }
    e.facingX = Math.cos(e.dashA || 0) >= 0 ? 1 : -1;
  },
  teleporter(e, dt, tg, m) {
    e.st += dt;
    e.vx = e.vy = 0;
    switch (e.state) {
      case 'idle': e.state = 'hidden'; e.st = 0; break;
      case 'hidden':
        e.intangible = true; e.alpha = 0;
        if (e.st > 1.0) {
          const tiles = reachTiles(run.room).filter(([x, y]) => { const c = tileCenter(x, y); const d = dist(c.x, c.y, tg.x, tg.y); return d > 50 && d < 90; });
          if (tiles.length) { const t = pick(tiles); const c = tileCenter(t[0], t[1]); e.x = c.x; e.y = c.y; }
          e.state = 'appear'; e.st = 0;
          Particles.burst(e.x, e.y, 12, ['#231830', '#d08aff'], 50, 0.5);
        }
        break;
      case 'appear':
        e.alpha = e.st / 0.35; e.intangible = e.st < 0.2;
        if (e.st > 0.35) { e.state = 'attack'; e.st = 0; e.alpha = 1; e.intangible = false; }
        break;
      case 'attack':
        e.wind = 0.4 - e.st;
        if (e.st > 0.4) {
          const S = e.D.shot, a = angTo(e.x, e.y, tg.x, tg.y);
          for (let i = 0; i < S.n; i++) eShoot(e, a - S.spread / 2 + S.spread * i / (S.n - 1), S.spd, shotOpts(e, e.D));
          Sound.play('enemyShoot');
          e.state = 'linger'; e.st = 0;
        }
        break;
      case 'linger': if (e.st > 0.9) { e.state = 'vanish'; e.st = 0; } break;
      case 'vanish':
        e.alpha = 1 - e.st / 0.3;
        if (e.st > 0.3) { e.state = 'hidden'; e.st = 0; }
        break;
    }
  },
  summoner(e, dt, tg, m) {
    AI.caster(e, dt, tg, m);
    e.sumT = (e.sumT === undefined ? 2.5 : e.sumT) - dt;
    if (e.sumT <= 0) {
      e.sumT = 5.5;
      const mine = run.enemies.filter(x => x.summoner === e && !x.dead).length;
      if (mine < 3 && run.enemies.length < 16) {
        for (let i = 0; i < 2; i++) {
          const a = rnd(TAU);
          const x = e.x + Math.cos(a) * 18, y = e.y + Math.sin(a) * 18;
          addFx({ type: 'spawn', x, y, life: 0.6, spec: { type: e.D.summon, summoner: e } });
        }
        e.wind = 0.5;
      }
    }
  },
  spinner(e, dt, tg, m) {
    e.st += dt;
    const a = angTo(e.x, e.y, tg.x, tg.y) + Math.PI / 2;
    e.vx = Math.cos(a) * e.spd * m; e.vy = Math.sin(a) * e.spd * m;
    const firing = (e.st % 4) < 2.4;
    if (firing && e.st > 1) {
      e.spinA = (e.spinA || 0) + dt * 2.1;
      e.fireAcc = (e.fireAcc || 0) + dt;
      const S = e.D.shot;
      if (e.fireAcc > S.cd) {
        e.fireAcc = 0;
        for (let i = 0; i < S.arms; i++) eShoot(e, e.spinA + i * TAU / S.arms, S.spd, shotOpts(e, e.D));
        Sound.play('enemyShoot', 0.5);
      }
    }
    e.wind = !firing && (e.st % 4) > 3.6 ? 0.3 : 0;
  },
};

function shooterFire(e, dt, tg) {
  const S = e.D.shot;
  if (!S) return;
  if (e.burstLeft > 0) {
    e.burstT -= dt;
    if (e.burstT <= 0) {
      e.burstT = 0.13; e.burstLeft--;
      eShoot(e, angTo(e.x, e.y, tg.x, tg.y), S.spd, shotOpts(e, e.D));
      Sound.play('enemyShoot');
    }
    return;
  }
  if (e.wind > 0) {
    e.wind -= dt;
    if (e.wind <= 0) {
      const a = angTo(e.x, e.y, tg.x, tg.y);
      const o = shotOpts(e, e.D);
      if (S.ring) { const off = rnd(TAU); for (let i = 0; i < S.ring; i++) eShoot(e, off + i * TAU / S.ring, S.spd, o); }
      else if (S.burst) { e.burstLeft = S.burst; e.burstT = 0; }
      else if (S.n > 1) { for (let i = 0; i < S.n; i++) eShoot(e, a - S.spread / 2 + S.spread * i / (S.n - 1), S.spd, o); }
      else eShoot(e, a, S.spd, o);
      if (!S.burst) Sound.play('enemyShoot');
      e.wind = 0;
    }
    return;
  }
  e.shotCd -= dt * (e.mod === 'swift' ? 1.3 : 1);
  if (e.shotCd <= 0) {
    const d = dist(e.x, e.y, tg.x, tg.y);
    if (d < 230 && (S.ring || lineClear(e.x, e.y, tg.x, tg.y))) {
      e.wind = S.ring ? 0.5 : 0.35;
      e.shotCd = S.cd * rnd(0.85, 1.15);
    } else e.shotCd = 0.4;
  }
}

function updateEnemies(dt) {
  const p = run.player;
  for (const e of run.enemies) {
    if (e.dead) continue;
    e.anim += dt;
    e.flash -= dt;
    e.orbCd -= dt;
    if (e.freezeCd > 0) e.freezeCd -= dt;
    e.hitWall = false;
    if (e.wanderT !== undefined) e.wanderT -= dt;
    updateStatuses(e, dt, false);
    if (e.dead) continue;
    if (e.mod === 'regen' && e.hp < e.maxHp) e.hp = Math.min(e.maxHp, e.hp + e.maxHp * 0.03 * dt);
    if (e.dying !== undefined) { bossDying(e, dt); continue; }
    if (e.frozen > 0) { e.frozen -= dt; e.vx = e.vy = 0; }
    else if (e.stun > 0) { e.stun -= dt; e.vx = e.vy = 0; }
    else {
      const m = e.statuses.chill ? 0.55 : 1;
      const tg = enemyTarget(e);
      if (e.boss) bossUpdate(e, dt, tg, m);
      else AI[e.ai](e, dt, tg, m);
    }
    // movement + knockback
    const kx = e.kbx * dt, ky = e.kby * dt;
    e.kbx *= Math.max(0, 1 - 9 * dt); e.kby *= Math.max(0, 1 - 9 * dt);
    const hit = moveActor(e, e.vx * dt + kx, e.vy * dt + ky, e.fly || e.z > 4);
    if (hit) e.hitWall = true;
    if (!e.boss && Math.abs(e.vx) > 1 && e.ai !== 'shielder') e.facing = Math.atan2(e.vy, e.vx);
    // contact
    if (!e.intangible && e.z < 6 && !e.spawning && !p.dead && e.frozen <= 0) {
      const rr = e.r + p.r;
      if (dist2(e.x, e.y, p.x, p.y) < rr * rr) {
        if (hurtPlayer(e.dmg, e.name)) {
          if (e.D && e.D.touch) addStatus(p, e.D.touch, 2.5);
          if (e.mod === 'venom') addStatus(p, 'poison', 3);
          if (e.mod === 'vampiric') e.hp = Math.min(e.maxHp, e.hp + e.maxHp * 0.15);
          if (p.stats.thorns) hitEnemy(e, pDamage(p) * p.stats.thorns, { kx: e.x - p.x, ky: e.y - p.y, kb: 150 });
        }
      }
    }
  }
  // separation
  const en = run.enemies;
  for (let i = 0; i < en.length; i++) {
    const a = en[i];
    if (a.dead || a.boss) continue;
    for (let j = i + 1; j < en.length; j++) {
      const b = en[j];
      if (b.dead || b.boss || a.fly !== b.fly) continue;
      const dx = b.x - a.x, dy = b.y - a.y, rr = a.r + b.r;
      const d2 = dx * dx + dy * dy;
      if (d2 < rr * rr && d2 > 0.01) {
        const d = Math.sqrt(d2), push = (rr - d) * 0.5;
        const nx = dx / d, ny = dy / d;
        moveActor(a, -nx * push, -ny * push, a.fly);
        moveActor(b, nx * push, ny * push, b.fly);
      }
    }
  }
  run.enemies = run.enemies.filter(e => !e.dead);
}

function hitEnemy(e, dmg, o = {}) {
  if (e.dead || (e.intangible && !o.force) || e.spawning) return;
  if (e.boss && (e.invuln > 0 || e.dying !== undefined)) { if (!o.dot) Particles.burst(e.x, e.y, 2, '#a59fb0', 30, 0.2); return; }
  if (e.mod === 'armored') dmg *= 0.7;
  if (e.frozen > 0) dmg *= 1.15;
  e.hp -= dmg;
  run.dmgDealt += dmg;
  if (!o.dot) e.flash = 0.08;
  if (o.kx !== undefined && !e.boss) {
    const l = Math.hypot(o.kx, o.ky) || 1;
    const f = (o.kb || 90) * (e.D && e.D.shield ? 0.35 : 1) * (e.elite ? 0.6 : 1);
    e.kbx += o.kx / l * f; e.kby += o.ky / l * f;
  }
  if (Save.data.settings.numbers) {
    const col = o.dot === 'burn' ? TEXT_COLORS.o : o.dot === 'poison' ? TEXT_COLORS.g : o.crit ? TEXT_COLORS.y : TEXT_COLORS.w;
    const v = dmg < 10 ? Math.round(dmg * 10) / 10 : Math.round(dmg);
    if (!o.dot || v >= 1) Floaters.add(e.x, e.y - e.r - 6, String(Math.max(1, Math.round(v))), col, { scale: o.crit ? 1 : 1, life: o.crit ? 0.9 : 0.6 });
  }
  if (!o.dot) {
    Particles.burst(e.x, e.y, o.crit ? 6 : 3, o.crit ? ['#fff2a8', '#f6cf57'] : ['#e8e4dc', '#a59fb0'], 50, 0.25);
    Sound.play(o.crit ? 'crit' : 'hit');
    if (o.crit) hitstop(0.02);
  }
  if (e.hp <= 0) killEnemy(e, o);
}

function killEnemy(e, o = {}) {
  if (e.dead) return;
  if (e.boss) { startBossDeath(e); return; }
  e.dead = true;
  run.kills++;
  const p = run.player, s = p.stats;
  const cols = enemyColors(e);
  Particles.burst(e.x, e.y, e.elite ? 26 : 16, cols, 90, 0.6, { grav: 60 });
  if (!o.silent) Sound.play('kill');
  shake(e.elite ? 3 : 1.5);
  if (!e.summoned || chance(0.5)) {
    // experience
    const n = Math.min(8, Math.max(1, Math.round(e.xp / 2)));
    for (let i = 0; i < n; i++) run.room.pickups.push(makePickup('xp', e.x, e.y, { value: e.xp / n }));
    // oil
    addOil(2.5 + (e.elite ? 4 : 0));
    run.oilFx.push({ x: e.x, y: e.y, t: 0 });
    // coins and hearts
    const cc = e.elite ? 0.8 : 0.13;
    if (Math.random() < cc) run.room.pickups.push(makePickup(Math.random() < 0.12 ? 'coin5' : 'coin', e.x, e.y));
    const hc = run.ardor >= 4 ? 0.02 : 0.035;
    if (Math.random() < hc + (e.elite ? 0.1 : 0)) run.room.pickups.push(makePickup('heart', e.x, e.y));
    if (e.elite && Math.random() < 0.25) run.room.pickups.push(makePickup('cons', e.x, e.y, { id: randomCons() }));
  }
  // perk effects
  if (s.leech) healPlayer(s.leech, true);
  if (s.fury) addStatus(p, 'fury', 2.5);
  if (s.explode) addFx({ type: 'explosion', x: e.x, y: e.y, r: 26 + 6 * s.explode, dmg: pDamage(p) * (0.9 + 0.5 * s.explode), owner: 'player', life: 0.3, small: true });
  if (s.ashTrail) addFx({ type: 'fire', x: e.x, y: e.y, r: 12, life: 3, owner: 'player' });
  // enemy effects
  if (e.D.split && !e.noSplit) {
    for (let i = 0; i < e.D.splitN; i++) {
      const ne = makeEnemy(e.D.split, e.x + rnd(-5, 5), e.y + rnd(-5, 5), null, { summoned: true });
      ne.stun = 0.25; ne.kbx = rnd(-90, 90); ne.kby = rnd(-90, 90);
      run.enemies.push(ne);
    }
  }
  if (e.mod === 'splitter' && !e.noSplit) {
    for (let i = 0; i < 2; i++) {
      const ne = makeEnemy(e.type, e.x + rnd(-6, 6), e.y + rnd(-6, 6), null, { small: true, summoned: true });
      ne.stun = 0.3; ne.kbx = rnd(-100, 100); ne.kby = rnd(-100, 100);
      run.enemies.push(ne);
    }
  }
  if (e.mod === 'volatile') { const off = rnd(TAU); for (let i = 0; i < 8; i++) eShoot(e, off + i * TAU / 8, 80, { kind: 'fire', dmg: e.dmg * 0.7 }); }
  if (e.D.deathCloud) addFx({ type: 'cloud', x: e.x, y: e.y, r: 24, life: 3.5, owner: 'enemy', status: 'poison' });
}

function enemyColors(e) {
  switch (e.type) {
    case 'rat': return ['#6e5a4e', '#a06868', '#d04b3c'];
    case 'bat': return ['#3a2246', '#6a3a80', '#d04b3c'];
    case 'skeleton': case 'skull': return ['#e8e4dc', '#a59fb0', '#c57ae0'];
    case 'ghoul': return ['#5d7a5a', '#34482f', '#7e2530'];
    case 'grub': case 'grubling': return ['#c9b28a', '#e9dcb0', '#8fd35a'];
    case 'spore': return ['#a33a7a', '#e88fc0', '#4f8a3a'];
    case 'hopper': return ['#c8443a', '#e8e4dc'];
    case 'moth': return ['#b8b0a0', '#e6e0cc'];
    case 'automaton': case 'turret': return ['#9a8250', '#6b6478', '#f29c38'];
    case 'slag': case 'spark': return ['#f29c38', '#f6cf57', '#b5571f'];
    case 'smith': return ['#8a5a34', '#6b6478'];
    case 'drowned': case 'eel': case 'jelly': return ['#5aa0aa', '#9ad8dc', '#4f7ab8'];
    case 'shade': case 'wisp': return ['#231830', '#d08aff', '#7a3a9a'];
    case 'cultist': return ['#9a2f3a', '#5c1f2a', '#f6cf57'];
    case 'knight': return ['#c0c8d0', '#7a8290'];
    case 'eye': return ['#8a3aa0', '#e0574a', '#e8e4dc'];
  }
  return ['#e8e4dc', '#a59fb0'];
}

// ---------------------------------------------------------------------
// Boss
// ---------------------------------------------------------------------
function makeBoss(id, x, y) {
  const B = BOSSES[id];
  const d = run.depth;
  const cyc = ((d - 1) % 5) + 1;
  const extra = d > 5 ? depthHp(d) / depthHp(cyc) : 1;
  const hp = B.hp * extra * ardHp();
  return {
    boss: true, bid: id, B, D: { name: B.name }, name: B.name, x, y, vx: 0, vy: 0, r: B.r, hp, maxHp: hp,
    spd: B.spd, dmg: 13 * depthDmg(d) * ardDmg(), ai: 'boss', fly: true, phase: 0, pat: null, gapT: 1.6, invuln: 0,
    lastPat: -1, z: 0, alpha: 1, statuses: {}, frozen: 0, stun: 0, flash: 0, anim: 0, kbx: 0, kby: 0, facing: 0,
    intangible: false, orbCd: 0, xp: 60 + 30 * d, wind: 0, st: 0
  };
}

function bossShoot(e, a, s, extra = {}) {
  eShoot(e, a, s.spd || 90, Object.assign({ kind: s.kind || 'orb', col: s.col, status: s.status, dmg: e.dmg * 0.75, life: 7 }, extra));
}

const PATTERNS = {
  ring(e, P, dt, s) {
    if (!P.init) { P.init = true; P.k = 0; P.next = 0.4; e.wind = 0.4; }
    if (P.t >= P.next && P.k < s.count) {
      const off = (P.k % 2) * Math.PI / s.n + rnd(0, 0.15);
      for (let i = 0; i < s.n; i++) bossShoot(e, off + i * TAU / s.n, s);
      P.k++; P.next += s.gap; Sound.play('enemyShoot');
    }
    return P.k >= s.count && P.t > P.next;
  },
  aimed(e, P, dt, s) {
    if (!P.init) { P.init = true; P.k = 0; P.next = 0.35; e.wind = 0.35; }
    if (P.t >= P.next && P.k < s.count) {
      const p = run.player, a = angTo(e.x, e.y, p.x, p.y);
      for (let i = 0; i < s.n; i++) bossShoot(e, a - s.spread / 2 + s.spread * i / (s.n - 1), s);
      P.k++; P.next += s.gap; Sound.play('enemyShoot');
    }
    return P.k >= s.count && P.t > P.next;
  },
  spiral(e, P, dt, s) {
    if (!P.init) { P.init = true; P.ang = rnd(TAU); P.acc = 0; e.wind = 0.3; }
    if (P.t < 0.3) return false;
    P.acc += dt * s.rate;
    while (P.acc >= 1) {
      P.acc -= 1;
      for (let i = 0; i < s.arms; i++) bossShoot(e, P.ang + i * TAU / s.arms, s);
      Sound.play('enemyShoot', 0.5);
    }
    P.ang += s.rot * dt;
    return P.t > s.dur + 0.3;
  },
  summon(e, P, dt, s) {
    if (!P.init) {
      P.init = true;
      const alive = run.enemies.filter(x => !x.dead && !x.boss).length;
      const n = Math.min(s.count, Math.max(0, s.cap - alive));
      for (let i = 0; i < n; i++) {
        const tiles = reachTiles(run.room).filter(([x, y]) => { const c = tileCenter(x, y); return dist(c.x, c.y, e.x, e.y) < 90 && dist(c.x, c.y, run.player.x, run.player.y) > 50; });
        if (!tiles.length) break;
        const t = pick(tiles), c = tileCenter(t[0], t[1]);
        addFx({ type: 'spawn', x: c.x, y: c.y, life: 0.8, spec: { type: s.type, summoned: true } });
      }
      e.wind = 0.6; Sound.play('spawn');
    }
    return P.t > 0.9;
  },
  charge(e, P, dt, s) {
    if (!P.init) { P.init = true; P.k = 0; P.sub = 'aim'; P.st = 0; }
    P.st += dt;
    const p = run.player;
    if (P.sub === 'aim') {
      e.vx = e.vy = 0;
      P.a = angTo(e.x, e.y, p.x, p.y);
      e.wind = 0.65 - P.st;
      e.chargeLine = P.a;
      if (P.st > 0.65) { P.sub = 'go'; P.st = 0; e.chargeLine = null; Sound.play('dash'); }
    } else if (P.sub === 'go') {
      e.vx = Math.cos(P.a) * s.spd; e.vy = Math.sin(P.a) * s.spd;
      if (Math.random() < 0.6) Particles.add({ x: e.x + rnd(-6, 6), y: e.y + e.r, life: 0.4, color: '#55505e', size: 2 });
      if (e.hitWallBoss || P.st > 1.3) {
        P.sub = 'stop'; P.st = 0; e.vx = e.vy = 0;
        shake(5); Sound.play('thud');
        if (s.ring) { const off = rnd(TAU); for (let i = 0; i < s.ring; i++) bossShoot(e, off + i * TAU / s.ring, { spd: 85, kind: s.kind, status: s.status }); }
      }
    } else if (P.sub === 'stop') {
      e.vx = e.vy = 0;
      if (P.st > 0.45) { P.k++; P.sub = 'aim'; P.st = 0; if (P.k >= s.count) return true; }
    }
    return false;
  },
  slam(e, P, dt, s) {
    if (!P.init) { P.init = true; P.k = 0; P.sub = 'rise'; P.st = 0; }
    P.st += dt;
    const p = run.player;
    if (P.sub === 'rise') {
      if (P.st < 0.05) { P.x0 = e.x; P.y0 = e.y; }
      if (P.st < 0.45) { P.tx = p.x; P.ty = p.y; }
      const k = Math.min(1, P.st / 0.65);
      e.z = Math.sin(k * Math.PI / 2) * 50;
      e.x = lerp(P.x0, P.tx, k); e.y = lerp(P.y0, P.ty, k);
      e.vx = e.vy = 0; e.intangible = e.z > 20;
      e.slamTarget = { x: P.tx, y: P.ty };
      if (k >= 1) { P.sub = 'fall'; P.st = 0; }
    } else if (P.sub === 'fall') {
      e.z = Math.max(0, 50 * (1 - P.st / 0.14));
      if (P.st > 0.14) {
        e.z = 0; e.intangible = false; e.slamTarget = null;
        // reposition out of any obstacles
        if (collides(run.room, e.x, e.y, e.r, true)) { const c = tileCenter(14, 7); e.x = c.x; e.y = c.y; }
        addFx({ type: 'shockwave', x: e.x, y: e.y, r: 6, maxR: 130, spd: 170, owner: 'enemy', dmg: e.dmg, src: e.name });
        if (s.ring) { const off = rnd(TAU); for (let i = 0; i < s.ring; i++) bossShoot(e, off + i * TAU / s.ring, { spd: 80, kind: s.kind, status: s.status }); }
        shake(7); Sound.play('explosion', 0.6);
        Particles.burst(e.x, e.y + e.r, 30, ['#55505e', '#8a8294', '#3b3546'], 120, 0.6);
        P.sub = 'rest'; P.st = 0;
      }
    } else if (P.sub === 'rest') {
      if (P.st > 0.5) { P.k++; P.sub = 'rise'; P.st = 0; if (P.k >= s.count) return true; }
    }
    return false;
  },
  rain(e, P, dt, s) {
    if (!P.init) { P.init = true; P.acc = 0; P.made = 0; e.wind = 0.4; }
    P.acc += dt * s.n / s.dur;
    while (P.acc >= 1 && P.made < s.n) {
      P.acc -= 1; P.made++;
      const p = run.player;
      let x, y;
      if (P.made % 3 === 0) { x = p.x + rnd(-10, 10); y = p.y + rnd(-10, 10); }
      else { const tiles = reachTiles(run.room); const t = pick(tiles); const c = tileCenter(t[0], t[1]); x = c.x; y = c.y; }
      addFx({ type: 'warn', x, y, r: s.hit === 'cloud' ? 20 : 22, life: 0.95, hit: s.hit, dmg: e.dmg, src: e.name });
    }
    return P.t > s.dur + 1.0;
  },
  wall(e, P, dt, s) {
    if (!P.init) { P.init = true; P.k = 0; P.next = 0.3; }
    if (P.t >= P.next && P.k < s.count) {
      P.k++; P.next += 1.1;
      const side = pick(['w', 'e', 'n', 's']);
      const horiz = side === 'w' || side === 'e';
      const n = horiz ? 13 : 27;
      const gap = rndi(1, n - 5);
      for (let i = 0; i < n; i++) {
        if (i >= gap && i < gap + 4) continue;
        let x, y, a;
        if (side === 'w') { x = RX + TS * 1.2; y = RY + TS * (1.5 + i); a = 0; }
        else if (side === 'e') { x = RX + TS * 27.8; y = RY + TS * (1.5 + i); a = Math.PI; }
        else if (side === 'n') { x = RX + TS * (1.5 + i); y = RY + TS * 1.2; a = Math.PI / 2; }
        else { x = RX + TS * (1.5 + i); y = RY + TS * 13.8; a = -Math.PI / 2; }
        run.ebullets.push({ x, y, vx: Math.cos(a) * 75, vy: Math.sin(a) * 75, r: 3, dmg: e.dmg * 0.7, life: 8, kind: s.kind || 'orb', col: 'red', status: s.status, src: e.name, accel: 0, curve: 0, t: 0, ghost: true });
      }
      Sound.play('warn');
    }
    return P.k >= s.count && P.t > P.next;
  },
  teleport(e, P, dt, s) {
    if (!P.init) { P.init = true; P.sub = 'out'; P.st = 0; }
    P.st += dt;
    e.vx = e.vy = 0;
    if (P.sub === 'out') {
      e.alpha = 1 - P.st / 0.35; e.intangible = P.st > 0.2;
      if (P.st > 0.35) {
        const p = run.player;
        const tiles = reachTiles(run.room).filter(([x, y]) => { const c = tileCenter(x, y); return dist(c.x, c.y, p.x, p.y) > 100 && x > 2 && x < RW - 3 && y > 2 && y < RH - 3; });
        if (tiles.length) { const t = pick(tiles), c = tileCenter(t[0], t[1]); e.x = c.x; e.y = c.y; }
        Particles.burst(e.x, e.y, 20, ['#9ad8dc', '#16343c'], 70, 0.6);
        P.sub = 'in'; P.st = 0;
      }
    } else if (P.sub === 'in') {
      e.alpha = P.st / 0.35; e.intangible = P.st < 0.25;
      if (P.st > 0.35) { e.alpha = 1; e.intangible = false; P.sub = 'shoot'; P.st = 0; e.wind = 0.3; }
    } else if (P.sub === 'shoot') {
      if (P.st > 0.3) {
        const p = run.player, a = angTo(e.x, e.y, p.x, p.y);
        for (let i = 0; i < s.n; i++) bossShoot(e, a - s.spread / 2 + s.spread * i / (s.n - 1), s);
        Sound.play('enemyShoot');
        return true;
      }
    }
    return false;
  },
  beam(e, P, dt, s) {
    if (!P.init) {
      P.init = true;
      const p = run.player, a0 = angTo(e.x, e.y, p.x, p.y) + Math.PI / s.count;
      const dir = chance(0.5) ? 1 : -1;
      for (let i = 0; i < s.count; i++) addFx({ type: 'beam', owner: e, ang: a0 + i * TAU / s.count, rot: s.rot * dir, warm: s.warm, dur: s.dur, life: s.warm + s.dur, len: 420, w: 7, dmg: e.dmg, src: e.name });
      Sound.play('warn');
    }
    e.vx = e.vy = 0;
    return P.t > s.warm + s.dur + 0.2;
  },
  darkpulse(e, P, dt, s) {
    if (!P.init) { P.init = true; e.wind = 0.7; }
    if (P.t > 0.7 && !P.done) {
      P.done = true;
      addStatus(run.player, 'blind', 5);
      const off = rnd(TAU);
      for (let i = 0; i < 18; i++) bossShoot(e, off + i * TAU / 18, { spd: 75, kind: 'void' });
      Sound.play('curse'); screenFlash('#000000', 0.6);
      addFx({ type: 'shockwave', x: e.x, y: e.y, r: 6, maxR: 260, spd: 300, owner: 'visual', dmg: 0 });
    }
    return P.t > 1.2;
  },
  drain(e, P, dt, s) {
    if (!P.init) { P.init = true; P.acc = 0; Sound.play('roar', 0.6); }
    const p = run.player;
    const a = angTo(p.x, p.y, e.x, e.y);
    run.pull = { x: Math.cos(a) * 42, y: Math.sin(a) * 42 };
    p.oil = Math.max(0, p.oil - 10 * dt);
    if (Math.random() < 0.7) {
      const ang = rnd(TAU), r = rnd(60, 160);
      Particles.add({ x: e.x + Math.cos(ang) * r, y: e.y + Math.sin(ang) * r, vx: -Math.cos(ang) * r * 1.5, vy: -Math.sin(ang) * r * 1.5, life: 0.6, color: pick(['#f6cf57', '#a24ab8']), drag: 0 });
    }
    P.acc += dt;
    if (P.acc > 1.3) {
      P.acc = 0;
      if (run.enemies.filter(x => !x.dead && !x.boss).length < 8) {
        const ang = rnd(TAU);
        addFx({ type: 'spawn', x: e.x + Math.cos(ang) * 30, y: e.y + Math.sin(ang) * 30, life: 0.5, spec: { type: 'wisp', summoned: true } });
      }
    }
    if (P.t > s.dur) { run.pull = null; return true; }
    return false;
  },
};

function bossUpdate(e, dt, tg, m) {
  e.hitWallBoss = e.hitWall;
  e.wind = Math.max(0, e.wind - dt);
  const ph = e.B.phases;
  if (e.phase + 1 < ph.length && e.hp / e.maxHp <= ph[e.phase + 1].at) {
    e.phase++;
    e.pat = null; e.gapT = 1.4; e.invuln = 1.4;
    e.z = 0; e.intangible = false; e.alpha = 1; e.slamTarget = null; e.chargeLine = null; run.pull = null;
    Sound.play('roar'); shake(8); screenFlash('#ffffff', 0.3);
    const off = rnd(TAU);
    for (let i = 0; i < 20; i++) bossShoot(e, off + i * TAU / 20, { spd: 70, kind: ph[0].pats[0].kind || 'orb' });
    toast(e.name + ' is enraged!', '#e0574a');
  }
  if (e.invuln > 0) { e.invuln -= dt; e.vx = e.vy = 0; return; }
  const rate = (run.ardor >= 5 ? 1.25 : 1) * (1 + 0.04 * Math.max(0, run.depth - 5));
  const cur = ph[e.phase];
  if (!e.pat) {
    e.gapT -= dt * rate;
    // movement between attacks
    const p = run.player;
    const d = dist(e.x, e.y, tg.x, tg.y);
    let a = angTo(e.x, e.y, tg.x, tg.y);
    if (d < 70) a += Math.PI;
    else if (d < 120) a += Math.PI / 2;
    e.vx = Math.cos(a) * e.spd * m; e.vy = Math.sin(a) * e.spd * m;
    void p;
    if (e.gapT <= 0) {
      let i;
      do { i = rndi(0, cur.pats.length - 1); } while (i === e.lastPat && cur.pats.length > 1);
      e.lastPat = i;
      e.pat = { s: cur.pats[i], t: 0 };
      e.vx = e.vy = 0;
    }
  } else {
    const done = PATTERNS[e.pat.s.p](e, e.pat, dt * rate, e.pat.s);
    e.pat.t += dt * rate;
    if (e.pat && (e.pat.s.p !== 'charge' && e.pat.s.p !== 'slam')) { e.vx *= 0.9; e.vy *= 0.9; if (e.pat.s.p !== 'drain' && e.spd > 0) { e.vx = 0; e.vy = 0; } }
    if (done) { e.pat = null; e.gapT = cur.gap; run.pull = null; }
  }
  if (e.vx) e.facing = Math.atan2(e.vy, e.vx);
}

function startBossDeath(e) {
  if (e.dying !== undefined) return;
  e.dying = 0; e.hp = 0; e.pat = null; e.vx = e.vy = 0; e.z = 0; e.alpha = 1; e.intangible = true;
  e.slamTarget = null; e.chargeLine = null; run.pull = null;
  for (const b of run.ebullets) b.dead = true;
  for (const f of run.fx) if (f.type === 'beam' || f.type === 'warn') f.dead = true;
  for (const x of run.enemies) if (!x.boss) killEnemy(x, { silent: true });
  Sound.play('roar'); hitstop(0.25);
  Music.setIntensity(0);
}
function bossDying(e, dt) {
  e.dying += dt;
  e.flash = (e.dying * 10 % 1) < 0.5 ? 0.05 : 0;
  if (Math.random() < 0.3) {
    const x = e.x + rnd(-e.r, e.r), y = e.y + rnd(-e.r, e.r);
    Particles.burst(x, y, 10, ['#fff2a8', '#f6cf57', '#f29c38', '#e8e4dc'], 90, 0.5);
    Sound.play('hit');
    shake(3);
  }
  if (e.dying > 2.0) {
    e.dead = true;
    run.kills++;
    Save.data.stats.bossKills++;
    Save.write();
    shake(12); Sound.play('explosion'); screenFlash('#fff2a8', 0.8);
    Particles.burst(e.x, e.y, 120, ['#fff2a8', '#f6cf57', '#f29c38', '#e8e4dc', '#c57ae0'], 220, 1.4);
    onBossDefeated(e);
  }
}

// ---------------------------------------------------------------------
// Enemy projectiles
// ---------------------------------------------------------------------
function updateEnemyBullets(dt) {
  const p = run.player, room = run.room;
  for (const b of run.ebullets) {
    if (b.dead) continue;
    b.t += dt; b.life -= dt;
    if (b.life <= 0) { b.dead = true; continue; }
    if (b.accel) { const sp = Math.hypot(b.vx, b.vy), ns = Math.max(10, sp + b.accel * dt); b.vx *= ns / sp; b.vy *= ns / sp; }
    if (b.curve) { const a = Math.atan2(b.vy, b.vx) + b.curve * dt, sp = Math.hypot(b.vx, b.vy); b.vx = Math.cos(a) * sp; b.vy = Math.sin(a) * sp; }
    b.x += b.vx * dt; b.y += b.vy * dt;
    const [tx, ty] = worldToTile(b.x, b.y);
    if (!b.ghost && blocksShot(room, tx, ty)) {
      const t = tileAt(room, tx, ty);
      if (t !== T.WALL && t !== T.DOOR) damageTile(tx, ty, 4);
      b.dead = true; Particles.burst(b.x, b.y, 3, bulletColor(b), 30, 0.2); continue;
    }
    if (b.ghost && (tx <= 0 || ty <= 0 || tx >= RW - 1 || ty >= RH - 1)) { b.dead = true; continue; }
    if (!p.dead && dist2(b.x, b.y, p.x, p.y - 1) < (b.r + 2.5) ** 2) {
      if (hurtPlayer(b.dmg, b.src)) {
        if (b.status) addStatus(p, b.status, b.status === 'poison' ? 3.5 : b.status === 'burn' ? 2.5 : 3);
        b.dead = true;
      } else if (p.dashT <= 0 && p.inv <= 0) b.dead = true;
    }
  }
  run.ebullets = run.ebullets.filter(b => !b.dead);
}
function bulletColor(b) {
  switch (b.kind) {
    case 'bone': return '#e8e4dc';
    case 'spore': return '#e88fc0';
    case 'dust': return '#d8d0c0';
    case 'fire': return '#f29c38';
    case 'ice': return '#9fe0ff';
    case 'void': return '#a24ab8';
  }
  return { violet: '#c57ae0', red: '#e0574a', cyan: '#7fd8e6' }[b.col] || '#c57ae0';
}

// ---------------------------------------------------------------------
// Effects (explosions, waves, clouds, fire, beams, summons, bombs)
// ---------------------------------------------------------------------
function addFx(f) { f.t = 0; if (f.life === undefined) f.life = 1; run.fx.push(f); return f; }

function placeBomb(x, y, owner) {
  addFx({ type: 'bomb', x, y, life: 1.5, owner });
  Sound.play('thud', 0.4);
}

function updateFx(dt) {
  const p = run.player, room = run.room;
  for (const f of run.fx) {
    if (f.dead) continue;
    if (f.delay) { f.delay -= dt; if (f.delay > 0) continue; f.delay = 0; }
    f.t += dt;
    switch (f.type) {
      case 'explosion':
        if (!f.done) {
          f.done = true;
          explosionHit(f);
        }
        break;
      case 'bomb':
        if (f.t >= f.life) {
          addFx({ type: 'explosion', x: f.x, y: f.y, r: 40, dmg: 60 + 15 * run.depth, owner: 'neutral', life: 0.4, reveal: true });
        } else if (Math.floor(f.t * (f.t > 1 ? 12 : 5)) !== Math.floor((f.t - dt) * (f.t > 1 ? 12 : 5))) Sound.play('tick');
        break;
      case 'shockwave': {
        f.r += f.spd * dt;
        if (f.owner === 'enemy' && !f.hitP && !p.dead) {
          const d = dist(f.x, f.y, p.x, p.y);
          if (Math.abs(d - f.r) < 7) { f.hitP = true; hurtPlayer(f.dmg, f.src || 'A shockwave'); }
        } else if (f.owner === 'player') {
          for (const e of run.enemies) {
            if (e.dead || f.hit.has(e)) continue;
            const d = dist(f.x, f.y, e.x, e.y);
            if (Math.abs(d - f.r) < 8 + e.r) { f.hit.add(e); hitEnemy(e, f.dmg, { kx: e.x - f.x, ky: e.y - f.y, kb: 160 }); addStatus(e, 'burn', 2.5, pDamage(p) * 0.6 * p.stats.burnMult); }
          }
        }
        if (f.r >= f.maxR) f.dead = true;
        break;
      }
      case 'warn':
        if (f.t >= f.life) {
          if (f.hit === 'cloud') addFx({ type: 'cloud', x: f.x, y: f.y, r: f.r, life: 3.2, owner: 'enemy', status: 'poison' });
          else addFx({ type: 'explosion', x: f.x, y: f.y, r: f.r, dmg: f.dmg, owner: 'enemy', life: 0.35, src: f.src });
        }
        break;
      case 'cloud':
        f.tick = (f.tick || 0) - dt;
        if (f.owner === 'enemy' && f.tick <= 0 && dist(f.x, f.y, p.x, p.y) < f.r * Math.min(1, f.t * 3)) { f.tick = 0.5; addStatus(p, f.status, 2.5); }
        if (Math.random() < 0.3) Particles.add({ x: f.x + rnd(-f.r, f.r) * 0.8, y: f.y + rnd(-f.r, f.r) * 0.6, vy: -8, life: 0.8, color: 'rgba(120,200,80,0.5)', size: 2 });
        break;
      case 'fire':
        f.tick = (f.tick || 0) - dt;
        if (f.tick <= 0) {
          f.tick = 0.35;
          if (f.owner === 'player') {
            for (const e of run.enemies) if (!e.dead && !e.fly && dist(f.x, f.y, e.x, e.y) < f.r + e.r) { hitEnemy(e, pDamage(p) * 0.3, { dot: 'burn' }); addStatus(e, 'burn', 2, pDamage(p) * 0.5 * p.stats.burnMult); }
          } else if (dist(f.x, f.y, p.x, p.y) < f.r + 2 && p.dashT <= 0) {
            addStatus(p, 'burn', 2);
          }
        }
        if (Math.random() < 0.25) Particles.add({ x: f.x + rnd(-f.r, f.r) * 0.7, y: f.y + rnd(-3, 3), vy: -25, life: 0.45, color: pick(['#f29c38', '#f6cf57', '#b5571f']) });
        break;
      case 'beam': {
        const e = f.owner;
        if (e.dead || e.dying !== undefined) { f.dead = true; break; }
        f.x = e.x; f.y = e.y;
        if (f.t > f.warm) {
          f.ang += f.rot * dt;
          // collision with the player: point-segment distance
          const ex = f.x + Math.cos(f.ang) * f.len, ey = f.y + Math.sin(f.ang) * f.len;
          const d = pointSegDist(p.x, p.y, f.x, f.y, ex, ey);
          if (d < f.w / 2 + 2) hurtPlayer(f.dmg, f.src);
          if (Math.random() < 0.5) { const k = rnd(0.1, 1); Particles.add({ x: lerp(f.x, ex, k), y: lerp(f.y, ey, k), vx: rnd(-20, 20), vy: rnd(-20, 20), life: 0.3, color: '#e0a0ff', above: true }); }
        } else {
          // during the warning the beam slowly follows the player
          f.ang += f.rot * dt * 0.15;
        }
        break;
      }
      case 'spawn':
        if (f.t >= f.life) {
          const sp = f.spec;
          if (sp.type === 'BOSS') {
            const b = makeBoss(sp.boss, f.x, f.y);
            run.enemies.push(b); run.bossRef = b;
          } else {
            const e = makeEnemy(sp.type, f.x, f.y, sp.mod, { summoned: sp.summoned });
            if (sp.summoner) { e.summoner = sp.summoner; }
            e.summoned = !!sp.summoned;
            run.enemies.push(e);
          }
          Particles.burst(f.x, f.y, 10, ['#c57ae0', '#4b2a5c', '#e8e4dc'], 60, 0.4);
        }
        break;
      case 'bolt': case 'flare': break;
    }
    if (f.t >= f.life) f.dead = true;
  }
  run.fx = run.fx.filter(f => !f.dead);
  room.spikeT += dt;
}
function pointSegDist(px, py, x0, y0, x1, y1) {
  const dx = x1 - x0, dy = y1 - y0;
  const l2 = dx * dx + dy * dy;
  let t = l2 ? ((px - x0) * dx + (py - y0) * dy) / l2 : 0;
  t = clamp(t, 0, 1);
  return dist(px, py, x0 + t * dx, y0 + t * dy);
}

function explosionHit(f) {
  const p = run.player, room = run.room;
  Particles.burst(f.x, f.y, f.small ? 14 : 34, ['#fff2a8', '#f6cf57', '#f29c38', '#b5571f', '#3b3546'], f.r * 4, 0.6);
  Sound.play('explosion', f.small ? 0.4 : 1);
  shake(f.small ? 2 : 6);
  run.flashLight = { x: f.x, y: f.y, t: 0.3, r: f.r * 3 };
  if (f.owner !== 'enemy') {
    for (const e of run.enemies) {
      if (e.dead) continue;
      if (dist(f.x, f.y, e.x, e.y) < f.r + e.r) hitEnemy(e, f.dmg, { kx: e.x - f.x, ky: e.y - f.y, kb: 220, force: true });
    }
  }
  if (f.owner !== 'player' && !p.dead) {
    if (dist(f.x, f.y, p.x, p.y) < f.r + 2) hurtPlayer(f.owner === 'neutral' ? Math.min(14, f.dmg * 0.3) : f.dmg, f.src || 'An explosion');
  }
  // tiles involved
  if (!f.small || f.owner === 'neutral') {
    const [cx, cy] = worldToTile(f.x, f.y);
    const R = Math.ceil(f.r / TS);
    for (let ty = cy - R; ty <= cy + R; ty++) for (let tx = cx - R; tx <= cx + R; tx++) {
      if (tx < 1 || ty < 1 || tx >= RW - 1 || ty >= RH - 1) continue;
      const c = tileCenter(tx, ty);
      if (dist(c.x, c.y, f.x, f.y) > f.r + 6) continue;
      const t = room.grid[ty][tx];
      if (t === T.BARREL) explodeBarrel(tx, ty);
      else if (t === T.URN) breakUrn(tx, ty);
      else if ((t === T.CRACK || t === T.ROCK) && f.owner === 'neutral') {
        room.grid[ty][tx] = T.FLOOR; room.bgDirty = true;
        Particles.burst(c.x, c.y, 12, ['#55505e', '#3b3546', '#8a8294'], 80, 0.6, { grav: 100 });
        if (t === T.CRACK && Math.random() < 0.6) room.pickups.push(makePickup(Math.random() < 0.7 ? 'coin' : 'cons', c.x, c.y, { id: 'bomb' }));
      }
    }
  }
  // secret passages
  if (f.reveal) {
    for (const d in room.doors) {
      const n = room.doors[d];
      if (n.type !== 'secret' || n.found) continue;
      const dc = doorCenter(d);
      if (dist(dc.x, dc.y, f.x, f.y) < f.r + 22) {
        n.found = true;
        for (const [tx, ty] of DIRS[d].tiles) room.grid[ty][tx] = T.DOOR;
        room.bgDirty = true;
        toast('A secret passage!', '#f6cf57');
        Sound.play('chest');
      }
    }
  }
}

function freezeAll(t) {
  for (const e of run.enemies) if (!e.dead) { e.frozen = e.boss ? t * 0.4 : t; }
  Sound.play('freeze'); screenFlash('#c8f2f5', 0.4);
  Particles.burst(run.player.x, run.player.y, 40, ['#c8f2f5', '#7fd8e6', '#ffffff'], 200, 0.8);
}

// ---------------------------------------------------------------------
// Pickups
// ---------------------------------------------------------------------
function makePickup(type, x, y, o = {}) {
  const a = rnd(TAU), s = rnd(20, 70);
  return { type, x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, z: 0, vz: type === 'xp' ? 30 : 70, t: 0, value: o.value || 1, id: o.id || null, magnet: false };
}
function randomCons() {
  const keys = Object.keys(CONS);
  return weightedPick(keys, k => CONS[k].w);
}

function updatePickups(dt) {
  const p = run.player, room = run.room;
  const pr = p.stats.pickup;
  for (const k of room.pickups) {
    if (k.dead) continue;
    k.t += dt;
    k.vz -= 260 * dt; k.z += k.vz * dt;
    if (k.z < 0) { k.z = 0; k.vz = Math.abs(k.vz) > 30 ? -k.vz * 0.4 : 0; }
    const d = dist(k.x, k.y, p.x, p.y);
    const auto = k.type === 'xp' || (k.type === 'coin' || k.type === 'coin5') && !room.combat;
    if (!p.dead && k.t > 0.35 && (d < pr || (auto && !room.combat && k.t > 0.6) || k.magnet)) {
      if (k.type === 'heart' && p.hp >= p.stats.maxHp) { /* resta a terra */ }
      else if (k.type === 'cons' && !canTakeCons(k.id)) { }
      else {
        k.magnet = true;
        const a = angTo(k.x, k.y, p.x, p.y), sp = 160 + k.t * 60;
        k.vx = Math.cos(a) * sp; k.vy = Math.sin(a) * sp;
      }
    } else { k.vx *= Math.max(0, 1 - 4 * dt); k.vy *= Math.max(0, 1 - 4 * dt); }
    const ox = k.x, oy = k.y;
    k.x += k.vx * dt; k.y += k.vy * dt;
    if (!k.magnet) {
      const [tx, ty] = worldToTile(k.x, k.y);
      if (isSolidTile(room, tx, ty, false)) { k.x = ox; k.y = oy; k.vx = -k.vx * 0.5; k.vy = -k.vy * 0.5; }
    }
    if (d < 7 && k.t > 0.3 && !p.dead) collectPickup(k);
  }
  room.pickups = room.pickups.filter(k => !k.dead);
}
function canTakeCons(id) {
  const p = run.player;
  return p.cons.some(s => !s || (s.id === id && s.n < 3));
}
function collectPickup(k) {
  const p = run.player;
  switch (k.type) {
    case 'xp': addXP(k.value); Sound.play('xp'); break;
    case 'coin': { const n = addCoins(1); Floaters.add(p.x, p.y - 12, '+' + n, TEXT_COLORS.y, { life: 0.5 }); Sound.play('coin'); break; }
    case 'coin5': { const n = addCoins(5); Floaters.add(p.x, p.y - 12, '+' + n, TEXT_COLORS.y, { life: 0.6 }); Sound.play('coin'); break; }
    case 'heart': if (p.hp >= p.stats.maxHp) return; healPlayer(12 + 2 * run.depth); break;
    case 'oil': addOil(k.value || 25); Sound.play('oil'); Floaters.add(p.x, p.y - 12, '+olio', TEXT_COLORS.o, { life: 0.6 }); break;
    case 'key': p.keys++; Sound.play('pickup'); Floaters.add(p.x, p.y - 12, '+1 key', TEXT_COLORS.y, { life: 0.8 }); break;
    case 'cons':
      if (!giveCons(k.id)) return;
      Sound.play('pickup'); toast(CONS[k.id].name, '#ece6d8', CONS[k.id].desc);
      break;
  }
  k.dead = true;
}

// ---------------------------------------------------------------------
// Interactions with room objects
// ---------------------------------------------------------------------
function nearestObject() {
  const p = run.player, room = run.room;
  let best = null, bd = 22;
  for (const o of room.objects) {
    if (o.gone || o.type === 'merchant') continue;
    if (o.type === 'chest' && o.open) continue;
    const d = dist(o.x, o.y, p.x, p.y);
    if (d < bd) { bd = d; best = o; }
  }
  return best;
}

function interact(o) {
  const p = run.player;
  switch (o.type) {
    case 'relic': takeRelic(o); break;
    case 'chest': openChest(o); break;
    case 'shopitem': buyItem(o); break;
    case 'shrine': useShrine(o); break;
    case 'trapdoor': descend(); break;
  }
  void p;
}

function takeRelic(o) {
  const p = run.player;
  const R = RELICS[o.id];
  p.relics.push(o.id);
  if (R.curse && !p.curses.includes(R.curse)) p.curses.push(R.curse);
  recalcStats();
  if (R.onTake) R.onTake(p);
  o.gone = true;
  if (o.group) for (const x of run.room.objects) if (x.group === o.group && x !== o && !x.gone) { x.gone = true; Particles.burst(x.x, x.y - 8, 20, ['#8a8294', '#55505e'], 60, 0.6); }
  banner(R.name, R.desc, '#f6cf57', R.icon);
  Sound.play('chest');
  Particles.burst(o.x, o.y - 10, 30, ['#f6cf57', '#fff2a8'], 100, 0.8, { grav: -40 });
  if (R.curse) setTimeout(() => Sound.play('curse'), 300);
}

function openChest(o) {
  const p = run.player, room = run.room;
  if (o.gold && !o.free) {
    if (p.keys <= 0) { Sound.play('deny'); toast('A key is needed', '#8a8294'); return; }
    p.keys--;
  }
  o.open = true;
  Sound.play('chest');
  Particles.burst(o.x, o.y - 4, 20, ['#f6cf57', '#fff2a8', '#c49a6a'], 90, 0.6, { grav: 60 });
  const drops = [];
  if (o.gold) {
    const extra = p.stats.goldKeys ? 1 : 0;
    drops.push(['cons', randomCons()]);
    for (let i = 0; i < 3 + extra * 2; i++) drops.push([Math.random() < 0.25 ? 'coin5' : 'coin']);
    if (Math.random() < 0.5 + extra * 0.3) drops.push(['heart']);
    if (Math.random() < 0.3 + extra * 0.3) drops.push(['cons', randomCons()]);
    if (Math.random() < 0.25 + extra * 0.25) {
      const r = randomRelics(1, { shuffle: a => shuffle(a) })[0];
      if (r) room.objects.push({ type: 'relic', id: r, x: o.x, y: o.y - 26 });
    }
  } else {
    const n = rndi(2, 4);
    for (let i = 0; i < n; i++) {
      const r = Math.random();
      if (r < 0.5) drops.push(['coin']);
      else if (r < 0.65) drops.push(['heart']);
      else if (r < 0.8) drops.push(['oil']);
      else if (r < 0.93) drops.push(['cons', randomCons()]);
      else drops.push(['key']);
    }
  }
  for (const [t, id] of drops) room.pickups.push(makePickup(t, o.x, o.y - 2, { id, value: t === 'oil' ? 25 : 1 }));
}

function priceOf(o) { return Math.max(1, Math.round(o.price * run.player.stats.priceMult)); }
function buyItem(o) {
  const p = run.player;
  const price = priceOf(o);
  if (p.coins < price) { Sound.play('deny'); toast('Not enough coins', '#8a8294'); return; }
  const it = o.item;
  if (it.kind === 'cons' && !canTakeCons(it.id)) { Sound.play('deny'); toast('Bag full', '#8a8294'); return; }
  if (it.kind === 'heal' && p.hp >= p.stats.maxHp) { Sound.play('deny'); toast('You are already at full strength', '#8a8294'); return; }
  p.coins -= price;
  o.gone = true;
  Sound.play('buy');
  if (it.kind === 'cons') giveCons(it.id);
  else if (it.kind === 'heal') healPlayer(Math.round(p.stats.maxHp * 0.4));
  else if (it.kind === 'key') { p.keys++; }
  else if (it.kind === 'relic') takeRelic({ id: it.id, x: o.x, y: o.y });
  const m = run.room.objects.find(x => x.type === 'merchant');
  if (m) m.line = pick(['Deal done.', 'Excellent choice.', 'Come back anytime.', 'May the light go with you.']);
}

function useShrine(o) {
  const p = run.player;
  if (o.uses <= 0) return;
  switch (o.kind) {
    case 'blood': {
      if (p.stats.maxHp <= 30) { Sound.play('deny'); toast('You are too weak to offer more', '#8a8294'); return; }
      o.uses--;
      run.bloodPaid = (run.bloodPaid || 0) + 15;
      p.baseHpMod = (p.baseHpMod || 0) - 15;
      p.hp = Math.max(1, p.hp - 15);
      const choices = rollPerkChoices(3, 1);
      if (choices.length) { run.forcedChoices = choices; run.pendingLevels++; }
      Sound.play('curse'); screenFlash('#7e2530', 0.4);
      Particles.burst(o.x, o.y - 10, 30, ['#d04b3c', '#7e2530'], 90, 0.7);
      recalcStats();
      break;
    }
    case 'fortune': {
      if (p.coins < 5) { Sound.play('deny'); toast('5 coins needed', '#8a8294'); return; }
      p.coins -= 5; o.uses--;
      Sound.play('coin');
      const r = Math.random();
      if (r < 0.35) toast('The coins sink into silence.', '#8a8294');
      else if (r < 0.65) { for (let i = 0; i < 8; i++) run.room.pickups.push(makePickup('coin', o.x, o.y)); toast('The fountain returns double!', '#f6cf57'); }
      else if (r < 0.88) { run.room.pickups.push(makePickup('cons', o.x, o.y, { id: randomCons() })); toast('Something resurfaces from the water.', '#ece6d8'); }
      else { run.pendingLevels++; toast('A gift from the fountain!', '#c57ae0'); }
      break;
    }
    case 'fountain': {
      if (p.curses.length && p.coins >= 20) {
        p.coins -= 20; o.uses--;
        const c = p.curses.splice(rndi(0, p.curses.length - 1), 1)[0];
        recalcStats();
        toast('Curse purified: ' + CURSES[c].name, '#7fd8e6');
        Sound.play('heal');
      } else if (!p.curses.length) {
        o.uses--;
        healPlayer(999, true); addOil(999);
        toast('The pure water restores you.', '#7fd8e6');
      } else { Sound.play('deny'); toast('20 coins needed', '#8a8294'); return; }
      break;
    }
    case 'pact': {
      o.uses--;
      const r = randomRelics(1, { shuffle: a => shuffle(a) })[0];
      const avail = Object.keys(CURSES).filter(c => !p.curses.includes(c));
      if (avail.length) p.curses.push(pick(avail));
      recalcStats();
      if (r) takeRelic({ id: r, x: o.x, y: o.y });
      Sound.play('curse'); screenFlash('#4b2a5c', 0.5);
      toast('The pact is sealed.', '#c57ae0', avail.length ? 'New curse: ' + CURSES[p.curses[p.curses.length - 1]].name : '');
      break;
    }
  }
}

function revealMap() {
  for (const r of run.floor.rooms) { r.seen = true; if (r.type === 'secret') r.mapped = true; }
  toast('The map is revealed', '#d8c49a');
  Sound.play('pickup');
}
function rollDice() {
  const p = run.player;
  const ch = rollPerkChoices(1, 0);
  if (ch.length) {
    const id = ch[0];
    p.perks[id] = (p.perks[id] || 0) + 1;
    recalcStats();
    if (PERKS[id].onTake) PERKS[id].onTake(p);
    banner(PERKS[id].name, PERKS[id].desc, RARITY[PERKS[id].rar].col, PERKS[id].icon);
  }
  if (Math.random() < 0.3) {
    const avail = Object.keys(CURSES).filter(c => !p.curses.includes(c));
    if (avail.length) { const c = pick(avail); p.curses.push(c); recalcStats(); setTimeout(() => toast('Curse: ' + CURSES[c].name, '#c57ae0', CURSES[c].desc), 700); Sound.play('curse'); }
  }
  Sound.play('pickup');
}

// perk choice (weighted by rarity)
function rollPerkChoices(n, minRar = 0) {
  const p = run.player;
  const luck = p.stats.luck + (run.depth - 1) * 0.25;
  const avail = Object.keys(PERKS).filter(id => (p.perks[id] || 0) < PERKS[id].max && PERKS[id].rar >= minRar);
  const out = [];
  const pool = avail.slice();
  while (out.length < n && pool.length) {
    const id = weightedPick(pool, k => {
      const r = PERKS[k].rar;
      return RARITY[r].w * (r === 0 ? 1 : 1 + luck * (0.3 + r * 0.35));
    });
    out.push(id);
    pool.splice(pool.indexOf(id), 1);
  }
  return out;
}
