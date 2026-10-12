'use strict';
// =====================================================================
// Game flow: run, rooms, scenes, main loop
// =====================================================================

const Scenes = {};
const Game = { scene: null, name: '', error: null };
function setScene(name, arg) {
  Game.scene = Scenes[name]; Game.name = name;
  Input.clearAll();
  if (Game.scene.enter) Game.scene.enter(arg);
}

// ---------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------
function startRun(lanternId, ardor) {
  const seed = (Math.random() * 2 ** 31) >>> 0;
  run = {
    seed, rng: new RNG(seed), depth: 1, ardor: ardor || 0, player: newPlayer(lanternId),
    floor: null, room: null, bullets: [], ebullets: [], enemies: [], fx: [],
    kills: 0, time: 0, dmgDealt: 0, dmgTaken: 0, coinsTotal: 0, pendingLevels: 0, rerollCost: 5,
    offeredRelics: new Set(), oilFx: [], flashLight: null, toasts: [], banners: [], focus: null, pull: null,
    won: false, endless: false, roomsCleared: 0, newUnlocks: [], trans: null, intro: null, bossIntro: null,
    flowT: 0, levelDelay: 0, lockMsgT: 0, deathT: 0, victoryT: 0
  };
  const p = run.player;
  recalcStats();
  const L = LANTERNS.find(l => l.id === lanternId) || LANTERNS[0];
  L.start(p);
  recalcStats();
  p.hp = p.stats.maxHp; p.oil = p.stats.maxOil; p.dashCharges = p.stats.dashCharges;
  p.guardT = 2;
  Save.data.stats.runs++;
  Save.write();
  Particles.clear(); Floaters.clear();
  newFloor();
  setScene('play');
  toast('Find the warden and descend deeper.', '#e8dcc0', 'Press TAB for the map, ESC to pause.');
}

function newFloor() {
  const p = run.player;
  run.floor = genFloor(run.depth, run.rng);
  p.secondwindUsed = false;
  if (p.stats.mapReveal) for (const r of run.floor.rooms) { r.seen = true; if (r.type === 'secret') r.mapped = true; }
  enterRoom(run.floor.start, null);
  run.intro = { t: 0, depth: run.depth };
  const b = biomeOf(run.depth);
  Music.play(b.music); Music.setIntensity(0);
  if (run.depth > Save.data.stats.bestDepth) { Save.data.stats.bestDepth = run.depth; Save.write(); }
  checkUnlocks();
}

function checkUnlocks() {
  for (const L of LANTERNS) {
    if (Save.data.unlocks.lanterns.includes(L.id)) continue;
    if (L.unlock(Save.data.stats)) {
      Save.unlockLantern(L.id);
      if (run) { run.newUnlocks.push(L.name); toast('New lantern unlocked', '#f6cf57', L.name); }
    }
  }
}

function enterRoom(room, fromDir) {
  const p = run.player;
  run.room = room;
  if (!room.built) buildRoom(room, run.floor);
  if (room.bgDirty || !room.bg) renderRoomBg(room, run.floor);
  room.visited = true; room.seen = true;
  for (const d in room.doors) if (doorVisible(room, d)) room.doors[d].seen = true;
  if (fromDir) { const pos = doorEntry(DIRS[fromDir].opp); p.x = pos.x; p.y = pos.y; }
  else { const c = tileCenter(14, 7); p.x = c.x; p.y = c.y + 20; }
  p.dashT = 0;
  run.bullets = []; run.ebullets = []; run.enemies = []; run.fx = []; run.pull = null; run.flow = null; run.flowT = 0;
  run.bossRef = null;
  Particles.clear();
  if (!room.cleared) {
    room.combat = true; room.waveIdx = 0; room.waveDelay = 0.3;
    Sound.play('lock');
    if (room.type === 'boss') {
      const B = BOSSES[room.waves[0][0].boss];
      run.bossIntro = { t: 0, B };
      room.waveDelay = 1.2;
      Sound.play('roar');
      Music.setIntensity(2);
    } else Music.setIntensity(1);
    if (room.type === 'elite') toast('Challenge Hall', '#e0574a', 'Survive the champions for a prize.');
  } else {
    room.combat = false;
    Music.setIntensity(0);
  }
  if (room.type === 'shop' && !room.greeted) { room.greeted = true; Sound.play('coin'); }
  if (room.type === 'secret' && !room.greeted) { room.greeted = true; toast('A forgotten room', '#f6cf57'); }
}

function updateRoomFlow(dt) {
  const room = run.room;
  if (!room.combat) return;
  const pending = run.fx.some(f => f.type === 'spawn');
  if (run.enemies.length === 0 && !pending) {
    room.waveDelay -= dt;
    if (room.waveDelay <= 0) {
      if (room.waveIdx < room.waves.length) {
        spawnWave(room, room.waves[room.waveIdx]);
        room.waveIdx++;
        room.waveDelay = 0.6;
      } else if (room.type !== 'boss') roomCleared(room);
    }
  }
}

function spawnWave(room, wave) {
  const p = run.player;
  if (wave[0].type === 'BOSS') {
    const c = tileCenter(14, 7);
    const y = p.y < c.y ? c.y + 30 : c.y - 30;
    addFx({ type: 'spawn', x: c.x, y, life: 1.0, spec: { type: 'BOSS', boss: wave[0].boss } });
    return;
  }
  const all = reachTiles(room).filter(([x, y]) => room.grid[y][x] === T.FLOOR);
  let tiles = all.filter(([x, y]) => { const c = tileCenter(x, y); return dist(c.x, c.y, p.x, p.y) > 100; });
  if (tiles.length < wave.length) tiles = all.filter(([x, y]) => { const c = tileCenter(x, y); return dist(c.x, c.y, p.x, p.y) > 50; });
  shuffle(tiles);
  wave.forEach((spec, i) => {
    const t = tiles[i % tiles.length];
    const c = tileCenter(t[0], t[1]);
    addFx({ type: 'spawn', x: c.x + rnd(-2, 2), y: c.y + rnd(-2, 2), life: 0.75 + i * 0.05, spec: { type: spec.type, mod: spec.mod } });
  });
  Sound.play('spawn');
}

