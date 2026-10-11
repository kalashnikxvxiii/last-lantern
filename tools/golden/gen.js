'use strict';
// Genera i dati golden per i test del porting Godot eseguendo il codice JS originale.
// Uso: node tools/golden/gen.js
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'godot', 'tests', 'golden');
const FILES = ['core.js', 'font.js', 'gfx.js', 'sprites.js', 'audio.js', 'data.js', 'dungeon.js', 'entities.js', 'render.js', 'ui.js', 'game.js'];

const noop = () => {};
const ctx = {
  console, URLSearchParams,
  window: { addEventListener: noop },
  document: { getElementById: () => null, createElement: () => ({ getContext: () => null }) },
  localStorage: { getItem: () => null, setItem: noop },
  navigator: {}, performance: { now: () => 0 },
  addEventListener: noop, requestAnimationFrame: noop, setTimeout: noop, innerWidth: 480, innerHeight: 270,
};
vm.createContext(ctx);
for (const f of FILES) vm.runInContext(fs.readFileSync(path.join(ROOT, 'js', f), 'utf8'), ctx, { filename: f });

// codice eseguito dentro la sandbox: vede le dichiarazioni globali dei file JS
const HARNESS = String.raw`
Save.load();
function seedRandom(s) { const r = new RNG(s); Math.random = () => r.next(); }
function makeRun(lantern) {
  run = { player: newPlayer(lantern || 'custode'), offeredRelics: new Set(), ardore: 0, depth: 1, room: null,
    enemies: [], bullets: [], ebullets: [], fx: [], toasts: [], banners: [], kills: 0, dmgDealt: 0, dmgTaken: 0, coinsTotal: 0 };
  return run;
}
const key = r => r.gx + ',' + r.gy;

function genRng() {
  return [1, 42, 123456789, 2147483647, 4294967295].map(seed => {
    const r = new RNG(seed); const values = [];
    for (let i = 0; i < 1000; i++) values.push(r.next());
    return { seed, values };
  });
}

function genUtil() {
  const r = new RNG(7);
  const h = [];
  for (let i = 0; i < 300; i++) { const x = r.int(-50, 600), y = r.int(-50, 400), s = r.int(0, 1100); h.push([x, y, s, hash2(x, y, s)]); }
  h.push([0, 0, 0, hash2(0, 0)]);
  const im = [];
  for (let i = 0; i < 200; i++) { const a = r.int(0, 4294967295), b = r.int(0, 4294967295); im.push([a, b, Math.imul(a, b)]); }
  const xs = [-2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 0.49999999, -0.50000001, 3.7, -3.7, 0, 1e6 + 0.5];
  for (let i = 0; i < 50; i++) xs.push(r.range(-1000, 1000));
  const round = xs.map(x => [x, Math.round(x)]);
  const time = [0, 5, 59.9, 60, 61, 125.5, 3599, 3600].map(s => [s, fmtTime(s)]);
  seedRandom(5);
  const seq = { seed: 5, rnd: rnd(), rnd10: rnd(10), rnd37: rnd(3, 7), rndi29: rndi(2, 9), pick: pick(['a', 'b', 'c', 'd']),
    chance: chance(0.3), shuffle: shuffle([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    weighted: weightedPick([['x', 1], ['y', 3], ['z', 0.5]], k => k[1])[0] };
  return { hash2: h, imul: im, round, time, seq };
}

function floorJson(depth, seed) {
  const f = genFloor(depth, new RNG(seed));
  return {
    depth, seed, start: key(f.start),
    rooms: f.rooms.map(r => ({ key: key(r), gx: r.gx, gy: r.gy, type: r.type, dist: r.dist, seed: r.seed,
      cleared: !!r.cleared, found: !!r.found, locked: !!r.locked,
      doors: Object.fromEntries(Object.entries(r.doors).map(([d, n]) => [d, key(n)])) }))
  };
}
function genFloors() {
  const out = [];
  for (let s = 1; s <= 50; s++) out.push(floorJson(1, s));
  for (let s = 1; s <= 10; s++) { out.push(floorJson(2, s)); out.push(floorJson(3, s)); }
  return out;
}

function genRooms() {
  const out = [];
  for (let s = 1; s <= 20; s++) {
    seedRandom(s * 7919);
    makeRun();
    const f = genFloor(1, new RNG(s));
    const rooms = [];
    for (const r of f.rooms) {
      buildRoom(r, f);
      rooms.push({ key: key(r), type: r.type, grid: r.grid, tileHp: r.tileHp, doorDir: r.doorDir,
        objects: r.objects, pickups: r.pickups, decals: r.decals, waves: r.waves, tutorial: !!r.tutorial,
        reach: r.reach ? [...r.reach] : null });
    }
    out.push({ seed: s, rooms });
  }
  return out;
}

function statCase(lantern, perks, relics, curses, ardore, baseHpMod) {
  makeRun(lantern);
  run.ardore = ardore;
  const p = run.player;
  p.perks = perks; p.relics = relics; p.curses = curses; p.baseHpMod = baseHpMod;
  p.hp = 9999; p.oil = 9999; p.dashCharges = 99;
  recalcStats();
  const derived = [];
  for (const st of [{}, { rage: {} }, { weak: {} }, { fury: {} }, { slow: {}, chill: {} }, { blind: {} }]) {
    for (const [hf, of] of [[1, 1], [0.3, 0.5], [0.1, 0]]) {
      p.statuses = st; p.hp = p.stats.maxHp * hf; p.oil = p.stats.maxOil * of;
      derived.push({ statuses: Object.keys(st), hpFrac: hf, oilFrac: of, damage: pDamage(p), fireRate: pFireRate(p), speed: pSpeed(p), light: pLight(p) });
    }
  }
  return { lantern, perks, relics, curses, ardore, baseHpMod, stats: p.stats, derived };
}
function genStats() {
  const cases = [];
  for (const L of LANTERNS) cases.push(statCase(L.id, {}, [], [], 0, 0));
  for (const id in PERKS) { cases.push(statCase('custode', { [id]: 1 }, [], [], 0, 0)); cases.push(statCase('custode', { [id]: PERKS[id].max }, [], [], 0, 0)); }
  for (const id in RELICS) cases.push(statCase('custode', {}, [id], [], 0, 0));
  for (const id in CURSES) cases.push(statCase('custode', {}, [], [id], 0, 0));
  const r = new RNG(99);
  const pk = Object.keys(PERKS), rk = Object.keys(RELICS), ck = Object.keys(CURSES), lk = LANTERNS.map(l => l.id);
  for (let i = 0; i < 30; i++) {
    const perks = {};
    for (let k = 0; k < r.int(0, 8); k++) { const id = r.pick(pk); perks[id] = Math.min(PERKS[id].max, (perks[id] || 0) + 1); }
    const relics = r.shuffle(rk.slice()).slice(0, r.int(0, 4));
    const curses = r.shuffle(ck.slice()).slice(0, r.int(0, 3));
    cases.push(statCase(r.pick(lk), perks, relics, curses, r.int(0, 5), r.chance(0.3) ? -15 : 0));
  }
  const perkRolls = [];
  for (let s = 1; s <= 12; s++) {
    seedRandom(s * 31);
    makeRun();
    const p = run.player;
    p.perks = s % 3 === 0 ? { dmg: 5, rate: 2 } : {};
    if (s % 4 === 0) p.relics = ['r_clover'];
    run.depth = 1 + (s % 3);
    recalcStats();
    const n = 3 + p.stats.extraChoice, minRar = s % 5 === 0 ? 1 : 0;
    perkRolls.push({ seed: s * 31, perks: p.perks, relics: p.relics, depth: run.depth, n, minRar, out: rollPerkChoices(n, minRar) });
  }
  return { cases, perkRolls };
}

function genFormulas() {
  const xp = [], dh = [], dd = [], bp = [], hurt = [];
  for (let L = 1; L <= 40; L++) xp.push([L, xpNeed(L)]);
  for (let d = 1; d <= 12; d++) { dh.push([d, depthHp(d)]); dd.push([d, depthDmg(d)]); }
  for (let d = 1; d <= 6; d++) {
    for (const id in CONS) bp.push(['cons', id, d, basePrice({ kind: 'cons', id }, d)]);
    bp.push(['heal', '', d, basePrice({ kind: 'heal' }, d)]);
    bp.push(['key', '', d, basePrice({ kind: 'key' }, d)]);
    bp.push(['relic', '', d, basePrice({ kind: 'relic', id: 'r_eye' }, d)]);
  }
  const r = new RNG(3);
  for (let i = 0; i < 100; i++) {
    const amount = r.range(1, 40), dmgTaken = r.pick([1, 1.2, 1.44]), armor = r.int(0, 12), fragile = r.chance(0.3), oilEmpty = r.chance(0.3);
    // stessa formula di hurtPlayer (js/entities.js)
    let dmg = amount * dmgTaken * (1 - Math.min(0.6, armor * 0.07));
    if (fragile) dmg *= 1.3;
    if (oilEmpty) dmg *= 1.25;
    hurt.push([amount, dmgTaken, armor, fragile, oilEmpty, Math.max(1, Math.round(dmg))]);
  }
  return { xpNeed: xp, depthHp: dh, depthDmg: dd, basePrice: bp, hurt };
}

function genEnemies() {
  const enemies = [], bosses = [];
  const F = ['hp', 'maxHp', 'spd', 'dmg', 'xp', 'r', 'fly', 'shotCd', 'anim', 't', 'stun', 'elite', 'mod'];
  let seed = 1;
  for (const type of ['rat', 'bat', 'skeleton', 'skull', 'ghoul']) for (let depth = 1; depth <= 3; depth++)
    for (const mod of [null, ...Object.keys(ELITE_MODS)]) for (const small of [false, true]) {
      seedRandom(seed); makeRun(); run.depth = depth; recalcStats();
      const e = makeEnemy(type, 100, 100, mod, small ? { small: true } : {});
      const fields = {}; for (const k of F) fields[k] = e[k] === undefined ? null : e[k];
      fields.elite = !!e.elite;
      enemies.push({ seed, type, depth, mod, small, fields }); seed++;
    }
  for (let depth = 1; depth <= 2; depth++) {
    makeRun(); run.depth = depth;
    const b = makeBoss('bones', 100, 100);
    bosses.push({ id: 'bones', depth, fields: { hp: b.hp, maxHp: b.maxHp, spd: b.spd, dmg: b.dmg, xp: b.xp, r: b.r } });
  }
  return { enemies, bosses };
}

function genMovement() {
  const traces = [], flow = [], lines = [];
  for (let s = 1; s <= 10; s++) {
    seedRandom(s); makeRun();
    const f = genFloor(1, new RNG(s));
    const room = f.rooms.find(r => r.type === 'normal');
    buildRoom(room, f);
    run.room = room;
    for (const open of [true, false]) {
      room.cleared = open; room.combat = !open;
      const c = tileCenter(14, 7);
      const a = { x: c.x, y: c.y + 20, r: 4 };
      const start = [a.x, a.y];
      const r = new RNG(1000 + s);
      const steps = [];
      for (let i = 0; i < 400; i++) {
        const axis = r.int(0, 2);
        const dx = axis === 1 ? 0 : r.range(-6, 6), dy = axis === 0 ? 0 : r.range(-6, 6);
        // come updatePlayer: assi separati e scivolamento sugli spigoli
        const bx = moveAxis(a, dx, 0, false);
        const by = moveAxis(a, dy, 1, false);
        if (bx && Math.abs(dy) < 1) nudge(a, 0, dx);
        if (by && Math.abs(dx) < 1) nudge(a, 1, dy);
        steps.push([dx, dy, a.x, a.y, bx || by]);
      }
      traces.push({ seed: s, open, start, steps });
    }
    room.cleared = false; room.combat = true;
    const c = tileCenter(14, 7);
    run.player = Object.assign(run.player, { x: c.x, y: c.y });
    updateFlow();
    const r = new RNG(2000 + s);
    const probes = [];
    for (let i = 0; i < 40; i++) {
      const t = r.pick(reachTiles(room)); const tc = tileCenter(t[0], t[1]);
      const ex = tc.x + r.range(-5, 5), ey = tc.y + r.range(-5, 5);
      probes.push([ex, ey, flowAngle({ x: ex, y: ey }, run.player.x, run.player.y)]);
    }
    flow.push({ seed: s, player: [c.x, c.y], probes });
    const cases = [];
    for (let i = 0; i < 40; i++) {
      const x0 = r.range(RX, RX + RW * TS), y0 = r.range(RY, RY + RH * TS), x1 = r.range(RX, RX + RW * TS), y1 = r.range(RY, RY + RH * TS);
      cases.push([x0, y0, x1, y1, lineClear(x0, y0, x1, y1)]);
    }
    lines.push({ seed: s, cases });
  }
  return { traces, flow, lines };
}

JSON.stringify({ rng: genRng(), util: genUtil(), floors: genFloors(), rooms: genRooms(), stats: genStats(),
  formulas: genFormulas(), enemies: genEnemies(), movement: genMovement() });
`;

const all = JSON.parse(vm.runInContext(HARNESS, ctx, { filename: 'harness.js' }));
fs.mkdirSync(OUT, { recursive: true });
for (const k in all) {
  fs.writeFileSync(path.join(OUT, k + '.json'), JSON.stringify(all[k]));
  console.log('scritto', k + '.json');
}