function roomCleared(room) {
  room.cleared = true; room.combat = false;
  run.roomsCleared++;
  Sound.play('door');
  Music.setIntensity(0);
  const c = tileCenter(14, 7);
  let rx = c.x, ry = c.y;
  if (room.grid[7][14] !== T.FLOOR) { const p = run.player; rx = p.x; ry = p.y - 20; }
  if (room.type === 'elite') {
    room.objects.push({ type: 'chest', gold: true, free: true, x: rx - 20, y: ry });
    const r = randomRelics(1, { shuffle: a => shuffle(a) })[0];
    if (r) room.objects.push({ type: 'relic', id: r, x: rx + 20, y: ry });
    toast('Challenge complete!', '#f6cf57');
    return;
  }
  if (Math.random() < 0.5) {
    const kind = weightedPick([['coins', 30], ['heart', 18], ['oil', 18], ['cons', 14], ['key', 9], ['chest', 11]], k => k[1])[0];
    const pk = run.room.pickups;
    if (kind === 'coins') for (let i = 0; i < rndi(2, 4); i++) pk.push(makePickup('coin', rx, ry));
    else if (kind === 'heart') pk.push(makePickup('heart', rx, ry));
    else if (kind === 'oil') pk.push(makePickup('oil', rx, ry, { value: 30 }));
    else if (kind === 'cons') pk.push(makePickup('cons', rx, ry, { id: randomCons() }));
    else if (kind === 'key') pk.push(makePickup('key', rx, ry));
    else room.objects.push({ type: 'chest', gold: Math.random() < 0.3, x: rx, y: ry });
    Particles.burst(rx, ry, 16, ['#f6cf57', '#fff2a8'], 60, 0.6);
  }
}

function onBossDefeated(e) {
  const room = run.room, p = run.player;
  room.cleared = true; room.combat = false;
  const c = tileCenter(14, 7);
  const finalBoss = e.bid === 'devourer' && !run.won;
  if (!finalBoss) room.objects.push({ type: 'trapdoor', x: c.x, y: c.y + 34 });
  const r = randomRelics(1, { shuffle: a => shuffle(a) })[0];
  if (r) room.objects.push({ type: 'relic', id: r, x: c.x, y: c.y - 16 });
  for (let i = 0; i < 2; i++) room.pickups.push(makePickup('heart', e.x, e.y));
  for (let i = 0; i < 6 + run.depth * 2; i++) room.pickups.push(makePickup(Math.random() < 0.2 ? 'coin5' : 'coin', e.x, e.y));
  for (let i = 0; i < 10; i++) room.pickups.push(makePickup('xp', e.x, e.y, { value: e.xp / 10 }));
  healPlayer(Math.round(p.stats.maxHp * 0.3), true);
  addOil(p.stats.maxOil);
  toast(e.name + ' has fallen', '#f6cf57', 'A trapdoor opens downward.');
  checkUnlocks();
  if (e.bid === 'devourer' && !run.won) {
    run.won = true;
    run.victoryT = 3.2;
  }
}

function descend() {
  if (run.trans) return;
  Sound.play('descend');
  run.trans = { t: 0, kind: 'descend', swapped: false };
}

function checkDoors(dt) {
  const p = run.player, room = run.room;
  run.lockMsgT -= dt;
  for (const d in room.doors) {
    if (!doorVisible(room, d)) continue;
    const dc = doorCenter(d);
    if (doorLocked(room, d)) {
      if (!room.combat && dist(p.x, p.y, dc.x, dc.y) < 26) {
        if (p.keys > 0) { p.keys--; room.doors[d].locked = false; Sound.play('lock'); Sound.play('chest'); toast('You use a key', '#f6cf57'); }
        else if (run.lockMsgT <= 0) { toast('The door is locked', '#8a8294'); run.lockMsgT = 2.5; }
      }
      continue;
    }
    if (!doorOpen(room, d)) continue;
    let go = false;
    if (d === 'n') go = p.y < RY + 11 && Math.abs(p.x - dc.x) < 26;
    else if (d === 's') go = p.y > RY + (RH - 1) * TS + 5 && Math.abs(p.x - dc.x) < 26;
    else if (d === 'w') go = p.x < RX + 11 && Math.abs(p.y - dc.y) < 26;
    else if (d === 'e') go = p.x > RX + (RW - 1) * TS + 5 && Math.abs(p.y - dc.y) < 26;
    if (go) { run.trans = { t: 0, kind: 'room', to: room.doors[d], dir: d, swapped: false }; return; }
  }
}

function updateTrans(dt) {
  const tr = run.trans;
  tr.t += dt;
  const half = tr.kind === 'descend' ? 0.7 : 0.13;
  if (!tr.swapped && tr.t >= half) {
    tr.swapped = true;
    if (tr.kind === 'room') enterRoom(tr.to, tr.dir);
    else { run.depth++; newFloor(); }
  }
  if (tr.t >= half * 2) run.trans = null;
}
function transAlpha() {
  const tr = run.trans;
  if (!tr) return 0;
  const half = tr.kind === 'descend' ? 0.7 : 0.13;
  return tr.t < half ? tr.t / half : Math.max(0, 1 - (tr.t - half) / half);
}

function updateGame(dt) {
  run.time += dt;
  updatePlayer(dt);
  run.flowT -= dt;
  if (run.flowT <= 0) { updateFlow(); run.flowT = 0.18; }
  updateEnemies(dt);
  updateBullets(dt);
  updateEnemyBullets(dt);
  updateFx(dt);
  updatePickups(dt);
  updateRoomFlow(dt);
  run.focus = run.player.dead ? null : nearestObject();
  if (run.focus && Act.interact()) interact(run.focus);
  if (!run.player.dead) checkDoors(dt);
  for (const o of run.oilFx) o.t += dt;
  run.oilFx = run.oilFx.filter(o => o.t < 0.45);
}
function updateCommon(dt) {
  Particles.update(dt);
  Floaters.update(dt);
  updateNotices(dt);
  FX.shake = Math.max(0, FX.shake - dt * 30);
  FX.flash = Math.max(0, FX.flash - dt * 2.5);
  if (run.flashLight) { run.flashLight.t -= dt; if (run.flashLight.t <= 0) run.flashLight = null; }
  if (run.intro) { run.intro.t += dt; if (run.intro.t > 4.5) run.intro = null; }
  if (run.bossIntro) { run.bossIntro.t += dt; if (run.bossIntro.t > 2.8) run.bossIntro = null; }
}

// ---------------------------------------------------------------------
// Game scene
// ---------------------------------------------------------------------
Scenes.play = {
  mode: 'play',
  enter(arg) {
    this.mode = 'play';
    this.lock = 0;
    this.buildHover = -1;
    if (arg === 'continue') { run.victoryT = 0; Music.play(biomeOf(run.depth).music); }
  },
  openLevelUp() {
    const p = run.player;
    this.choices = run.forcedChoices || rollPerkChoices(3 + p.stats.extraChoice, 0);
    run.forcedChoices = null;
    if (!this.choices.length) {
      run.pendingLevels = Math.max(0, run.pendingLevels - 1);
      addCoins(10); toast('You already have everything. Take some coins.', '#f6cf57');
      return;
    }
    this.mode = 'levelup'; this.sel = 0; this.lock = 0.45; this.cardRects = [];
    Sound.play('levelup');
  },
  choosePerk(id) {
    const p = run.player;
    p.perks[id] = (p.perks[id] || 0) + 1;
    recalcStats();
    if (PERKS[id].onTake) PERKS[id].onTake(p);
    run.pendingLevels = Math.max(0, run.pendingLevels - 1);
    Sound.play('confirm');
    toast(PERKS[id].name, RARITY[PERKS[id].rar].col);
    this.mode = 'play';
    run.levelDelay = 0.35;
    p.fireCd = 0.25;
    Input.clearAll();
  },
  openPause() {
    this.mode = 'pause';
    this.confirmQuit = false;
    this.pauseMenu = new Menu([
      { label: 'Resume', action: () => { this.mode = 'play'; } },
      { label: 'Equipment', action: () => { this.mode = 'build'; this.buildSel = 0; } },
      { label: 'Map', action: () => { this.mode = 'map'; this.mapFrom = 'pause'; } },
      { label: 'Options', action: () => { this.mode = 'options'; this.optMenu = makeOptionsMenu(() => { this.mode = 'pause'; }); } },
      { label: () => this.confirmQuit ? 'Sure? The descent will be lost' : 'Abandon the descent', action: () => {
        if (!this.confirmQuit) { this.confirmQuit = true; return; }
        run.player.lastHit = 'Surrender'; run.abandoned = true; setScene('gameover');
      } },
    ]);
  },
  update(dt) {
    switch (this.mode) {
      case 'play': return this.updatePlay(dt);
      case 'levelup': return this.updateLevelUp(dt);
      case 'pause':
        if (Act.pause() || Act.back()) { this.mode = 'play'; return; }
        this.pauseMenu.update();
        return;
      case 'build': {
        const n = buildEntries().length;
        if (Act.back() || Act.pause() || Act.confirm()) { this.mode = 'pause'; return; }
        if (n) {
          if (Act.right()) this.buildSel = (this.buildSel + 1) % n;
          if (Act.left()) this.buildSel = (this.buildSel - 1 + n) % n;
          if (Act.down()) this.buildSel = Math.min(n - 1, this.buildSel + 10);
          if (Act.up()) this.buildSel = Math.max(0, this.buildSel - 10);
        }
        return;
      }
      case 'map':
        if (Act.map() || Act.pause() || Act.back() || Act.confirm() || Input.mLp) this.mode = this.mapFrom === 'pause' ? 'pause' : 'play';
        return;
      case 'options':
        if (Act.back() || Act.pause()) { this.mode = 'pause'; return; }
        this.optMenu.update();
        return;
    }
  },
  updatePlay(dt) {
    if (Act.pause() && !run.player.dead) { this.openPause(); return; }
    if (Act.map() && !run.player.dead) { this.mode = 'map'; this.mapFrom = 'play'; return; }
    updateCommon(dt);
    if (run.trans) { updateTrans(dt); return; }
    if (FX.hitstop > 0) { FX.hitstop -= dt; return; }
    if (run.player.dead) {
      run.deathT += dt;
      updateGame(dt * 0.25);
      if (run.deathT > 2.4) setScene('gameover');
      return;
    }
    if (run.lockFire && !Input.mL) run.lockFire = false;
    updateGame(dt);
    if (run.victoryT > 0) {
      run.victoryT -= dt;
      if (run.victoryT <= 0) { run.victoryT = 0; setScene('victory'); return; }
    }
    if (run.pendingLevels > 0 && !run.room.combat && !run.trans) {
      run.levelDelay -= dt;
      if (run.levelDelay <= 0) this.openLevelUp();
    } else if (run.room.combat) run.levelDelay = 0.7;
  },
  updateLevelUp(dt) {
    this.lock -= dt;
    const n = this.choices.length;
    if (Act.left()) { this.sel = (this.sel - 1 + n) % n; Sound.play('select'); }
    if (Act.right()) { this.sel = (this.sel + 1) % n; Sound.play('select'); }
    for (const r of this.cardRects || []) {
      const i = this.cardRects.indexOf(r);
      if (Input.mx >= r.x && Input.mx < r.x + r.w && Input.my >= r.y && Input.my < r.y + r.h) {
        if (this.sel !== i && performance.now() - Input.mouseMovedAt < 100) { this.sel = i; Sound.play('select'); }
        if (Input.mLp && this.lock <= 0) { this.choosePerk(this.choices[i]); run.lockFire = true; return; }
      }
    }
    if (this.lock > 0) return;
    for (let i = 0; i < n; i++) if (Input.hit('Digit' + (i + 1))) { this.choosePerk(this.choices[i]); return; }
    if (Act.confirm()) { this.choosePerk(this.choices[this.sel]); return; }
    // rematch
    const rr = this.rerollRect;
    const clicked = rr && Input.mLp && Input.mx >= rr.x && Input.mx < rr.x + rr.w && Input.my >= rr.y && Input.my < rr.y + rr.h;
    if (Input.hit('KeyR') || Input.btnHit(3) || clicked) {
      const p = run.player;
      if (p.coins >= run.rerollCost) {
        p.coins -= run.rerollCost; run.rerollCost += 3;
        this.choices = rollPerkChoices(3 + p.stats.extraChoice, 0);
        this.sel = 0; Sound.play('coin'); this.lock = 0.2;
      } else Sound.play('deny');
    }
  },
  draw(ctx) {
    drawWorld(ctx);
    // oil embers flying back to the lantern
    const p = run.player;
    for (const o of run.oilFx) {
      const k = o.t / 0.45;
      const x = lerp(o.x, p.x, k * k), y = lerp(o.y, p.y - 2, k * k) - Math.sin(k * Math.PI) * 14;
      pxRect(ctx, x - 1, y - 1, 2, 2, '#f29c38'); pxRect(ctx, x, y, 1, 1, '#fff2a8');
    }
    if (FX.flash > 0) { ctx.save(); ctx.globalAlpha = Math.min(0.6, FX.flash); pxRect(ctx, 0, 0, W, H, FX.flashCol); ctx.restore(); }
    // red border at low health
    if (p.hp / p.stats.maxHp < 0.3 && !p.dead) {
      ctx.save(); ctx.globalAlpha = 0.18 + 0.1 * Math.sin(Render.time * 5);
      const g = ctx.createRadialGradient(W / 2, H / 2, H * 0.3, W / 2, H / 2, H * 0.8);
      g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, '#a01818');
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); ctx.restore();
    }
    drawHUD(ctx);
    drawNotices(ctx);
    this.drawIntro(ctx);
    // crosshair
    if (this.mode === 'play' && Input.lastDevice === 'mouse' && !p.dead) {
      const mx = Math.round(Input.mx), my = Math.round(Input.my);
      const c = Input.mL ? '#f6cf57' : '#e8dcc0';
      for (const [dx, dy, w, h] of [[-5, 0, 3, 1], [3, 0, 3, 1], [0, -5, 1, 3], [0, 3, 1, 3]]) {
        pxRect(ctx, mx + dx + 1, my + dy + 1, w, h, '#0b0810');
        pxRect(ctx, mx + dx, my + dy, w, h, c);
      }
      pxRect(ctx, mx, my, 1, 1, '#f29c38');
    }
    if (run.trans) { ctx.save(); ctx.globalAlpha = transAlpha(); pxRect(ctx, 0, 0, W, H, '#000000'); ctx.restore(); }
    if (p.dead) {
      const a = Math.min(1, run.deathT / 2);
      ctx.save(); ctx.globalAlpha = a * 0.7; pxRect(ctx, 0, 0, W, H, '#000000'); ctx.restore();
      Font.draw(ctx, 'Your light is going out...', W / 2, H / 2 - 6, { align: 'center', color: '#e0574a', scale: 2, alpha: a });
    }
    switch (this.mode) {
      case 'levelup': {
        const more = run.pendingLevels > 1 ? '   (' + (run.pendingLevels - 1) + ' pending)' : '';
        this.cardRects = drawPerkCards(ctx, this.choices, this.sel, 'A new spark', 'Level ' + run.player.level + '  -  choose a perk' + more);
        const can = run.player.coins >= run.rerollCost;
        const label = 'Reroll  (' + run.rerollCost + ' coins)';
        const w = Font.width(label) + 30, x = W / 2 - w / 2, y = 236;
        panel(ctx, x, y, w, 18, { alpha: 0.9 });
        const kw = keycap(ctx, x + 6, y + 5, Input.lastDevice === 'pad' ? 'Y' : 'R');
        Font.draw(ctx, label, x + 10 + kw, y + 6, { color: can ? '#e8dcc0' : '#55505e' });
        this.rerollRect = { x, y, w, h: 18 };
        break;
      }
      case 'pause': this.drawPause(ctx); break;
      case 'build': this.drawPause(ctx, true); break;
      case 'map': drawFullMap(ctx); break;
      case 'options':
        ctx.save(); ctx.globalAlpha = 0.8; pxRect(ctx, 0, 0, W, H, '#050308'); ctx.restore();
        panel(ctx, W / 2 - 130, 50, 260, 170);
        Font.draw(ctx, 'Options', W / 2, 62, { align: 'center', color: '#f6cf57', scale: 2 });
        this.optMenu.draw(ctx, W / 2, 96, { lineH: 16 });
        break;
    }
  },
  drawPause(ctx, buildMode) {
    ctx.save(); ctx.globalAlpha = 0.78; pxRect(ctx, 0, 0, W, H, '#050308'); ctx.restore();
    Font.draw(ctx, 'Paused', 90, 40, { align: 'center', color: '#f6cf57', scale: 2 });
    if (!buildMode) this.pauseMenu.draw(ctx, 90, 76, { lineH: 16 });
    else Font.draw(ctx, '^dArrows to scroll, ENTER to go back', 90, 76, { align: 'center' });
    Font.draw(ctx, 'Seed ' + run.seed + '  -  ' + VERSION, 90, 240, { align: 'center', color: '#3b3546' });
    if (run.ardor) Font.draw(ctx, 'Ardor ' + run.ardor, 90, 228, { align: 'center', color: '#e0574a' });
    // equipment panel
    let hover = buildMode ? this.buildSel : -1;
    const rects = this.buildRects || [];
    rects.forEach((r, i) => { if (Input.mx >= r.x && Input.mx < r.x + r.w && Input.my >= r.y && Input.my < r.y + r.h) hover = i; });
    this.buildRects = drawBuildPanel(ctx, 186, 30, 166, 226, hover);
    drawStatsPanel(ctx, 358, 30, 116, 142);
    // summary
    panel(ctx, 358, 178, 116, 78);
    const rows = [['Kills', run.kills], ['Rooms', run.roomsCleared], ['Time', fmtTime(run.time)], ['Coins', run.coinsTotal], ['Damage', Math.round(run.dmgDealt)]];
    rows.forEach(([k, v], i) => { Font.draw(ctx, k, 366, 187 + i * 12, { color: '#8a8294' }); Font.draw(ctx, String(v), 466, 187 + i * 12, { align: 'right', color: '#e8dcc0' }); });
  },
  drawIntro(ctx) {
    const it = run.intro;
    if (it && it.t < 4.5) {
      const a = it.t < 0.6 ? it.t / 0.6 : it.t > 3.5 ? Math.max(0, 1 - (it.t - 3.5)) : 1;
      const b = biomeOf(it.depth);
      ctx.save(); ctx.globalAlpha = a * 0.6; pxRect(ctx, 0, 92, W, 70, '#050308'); ctx.restore();
      Font.draw(ctx, 'Depth ' + it.depth, W / 2, 98, { align: 'center', color: '#8a8294', alpha: a });
      Font.draw(ctx, b.name, W / 2, 112, { align: 'center', color: '#f6cf57', scale: 2, alpha: a });
      Font.wrap(b.lore, 360).forEach((l, i) => Font.draw(ctx, l, W / 2, 136 + i * 10, { align: 'center', color: '#c8c0d0', alpha: a }));
    }
    const bi = run.bossIntro;
    if (bi) {
      const a = bi.t < 0.4 ? bi.t / 0.4 : bi.t > 2.2 ? Math.max(0, 1 - (bi.t - 2.2) / 0.6) : 1;
      const bh = 22 * a;
      pxRect(ctx, 0, 28, W, bh, '#000000'); pxRect(ctx, 0, H - bh, W, bh, '#000000');
      Font.draw(ctx, bi.B.name, W / 2, 104, { align: 'center', color: '#e0574a', scale: 2, alpha: a });
      Font.draw(ctx, bi.B.title, W / 2, 126, { align: 'center', color: '#c8c0d0', alpha: a });
    }
  }
};

// ---------------------------------------------------------------------
// Options (reused by title and pause)
// ---------------------------------------------------------------------
function makeOptionsMenu(onBack) {
  const s = Save.data.settings;
  const vol = v => { const n = Math.round(v * 10); return '[' + '#'.repeat(n) + '-'.repeat(10 - n) + ']'; };
  return new Menu([
    { label: 'Music', value: () => vol(s.music), adjust: d => { s.music = clamp(Math.round(s.music * 10 + d) / 10, 0, 1); Sound.applyVolumes(); Save.write(); }, action: () => { } },
    { label: 'Effects', value: () => vol(s.sfx), adjust: d => { s.sfx = clamp(Math.round(s.sfx * 10 + d) / 10, 0, 1); Sound.applyVolumes(); Save.write(); Sound.play('coin'); }, action: () => { } },
    { label: 'Screen shake', value: () => s.shake ? 'Sì' : 'No', adjust: () => { s.shake = !s.shake; Save.write(); }, action: () => { s.shake = !s.shake; Save.write(); } },
    { label: 'Damage numbers', value: () => s.numbers ? 'Sì' : 'No', adjust: () => { s.numbers = !s.numbers; Save.write(); }, action: () => { s.numbers = !s.numbers; Save.write(); } },
    { label: 'Fullscreen', action: () => {
      try {
        const pr = !document.fullscreenElement ? document.documentElement.requestFullscreen() : document.exitFullscreen();
        if (pr && pr.catch) pr.catch(() => { });
      } catch (e) { }
    } },
    { label: 'Back', action: onBack },
  ]);
}

// ---------------------------------------------------------------------
// Title
// ---------------------------------------------------------------------
function drawWellBackground(ctx, t, embers) {
  const g = ctx.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, '#0a0710'); g.addColorStop(0.6, '#120c18'); g.addColorStop(1, '#1e1018');
  ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
  // well walls in perspective
  for (let i = 0; i < 14; i++) {
    const k = ((i + t * 0.25) % 14) / 14;
    const y = H * (0.05 + k * k * 1.1);
    const inset = 40 + (1 - k) * 120;
    ctx.fillStyle = 'rgba(70,50,80,' + (0.08 + k * 0.18).toFixed(3) + ')';
    ctx.fillRect(0, y, inset * 0.6, 2 + k * 3);
    ctx.fillRect(W - inset * 0.6, y, inset * 0.6, 2 + k * 3);
  }
  const vg = ctx.createRadialGradient(W / 2, H * 0.95, 10, W / 2, H * 0.95, 200);
  vg.addColorStop(0, 'rgba(242,156,56,0.18)'); vg.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = vg; ctx.fillRect(0, 0, W, H);
  for (const e of embers) {
    ctx.globalAlpha = Math.min(1, e.life * 2);
    pxRect(ctx, e.x, e.y, e.s, e.s, e.c);
  }
  ctx.globalAlpha = 1;
}
function updateEmbers(arr, dt) {
  if (arr.length < 70 && Math.random() < 0.5) arr.push({ x: rnd(W), y: H + 4, vy: -rnd(8, 30), vx: rnd(-6, 6), life: rnd(3, 8), s: chance(0.25) ? 2 : 1, c: pick(['#f29c38', '#f6cf57', '#b5571f', '#6b6478']) });
  for (const e of arr) { e.x += (e.vx + Math.sin(e.y * 0.05) * 6) * dt; e.y += e.vy * dt; e.life -= dt; }
  for (let i = arr.length - 1; i >= 0; i--) if (arr[i].life <= 0 || arr[i].y < -5) arr.splice(i, 1);
}

Scenes.title = {
  enter() {
    this.t = 0;
    this.embers = this.embers || [];
    this.menu = new Menu([
      { label: 'New descent', action: () => setScene('select') },
      { label: 'How to play', action: () => setScene('help') },
      { label: 'Archive', action: () => setScene('records') },
      { label: 'Options', action: () => setScene('options') },
    ]);
    Music.play('title'); Music.setIntensity(0);
    run = null;
  },
  update(dt) { this.t += dt; updateEmbers(this.embers, dt); this.menu.update(); },
  draw(ctx) {
    drawWellBackground(ctx, this.t, this.embers);
    drawBigLantern(ctx, W / 2, 46, '#f6cf57', Math.sin(this.t * 1.3) * 0.12, 3);
    Font.draw(ctx, 'LAST', W / 2, 92, { align: 'center', color: '#c8a050', scale: 3, shadowColor: '#2a1408' });
    Font.draw(ctx, 'LANTERN', W / 2, 118, { align: 'center', color: '#f6cf57', scale: 4, shadowColor: '#2a1408' });
    Font.draw(ctx, 'a descent into the sunless well', W / 2, 154, { align: 'center', color: '#8a8294' });
    this.menu.draw(ctx, W / 2, 178, { lineH: 15 });
    const st = Save.data.stats;
    if (st.runs > 0) Font.draw(ctx, 'Descents: ' + st.runs + '   Deepest depth: ' + st.bestDepth + '   Flames rekindled: ' + st.wins, W / 2, 248, { align: 'center', color: '#55505e' });
    Font.draw(ctx, 'Keyboard and mouse or gamepad', W / 2, 259, { align: 'center', color: '#3b3546' });
    Font.draw(ctx, VERSION, W - 5, 259, { align: 'right', color: '#3b3546' });
    if (!Sound.unlocked) Font.draw(ctx, 'Press any key to enable audio', W - 6, 4, { align: 'right', color: '#55505e' });
  }
};

Scenes.options = {
  enter() { this.menu = makeOptionsMenu(() => setScene('title')); this.embers = Scenes.title.embers; this.t = 0; },
  update(dt) { this.t += dt; updateEmbers(this.embers, dt); if (Act.back()) { setScene('title'); return; } this.menu.update(); },
  draw(ctx) {
    drawWellBackground(ctx, this.t, this.embers);
    panel(ctx, W / 2 - 130, 50, 260, 170);
    Font.draw(ctx, 'Options', W / 2, 62, { align: 'center', color: '#f6cf57', scale: 2 });
    this.menu.draw(ctx, W / 2, 96, { lineH: 16 });
  }
};

// ---------------------------------------------------------------------
// Lantern selection
// ---------------------------------------------------------------------
Scenes.select = {
  enter() {
    this.t = 0;
    this.embers = Scenes.title.embers;
    const un = Save.data.unlocks;
    this.ard = Math.min(un.ardor, this.ard || 0);
    const items = LANTERNS.map(L => ({
      label: un.lanterns.includes(L.id) ? L.name : 'Sealed lantern', L,
      disabled: !un.lanterns.includes(L.id),
      action: () => startRun(L.id, this.ard)
    }));
    if (un.ardor > 0) items.push({ label: 'Ardor', value: () => String(this.ard), adjust: d => { this.ard = clamp(this.ard + d, 0, un.ardor); }, action: () => { this.ard = (this.ard + 1) % (un.ardor + 1); } });
    items.push({ label: 'Back', action: () => setScene('title') });
    this.menu = new Menu(items, { allowDisabled: true });
  },
  update(dt) { this.t += dt; updateEmbers(this.embers, dt); if (Act.back()) { setScene('title'); return; } this.menu.update(); },
  draw(ctx) {
    drawWellBackground(ctx, this.t, this.embers);
    Font.draw(ctx, 'Choose your lantern', W / 2, 16, { align: 'center', color: '#f6cf57', scale: 2 });
    panel(ctx, 20, 44, 190, 200);
    this.menu.draw(ctx, 40, 58, { lineH: 16, align: 'left' });
    const it = this.menu.current();
    panel(ctx, 222, 44, 238, 200);
    if (it.L) {
      const L = it.L, locked = it.disabled;
      drawBigLantern(ctx, 341, 92, locked ? '#3b3546' : L.glass, Math.sin(this.t * 1.5) * 0.1, 3);
      Font.draw(ctx, locked ? '???' : L.name, 341, 140, { align: 'center', color: locked ? '#55505e' : '#f6cf57' });
      if (locked) Font.drawWrapped(ctx, '^dTo unlock: ^w' + L.unlockText, 232, 160, 218, {});
      else Font.drawWrapped(ctx, L.desc, 232, 160, 218, { color: '#d8d0c0' });
    } else if (it.label === 'Ardor') {
      Font.draw(ctx, 'Ardor ' + this.ard, 341, 70, { align: 'center', color: '#e0574a', scale: 2 });
      Font.drawWrapped(ctx, 'Each level of Ardor makes the descent crueler. Unlocked by rekindling the First Flame.', 232, 100, 218, { color: '#a8a0b0' });
      for (let i = 1; i <= this.ard; i++) Font.draw(ctx, ARDOR[i], 232, 140 + (i - 1) * 11, {});
      if (this.ard === 0) Font.draw(ctx, ARDOR[0], 232, 140, { color: '#8a8294' });
    } else {
      Font.drawWrapped(ctx, 'Each lantern changes how you face the dark. New lanterns unlock by descending deeper.', 232, 90, 218, { color: '#a8a0b0' });
    }
    Font.draw(ctx, 'ENTER or click to start   -   ESC to go back', W / 2, 252, { align: 'center', color: '#55505e' });
  }
};

// ---------------------------------------------------------------------
// Archive and guide
// ---------------------------------------------------------------------
Scenes.records = {
  enter() { this.t = 0; this.embers = Scenes.title.embers; },
  update(dt) { this.t += dt; updateEmbers(this.embers, dt); if (Act.back() || Act.confirm() || Input.mLp) setScene('title'); },
  draw(ctx) {
    drawWellBackground(ctx, this.t, this.embers);
    panel(ctx, W / 2 - 150, 30, 300, 210);
    Font.draw(ctx, 'Archive', W / 2, 42, { align: 'center', color: '#f6cf57', scale: 2 });
    const st = Save.data.stats, un = Save.data.unlocks;
    const rows = [
      ['Descents attempted', st.runs], ['Flames rekindled', st.wins], ['Deepest depth', st.bestDepth],
      ['Enemies defeated', st.kills], ['Wardens slain', st.bossKills],
      ['Fastest descent', st.bestTime ? fmtTime(st.bestTime) : '-'], ['Ardor unlocked', un.ardor],
      ['Lanterns', un.lanterns.length + ' / ' + LANTERNS.length],
    ];
    rows.forEach(([k, v], i) => {
      Font.draw(ctx, k, W / 2 - 130, 72 + i * 14, { color: '#a8a0b0' });
      Font.draw(ctx, String(v), W / 2 + 130, 72 + i * 14, { align: 'right', color: '#e8dcc0' });
    });
    LANTERNS.forEach((L, i) => {
      const ok = un.lanterns.includes(L.id);
      const x = W / 2 - 100 + i * 50;
      pxRect(ctx, x - 1, 192, 12, 16, '#0b0810');
      pxRect(ctx, x + 1, 195, 8, 10, ok ? L.glass : '#2a2430');
    });
    Font.draw(ctx, 'Press any key to go back', W / 2, 224, { align: 'center', color: '#55505e' });
  }
};

Scenes.help = {
  enter() { this.page = 0; this.t = 0; this.embers = Scenes.title.embers; },
  update(dt) {
    this.t += dt; updateEmbers(this.embers, dt);
    if (Act.back()) { setScene('title'); return; }
    if (Act.right() || Act.confirm() || Input.mLp) { this.page++; Sound.play('select'); if (this.page > 2) setScene('title'); }
    if (Act.left() && this.page > 0) { this.page--; Sound.play('select'); }
  },
  draw(ctx) {
    drawWellBackground(ctx, this.t, this.embers);
    panel(ctx, 24, 14, W - 48, H - 28);
    const titles = ['Controls', 'The descent', 'Status effects'];
    Font.draw(ctx, titles[this.page], W / 2, 24, { align: 'center', color: '#f6cf57', scale: 2 });
    const x = 44;
    if (this.page === 0) {
      const rows = [
        [['W', 'A', 'S', 'D'], 'Move'], [['Mouse'], 'Aim  (or the arrow keys)'], [['Left click'], 'Shoot  (or hold the arrow keys)'],
        [['Space'], 'Dash: pass through attacks unharmed'], [['Right click', 'F'], 'Flare: wave of fire, uses oil'],
        [['1', '2', '3', '4'], 'Use a consumable'], [['E'], 'Interact: chests, relics, merchant'], [['Tab', 'M'], 'Depth map'], [['Esc', 'P'], 'Pause and equipment'],
      ];
      rows.forEach(([keys, txt], i) => {
        let kx = x;
        for (const k of keys) kx += keycap(ctx, kx, 50 + i * 18, k) + 3;
        Font.draw(ctx, txt, x + 110, 51 + i * 18, { color: '#d8d0c0' });
      });
      Font.drawWrapped(ctx, '^dGamepad: left stick to move, right stick to aim and shoot, A dash, B Flare, X interact, d-pad for consumables.', x, 216, W - 90, {});
    } else if (this.page === 1) {
      const txt = [
        '^yThe lantern is your life.^w During fights the oil burns and your light shrinks. Every enemy killed gives back a little oil. Without oil the dark hurts you: you take ^r+25%^w damage.',
        '^yThe Flare^w burns and pushes back everything around you and cancels nearby projectiles. It costs oil: use it wisely.',
        '^yPerks^w come from leveling up and are chosen once the room is safe. ^yRelics^w are found in treasures, from merchants, in secrets and from wardens. Some carry ^pcurses^w.',
        '^yBombs^w open secret passages: look for cracks in the walls. Every depth has a ^rwarden^w: defeat it and go down the trapdoor. There are five depths down to the Heart of the Well.',
      ];
      let y = 46;
      for (const t of txt) y += Font.drawWrapped(ctx, t, x, y, W - 90, { color: '#d8d0c0' }) + 6;
    } else {
      const ks = Object.keys(STATUS);
      const desc = {
        burn: 'Damage over time for a few seconds.', poison: 'Damage over time that stacks with every hit.', chill: 'Slows. Three stacks freeze enemies.',
        slow: 'You move more slowly.', weak: 'You deal 30% less damage.', fragile: 'You take 30% more damage.', blind: 'Your light shrinks drastically.',
        rage: 'Damage and fire rate increased.', immune: 'No debuff can affect you.', invis: 'Enemies lose your trail.', fury: 'Fire rate increased after every kill.'
      };
      ks.forEach((k, i) => {
        const y = 46 + i * 16;
        pxRect(ctx, x, y - 2, 11, 12, '#0b0810');
        drawSpr(ctx, STATUS[k].icon, 0, x + 5.5, y + 4);
        Font.draw(ctx, STATUS[k].name, x + 18, y, { color: STATUS[k].col });
        Font.draw(ctx, desc[k] || '', x + 110, y, { color: '#d8d0c0' });
      });
    }
    Font.draw(ctx, (this.page + 1) + ' / 3   -   arrows to flip pages, ESC to exit', W / 2, H - 26, { align: 'center', color: '#55505e' });
  }
};

// ---------------------------------------------------------------------
// End of the descent
// ---------------------------------------------------------------------
function runSummaryRows() {
  return [
    ['Depth reached', run.depth], ['Level', run.player.level], ['Enemies defeated', run.kills],
    ['Rooms cleared', run.roomsCleared], ['Coins collected', run.coinsTotal], ['Time', fmtTime(run.time)],
  ];
}
function drawSummary(ctx, x, y) {
  runSummaryRows().forEach(([k, v], i) => {
    Font.draw(ctx, k, x, y + i * 12, { color: '#a8a0b0' });
    Font.draw(ctx, String(v), x + 170, y + i * 12, { align: 'right', color: '#e8dcc0' });
  });
}
function drawIconsRow(ctx, x, y, maxW) {
  const ents = buildEntries();
  ents.slice(0, Math.floor(maxW / 20) * 3).forEach((e, i) => {
    const cols = Math.floor(maxW / 20);
    const cx = x + (i % cols) * 20, cy = y + Math.floor(i / cols) * 20;
    pxRect(ctx, cx, cy, 18, 18, '#0b0810');
    pxRect(ctx, cx + 1, cy + 1, 16, 16, e.kind === 'curse' ? '#1a0d22' : '#1a141f');
    drawSpr(ctx, e.icon, 0, cx + 9, cy + 9);
  });
}

Scenes.gameover = {
  enter() {
    this.t = 0;
    const st = Save.data.stats;
    st.kills += run.kills;
    Save.write();
    checkUnlocks();
    Music.play('title'); Music.setIntensity(0);
    this.menu = new Menu([
      { label: 'New descent', action: () => setScene('select') },
      { label: 'Main menu', action: () => setScene('title') },
    ]);
    this.embers = Scenes.title.embers;
  },
  update(dt) { this.t += dt; updateEmbers(this.embers, dt); if (this.t > 0.8) this.menu.update(); },
  draw(ctx) {
    drawWellBackground(ctx, this.t, this.embers);
    const a = Math.min(1, this.t / 0.8);
    ctx.save(); ctx.globalAlpha = a;
    Font.draw(ctx, run.abandoned ? 'You left the Well' : 'Your light has gone out', W / 2, 18, { align: 'center', color: '#e0574a', scale: 2 });
    Font.draw(ctx, (run.abandoned ? '' : 'Killed by: ') + (run.abandoned ? 'The dark will await your return.' : (run.player.lastHit || 'The dark')), W / 2, 40, { align: 'center', color: '#a8a0b0' });
    panel(ctx, 30, 56, 200, 100);
    drawSummary(ctx, 44, 66);
    panel(ctx, 240, 56, 210, 100);
    Font.draw(ctx, 'What you carried', 345, 63, { align: 'center', color: '#e8dcc0' });
    drawIconsRow(ctx, 250, 76, 190);
    if (run.newUnlocks.length) Font.draw(ctx, 'Unlocked: ' + run.newUnlocks.join(', '), W / 2, 164, { align: 'center', color: '#f6cf57' });
    this.menu.draw(ctx, W / 2, 190, { lineH: 16 });
    Font.draw(ctx, 'Seed ' + run.seed + '  -  Ardor ' + run.ardor + '  -  ' + VERSION, W / 2, 252, { align: 'center', color: '#3b3546' });
    ctx.restore();
  }
};

Scenes.victory = {
  enter() {
    this.t = 0;
    const st = Save.data.stats, un = Save.data.unlocks;
    if (!run.winRecorded) {
      run.winRecorded = true;
      st.wins++;
      if (!st.bestTime || run.time < st.bestTime) st.bestTime = Math.round(run.time);
      st.maxArdorWon = Math.max(st.maxArdorWon, run.ardor);
      const before = un.ardor;
      un.ardor = Math.min(5, Math.max(un.ardor, run.ardor + 1));
      if (un.ardor > before) run.newUnlocks.push('Ardor ' + un.ardor);
      Save.write();
      checkUnlocks();
    }
    Music.play('title');
    this.menu = new Menu([
      { label: 'Continue into the Infinite Abyss', action: () => {
        run.endless = true;
        const c = tileCenter(14, 7);
        if (!run.room.objects.some(o => o.type === 'trapdoor')) run.room.objects.push({ type: 'trapdoor', x: c.x, y: c.y + 34 });
        setScene('play', 'continue');
      } },
      { label: 'Return to the surface', action: () => { Save.data.stats.kills += run.kills; Save.write(); setScene('title'); } },
    ]);
    this.embers = Scenes.title.embers;
  },
  update(dt) { this.t += dt; updateEmbers(this.embers, dt); if (this.t > 1.2) this.menu.update(); },
  draw(ctx) {
    drawWellBackground(ctx, this.t, this.embers);
    const glowA = Math.min(1, this.t / 2);
    const g = ctx.createRadialGradient(W / 2, 60, 5, W / 2, 60, 260);
    g.addColorStop(0, 'rgba(255,220,140,' + (0.35 * glowA) + ')'); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    drawBigLantern(ctx, W / 2, 34, '#fff2a8', Math.sin(this.t) * 0.06, 2);
    Font.draw(ctx, 'The First Flame burns again', W / 2, 62, { align: 'center', color: '#f6cf57', scale: 2 });
    Font.draw(ctx, 'The sun will rise again. The Well, however, is still hungry.', W / 2, 84, { align: 'center', color: '#c8c0d0' });
    panel(ctx, 30, 98, 200, 84);
    drawSummary(ctx, 44, 107);
    panel(ctx, 240, 98, 210, 84);
    drawIconsRow(ctx, 250, 106, 190);
    if (run.newUnlocks.length) Font.draw(ctx, 'Unlocked: ' + run.newUnlocks.join(', '), W / 2, 190, { align: 'center', color: '#f6cf57' });
    this.menu.draw(ctx, W / 2, 210, { lineH: 16 });
  }
};

// ---------------------------------------------------------------------
// Startup and main loop
// ---------------------------------------------------------------------
const DT = 1 / 60;
let acc = 0, lastT = 0;
function frame(now) {
  requestAnimationFrame(frame);
  if (!lastT) lastT = now;
  let dt = (now - lastT) / 1000;
  lastT = now;
  if (dt > 0.1) dt = 0.1;
  acc += dt;
  let steps = 0;
  Render.time = now / 1000;
  try {
    Input.pollPad();
    while (acc >= DT && steps < 6) {
      Game.scene.update(DT);
      acc -= DT; steps++;
      if (steps === 1) Input.endFrame();
    }
    const ctx = Gfx.ctx;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    pxRect(ctx, 0, 0, W, H, '#050308');
    Game.scene.draw(ctx);
    const hideCursor = Game.name === 'play' && Scenes.play.mode === 'play';
    if (Gfx.canvas.style.cursor !== (hideCursor ? 'none' : 'default')) Gfx.canvas.style.cursor = hideCursor ? 'none' : 'default';
  } catch (e) {
    if (!Game.error) { Game.error = e; console.error(e); }
  }
  if (Game.error) {
    const ctx = Gfx.ctx;
    pxRect(ctx, 0, H - 32, W, 32, '#300810');
    Font.draw(ctx, 'Error: ' + String(Game.error.message || Game.error).slice(0, 70), 4, H - 29, { color: '#ff8080' });
    Font.draw(ctx, 'Take a screenshot and send it along with the feedback form. ' + VERSION + (run ? '  seed ' + run.seed : ''), 4, H - 16, { color: '#e8c0c0' });
  }
}

function boot() {
  Save.load();
  Font.init();
  Gfx.init();
  buildSprites();
  initRender();
  Input.init(Gfx.canvas);
  const q = new URLSearchParams(location.search);
  setScene('title');
  // test parameters (development)
  if (q.has('test')) devStart(q);
  // auto-pause when the window loses focus
  addEventListener('blur', () => {
    if (Game.name === 'play' && Scenes.play.mode === 'play' && run && !run.player.dead && !run.victoryT) Scenes.play.openPause();
  });
  requestAnimationFrame(frame);
}

function devStart(q) {
  const mode = q.get('test');
  startRun(q.get('lantern') || 'warden', +(q.get('ardor') || 0));
  const depth = +(q.get('depth') || 1);
  if (depth > 1) { run.depth = depth; newFloor(); }
  if (mode === 'boss' || mode === 'shop' || mode === 'treasure' || mode === 'elite') {
    const r = run.floor.rooms.find(x => x.type === mode);
    if (r) { r.seen = true; enterRoom(r, null); const c = tileCenter(14, 12); run.player.x = c.x; run.player.y = c.y; }
  } else if (mode === 'fight') {
    const r = run.floor.rooms.find(x => x.type === 'normal');
    if (r) enterRoom(r, Object.keys(r.doors)[0]);
  }
  if (q.has('perks')) for (const id of q.get('perks').split(',')) if (PERKS[id]) run.player.perks[id] = (run.player.perks[id] || 0) + 1;
  if (q.has('relics')) for (const id of q.get('relics').split(',')) if (RELICS[id]) run.player.relics.push(id);
  recalcStats();
  run.intro = null;
  if (q.has('lv')) run.pendingLevels = +q.get('lv');
  if (q.has('coins')) run.player.coins = +q.get('coins');
  const sim = +(q.get('sim') || 0);
  for (let i = 0; i < sim; i++) {
    if (q.has('fire')) {
      const e = run.enemies[0];
      Input.mL = !!e; Input.lastDevice = 'mouse';
      if (e) { Input.mx = e.x; Input.my = e.y; }
    }
    Game.scene.update(DT);
    Input.endFrame();
  }
  Input.mL = false;
  if (q.has('pause')) Scenes.play.openPause();
  if (q.has('map')) { Scenes.play.mode = 'map'; Scenes.play.mapFrom = 'play'; }
  if (q.has('scene')) { setScene(q.get('scene')); for (let i = 0; i < 120; i++) Game.scene.update(DT); }
}

window.addEventListener('load', boot);
