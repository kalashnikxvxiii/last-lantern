'use strict';
// =====================================================================
//  Generazione delle profondita': mappa a stanze, layout, porte
// =====================================================================

// Quadranti 14x7 (colonna 13 e riga 6 sono gli assi di simmetria).
// '.' pavimento  '#' roccia  '%' roccia incrinata  'b' barile  'u' urna
// '^' spuntoni  'o' braciere  '?' roccia casuale
const QUADS = [
  ['..............', '..............', '..............', '..............', '..............', '..............', '..............'],
  ['..............', '..............', '..............', '.....##.......', '.....##.......', '..............', '..............'],
  ['..............', '..............', '..............', '..........o###', '...........###', '...........###', '...........###'],
  ['..............', '..............', '...#######....', '..............', '..............', '..............', '..............'],
  ['..............', '..b...........', '.....#........', '..........#...', '...#..........', '.......b....%.', '..............'],
  ['..............', '..............', '.............#', '.............#', '.............#', '.........#####', '..............'],
  ['..............', '..............', '....^^^.......', '....^^^.......', '..............', '.........^^^^^', '..............'],
  ['..............', '..............', '......####....', '......#.......', '......#.......', '..............', '..............'],
  ['..............', '.#............', '..#...........', '...#.......o..', '....#.........', '.....#........', '..............'],
  ['..............', '.b.....u......', '..............', '...u.......#..', '..........###.', '...........#..', '..............'],
  ['..............', '..............', '...?...#...?..', '..............', '..............', '...#...?...#..', '..............'],
  ['..............', '..#####.......', '..#...........', '..#....#######', '..............', '..............', '..............'],
  ['..............', '..............', '..............', '.........^^^^^', '.........^....', '.........^....', '..............'],
  ['..............', '..u.......u...', '....%%........', '....%%........', '..............', '.......b......', '..............'],
  ['..............', '...b..........', '..............', '.......##.....', '.......##..^^^', '...........^..', '..............'],
];
const QUAD_BOSS = ['..............', '.o............', '..............', '..............', '..............', '..............', '..............'];
const QUAD_SPECIAL = ['..............', '..o...........', '..............', '..............', '..............', '..............', '..............'];

function expandQuad(q) {
  const top = q.map(r => r + [...r.slice(0, 13)].reverse().join(''));
  return top.concat(top.slice(0, 6).reverse());
}

const DIRS = {
  n: { dx: 0, dy: -1, opp: 's', tiles: [[13, 0], [14, 0], [15, 0]] },
  s: { dx: 0, dy: 1, opp: 'n', tiles: [[13, 14], [14, 14], [15, 14]] },
  w: { dx: -1, dy: 0, opp: 'e', tiles: [[0, 6], [0, 7], [0, 8]] },
  e: { dx: 1, dy: 0, opp: 'w', tiles: [[28, 6], [28, 7], [28, 8]] },
};
// punto di ingresso del giocatore quando arriva da una porta
function doorEntry(dir) {
  switch (dir) {
    case 'n': return { x: RX + 14.5 * TS, y: RY + 1.9 * TS };
    case 's': return { x: RX + 14.5 * TS, y: RY + 13.1 * TS };
    case 'w': return { x: RX + 1.9 * TS, y: RY + 7.5 * TS };
    case 'e': return { x: RX + 27.1 * TS, y: RY + 7.5 * TS };
  }
}
function doorCenter(dir) {
  const t = DIRS[dir].tiles[1];
  return { x: RX + (t[0] + 0.5) * TS, y: RY + (t[1] + 0.5) * TS };
}

// ---------------------------------------------------------------------
//  Mappa della profondita'
// ---------------------------------------------------------------------
function genFloor(depth, rng, target) {
  const GW = 9, GH = 8;
  const nTarget = target || Math.min(20, 9 + depth * 2 + rng.int(0, 2));
  const key = (x, y) => x + ',' + y;
  for (let attempt = 0; attempt < 400; attempt++) {
    const cells = new Map();
    const nbCount = (x, y) => [[1, 0], [-1, 0], [0, 1], [0, -1]].reduce((a, [dx, dy]) => a + (cells.has(key(x + dx, y + dy)) ? 1 : 0), 0);
    const start = { gx: 4, gy: 4 };
    cells.set(key(4, 4), start);
    const queue = [start];
    while (queue.length && cells.size < nTarget) {
      const c = queue.shift();
      let added = false;
      for (const [dx, dy] of rng.shuffle([[1, 0], [-1, 0], [0, 1], [0, -1]])) {
        if (cells.size >= nTarget) break;
        const nx = c.gx + dx, ny = c.gy + dy;
        if (nx < 0 || ny < 0 || nx >= GW || ny >= GH) continue;
        if (cells.has(key(nx, ny))) continue;
        if (nbCount(nx, ny) > 1) continue;
        if (rng.chance(0.5)) continue;
        const n = { gx: nx, gy: ny };
        cells.set(key(nx, ny), n); queue.push(n); added = true;
      }
      if (!added && queue.length === 0 && cells.size < nTarget) {
        // rimetti in coda una stanza casuale per continuare a crescere
        queue.push(rng.pick([...cells.values()]));
      }
    }
    if (cells.size < nTarget) continue;
    const list = [...cells.values()];
    const nbs = c => [['n', 0, -1], ['s', 0, 1], ['w', -1, 0], ['e', 1, 0]].map(([d, dx, dy]) => [d, cells.get(key(c.gx + dx, c.gy + dy))]).filter(x => x[1]);
    // distanze BFS
    const distM = new Map([[start, 0]]);
    const bq = [start];
    while (bq.length) { const c = bq.shift(); for (const [, n] of nbs(c)) if (!distM.has(n)) { distM.set(n, distM.get(c) + 1); bq.push(n); } }
    const dead = list.filter(c => c !== start && nbs(c).length === 1).sort((a, b) => distM.get(b) - distM.get(a));
    const need = 3 + (depth >= 2 ? 1 : 0);
    if (dead.length < need) continue;
    if (distM.get(dead[0]) < 3) continue;

    // costruisci le stanze
    const rooms = new Map();
    for (const c of list) {
      rooms.set(key(c.gx, c.gy), {
        gx: c.gx, gy: c.gy, type: 'normal', dist: distM.get(c), doors: {}, seed: rng.int(1, 2 ** 31 - 1),
        built: false, visited: false, seen: false, cleared: false, found: true
      });
    }
    const R = c => rooms.get(key(c.gx, c.gy));
    R(start).type = 'start';
    R(dead[0]).type = 'boss';
    const rest = rng.shuffle(dead.slice(1));
    R(rest[0]).type = 'treasure';
    R(rest[0]).locked = depth >= 2;
    R(rest[1]).type = 'shop';
    let i = 2;
    if (depth >= 2 && rest[i]) { R(rest[i]).type = 'elite'; i++; }
    if (rest[i]) { R(rest[i]).type = 'shrine'; i++; }
    // stanza segreta: cella vuota con molte stanze adiacenti
    let best = null, bestN = 1;
    for (let gy = 0; gy < GH; gy++) for (let gx = 0; gx < GW; gx++) {
      if (cells.has(key(gx, gy))) continue;
      const adj = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => rooms.get(key(gx + dx, gy + dy))).filter(Boolean);
      if (adj.some(r => r.type === 'boss' || r.type === 'start')) continue;
      if (adj.length > bestN || (adj.length === bestN && best && rng.chance(0.4))) { best = { gx, gy }; bestN = adj.length; }
    }
    if (best) {
      rooms.set(key(best.gx, best.gy), {
        gx: best.gx, gy: best.gy, type: 'secret', dist: 99, doors: {}, seed: rng.int(1, 2 ** 31 - 1),
        built: false, visited: false, seen: false, cleared: true, found: false
      });
    }
    // collega le porte
    for (const r of rooms.values()) {
      for (const d in DIRS) {
        const n = rooms.get(key(r.gx + DIRS[d].dx, r.gy + DIRS[d].dy));
        if (n) r.doors[d] = n;
      }
    }
    const startRoom = R(start);
    for (const r of rooms.values()) if (['start', 'treasure', 'shop', 'shrine', 'secret'].includes(r.type)) r.cleared = true;
    return { depth, rooms: [...rooms.values()], map: rooms, start: startRoom, key };
  }
  return genFloor(depth, rng, nTarget - 1);
}

function roomAt(floor, gx, gy) { return floor.map.get(gx + ',' + gy); }

// ---------------------------------------------------------------------
//  Costruzione di una stanza
// ---------------------------------------------------------------------
function tileAt(room, tx, ty) {
  if (tx < 0 || ty < 0 || tx >= RW || ty >= RH) return T.WALL;
  return room.grid[ty][tx];
}
function doorVisible(room, dir) {
  const n = room.doors[dir];
  if (!n) return false;
  if (n.type === 'secret' && !n.found) return false;
  if (room.type === 'secret' && !room.found) return false;
  return true;
}
function doorLocked(room, dir) {
  const n = room.doors[dir];
  if (!n) return false;
  return n.type === 'treasure' && !!n.locked;
}
function doorOpen(room, dir) {
  if (!doorVisible(room, dir)) return false;
  if (doorLocked(room, dir)) return false;
  return room.cleared && !room.combat;
}
function isSolidTile(room, tx, ty, fly) {
  const t = tileAt(room, tx, ty);
  if (t === T.FLOOR || t === T.SPIKE) return false;
  if (t === T.WALL) return true;
  if (t === T.DOOR) return !doorOpen(room, room.doorDir[ty * RW + tx]);
  if (fly) return false;
  return true;
}
function blocksShot(room, tx, ty) {
  const t = tileAt(room, tx, ty);
  return !(t === T.FLOOR || t === T.SPIKE || (t === T.DOOR && doorOpen(room, room.doorDir[ty * RW + tx])));
}
const worldToTile = (x, y) => [Math.floor((x - RX) / TS), Math.floor((y - RY) / TS)];
const tileCenter = (tx, ty) => ({ x: RX + (tx + 0.5) * TS, y: RY + (ty + 0.5) * TS });

function buildRoom(room, floor) {
  const rng = new RNG(room.seed);
  const biome = biomeOf(floor.depth);
  room.built = true;
  room.grid = [];
  for (let y = 0; y < RH; y++) {
    const row = [];
    for (let x = 0; x < RW; x++) row.push(x === 0 || y === 0 || x === RW - 1 || y === RH - 1 ? T.WALL : T.FLOOR);
    room.grid.push(row);
  }
  room.doorDir = {};
  room.tileHp = {};
  room.objects = [];
  room.pickups = [];
  room.decals = [];
  room.spikeT = 0;
  room.waves = [];
  room.combat = false;
  room.bgDirty = true;

  let quad;
  if (room.type === 'boss') quad = QUAD_BOSS;
  else if (room.type === 'normal' || room.type === 'elite') quad = rng.pick(QUADS.slice(1));
  else if (room.type === 'start') quad = QUADS[0];
  else quad = QUAD_SPECIAL;

  const layout = expandQuad(quad);
  for (let y = 0; y < 13; y++) for (let x = 0; x < 27; x++) {
    let ch = layout[y][x];
    if (ch === '?') ch = rng.chance(0.5) ? '#' : '.';
    if (ch === 'u' && !biome.urns) ch = rng.chance(0.5) ? 'b' : '.';
    if (ch === '#' && rng.chance(0.12)) ch = '%';
    const t = { '.': T.FLOOR, '#': T.ROCK, '%': T.CRACK, 'b': T.BARREL, 'u': T.URN, '^': T.SPIKE, 'o': T.BRAZIER }[ch];
    room.grid[y + 1][x + 1] = t === undefined ? T.FLOOR : t;
    if (t === T.BARREL) room.tileHp[(y + 1) * RW + x + 1] = 18;
    if (t === T.URN) room.tileHp[(y + 1) * RW + x + 1] = 1;
  }
  // varieta' extra: urne/barili sparsi nelle stanze normali
  if (room.type === 'normal' && rng.chance(0.5)) {
    for (let k = 0; k < rng.int(1, 3); k++) {
      const x = rng.int(2, 26), y = rng.int(2, 12);
      if (room.grid[y][x] === T.FLOOR) {
        const t = biome.urns && rng.chance(0.6) ? T.URN : T.BARREL;
        room.grid[y][x] = t; room.tileHp[y * RW + x] = t === T.URN ? 1 : 18;
      }
    }
  }
  // porte e spazio libero davanti
  for (const d in DIRS) {
    if (!room.doors[d]) continue;
    for (const [tx, ty] of DIRS[d].tiles) {
      room.doorDir[ty * RW + tx] = d;
      room.grid[ty][tx] = doorVisible(room, d) ? T.DOOR : T.WALL;
    }
    clearDoorZone(room, d);
  }
  // raggiungibilita'
  if (!checkReachable(room)) {
    for (let y = 1; y < RH - 1; y++) for (let x = 1; x < RW - 1; x++) room.grid[y][x] = T.FLOOR;
    room.tileHp = {};
  }
  // decorazioni
  const nDec = rng.int(10, 22);
  for (let k = 0; k < nDec; k++) room.decals.push({ x: rng.int(RX + 18, RX + RW * TS - 18), y: rng.int(RY + 18, RY + RH * TS - 18), k: rng.int(0, 5), s: rng.next() });

  // contenuti
  const c = tileCenter(14, 7);
  switch (room.type) {
    case 'normal': case 'elite': planWaves(room, floor, rng, biome); break;
    case 'boss': room.waves = [[{ type: 'BOSS', boss: biome.boss }]]; break;
    case 'treasure': {
      const picks = randomRelics(2, rng);
      if (picks.length === 0) picks.push(null);
      picks.forEach((id, i) => {
        const x = picks.length === 1 ? c.x : c.x + (i === 0 ? -36 : 36);
        room.objects.push(id ? { type: 'relic', id, x, y: c.y, group: 'treasure' } : { type: 'chest', gold: true, x, y: c.y });
      });
      break;
    }
    case 'shop': makeShop(room, floor, rng); break;
    case 'shrine': makeShrine(room, floor, rng); break;
    case 'secret': {
      room.objects.push({ type: 'chest', gold: true, open: false, x: c.x, y: c.y + 12 });
      if (rng.chance(0.5)) {
        const r = randomRelics(1, rng)[0];
        if (r) room.objects.push({ type: 'relic', id: r, x: c.x, y: c.y - 24 });
      }
      for (let k = 0; k < rng.int(6, 10); k++) room.pickups.push(makePickup(rng.chance(0.2) ? 'coin5' : 'coin', c.x + rng.range(-50, 50), c.y + rng.range(-30, 40)));
      break;
    }
    case 'start':
      if (floor.depth === 1) room.tutorial = true;
      break;
  }
}

function clearDoorZone(room, d) {
  const zones = {
    n: [11, 1, 17, 2], s: [11, 12, 17, 13], w: [1, 5, 2, 9], e: [26, 5, 27, 9]
  }[d];
  for (let y = zones[1]; y <= zones[3]; y++) for (let x = zones[0]; x <= zones[2]; x++) {
    room.grid[y][x] = T.FLOOR; delete room.tileHp[y * RW + x];
  }
}

function walkable(t) { return t === T.FLOOR || t === T.SPIKE || t === T.DOOR; }

function floodFrom(room, sx, sy) {
  const seen = new Set();
  const q = [[sx, sy]];
  seen.add(sy * RW + sx);
  while (q.length) {
    const [x, y] = q.pop();
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (nx < 1 || ny < 1 || nx >= RW - 1 || ny >= RH - 1) continue;
      const k = ny * RW + nx;
      if (seen.has(k)) continue;
      if (!walkable(room.grid[ny][nx])) continue;
      seen.add(k); q.push([nx, ny]);
    }
  }
  return seen;
}
function checkReachable(room) {
  const entries = Object.keys(room.doors).map(d => ({ n: [14, 1], s: [14, 13], w: [1, 7], e: [27, 7] })[d]);
  const st = entries[0] || [14, 7];
  const seen = floodFrom(room, st[0], st[1]);
  for (const e of entries) if (!seen.has(e[1] * RW + e[0])) { room.reach = null; return false; }
  room.reach = seen;
  return true;
}
function reachTiles(room) {
  if (!room.reach) room.reach = floodFrom(room, 14, 7);
  return [...room.reach].map(k => [k % RW, Math.floor(k / RW)]);
}

// ---------------------------------------------------------------------
//  Ondate di nemici
// ---------------------------------------------------------------------
function planWaves(room, floor, rng, biome) {
  const d = floor.depth;
  const elite = room.type === 'elite';
  let nWaves = 1;
  if (d === 1) nWaves = room.dist >= 3 && rng.chance(0.25) ? 2 : 1;
  else if (d === 2) nWaves = rng.chance(0.4) ? 2 : 1;
  else if (d <= 4) nWaves = rng.chance(0.6) ? 2 : 1;
  else nWaves = rng.chance(0.3) ? 3 : 2;
  if (elite) nWaves = 2;
  const ard = run ? run.ardore : 0;
  let eliteChance = [0, 0.06, 0.12, 0.18, 0.24][Math.min(4, d - 1)] + Math.max(0, d - 5) * 0.04;
  if (ard >= 3) eliteChance *= 2;
  for (let w = 0; w < nWaves; w++) {
    let budget = 3.4 + d * 1.7 + Math.min(4, room.dist * 0.45) + rng.range(0, 1.6);
    if (d > 5) budget += (d - 5) * 1.2;
    if (nWaves > 1) budget *= 0.8;
    if (elite) budget *= 0.75;
    const wave = [];
    const pool = biome.pool;
    let guard = 0;
    while (budget > 0.9 && wave.length < 11 && guard++ < 50) {
      const opts = pool.filter(([, cost]) => cost <= budget + 0.4);
      if (!opts.length) break;
      const [type, cost] = rng.weighted(opts, o => o[2]);
      budget -= cost;
      let mod = null;
      if (elite || rng.chance(eliteChance)) mod = rng.pick(Object.keys(ELITE_MODS));
      wave.push({ type, mod });
    }
    if (wave.length) room.waves.push(wave);
  }
}

// ---------------------------------------------------------------------
//  Negozio e santuari
// ---------------------------------------------------------------------
function makeShop(room, floor, rng) {
  const c = tileCenter(14, 7);
  room.objects.push({ type: 'merchant', x: c.x, y: c.y - 40, line: rng.pick(MERCHANT_LINES) });
  const consPool = Object.keys(CONS);
  const items = [];
  const k1 = rng.weighted(consPool, k => CONS[k].w);
  let k2 = rng.weighted(consPool, k => CONS[k].w);
  if (k2 === k1) k2 = rng.weighted(consPool, k => CONS[k].w);
  items.push({ kind: 'cons', id: k1 }, { kind: 'cons', id: k2 });
  items.push({ kind: 'heal' });
  items.push({ kind: rng.chance(0.5) ? 'key' : 'cons', id: 'bomb' });
  const relic = randomRelics(1, rng)[0];
  if (relic) items.push({ kind: 'relic', id: relic });
  const n = items.length;
  items.forEach((it, i) => {
    const x = c.x + (i - (n - 1) / 2) * 40;
    room.objects.push({ type: 'shopitem', item: it, x, y: c.y + 18, price: basePrice(it, floor.depth) });
  });
}
function basePrice(it, depth) {
  const m = 1 + 0.12 * (depth - 1);
  if (it.kind === 'cons') return Math.round(CONS[it.id].price * m);
  if (it.kind === 'heal') return Math.round(15 * m);
  if (it.kind === 'key') return Math.round(12 * m);
  if (it.kind === 'relic') return Math.round((48 + depth * 8));
  return 10;
}
function makeShrine(room, floor, rng) {
  const c = tileCenter(14, 7);
  const kinds = ['blood', 'fortune', 'fountain', 'pact'];
  const kind = rng.pick(kinds);
  room.objects.push({ type: 'shrine', kind, x: c.x, y: c.y - 4, uses: kind === 'fortune' ? 5 : 1 });
}
function randomRelics(n, rng) {
  const owned = new Set(run ? run.player.relics : []);
  const offered = run ? run.offeredRelics : new Set();
  let pool = Object.keys(RELICS).filter(k => !owned.has(k) && !offered.has(k));
  if (pool.length < n) pool = Object.keys(RELICS).filter(k => !owned.has(k));
  rng.shuffle(pool);
  const out = pool.slice(0, n);
  for (const k of out) offered.add(k);
  return out;
}

function biomeOf(depth) { return BIOMES[(depth - 1) % BIOMES.length]; }

// ---------------------------------------------------------------------
//  Rendering dello sfondo della stanza (pre-calcolato)
// ---------------------------------------------------------------------
function hash2(x, y, s = 0) { let h = (x * 374761393 + y * 668265263 + s * 1442695041) | 0; h = (h ^ (h >>> 13)) * 1274126177; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; }

function renderRoomBg(room, floor) {
  const biome = biomeOf(floor.depth);
  if (!room.bg) room.bg = makeCanvas(RW * TS, RH * TS);
  const c = room.bg.getContext('2d');
  c.imageSmoothingEnabled = false;
  const s = room.seed % 1000;
  // pavimento
  for (let ty = 0; ty < RH; ty++) for (let tx = 0; tx < RW; tx++) {
    const x = tx * TS, y = ty * TS;
    const h = hash2(tx, ty, s);
    c.fillStyle = biome.floor[Math.floor(h * biome.floor.length)];
    c.fillRect(x, y, TS, TS);
    // fughe tra le lastre
    c.fillStyle = biome.floorD;
    c.fillRect(x, y + TS - 1, TS, 1); c.fillRect(x + TS - 1, y, 1, TS);
    if (h > 0.55) { c.fillRect(x + 8, y, 1, 8); }
    // granelli
    for (let k = 0; k < 4; k++) {
      const hx = hash2(tx * 7 + k, ty * 3, s + 9), hy = hash2(tx * 5, ty * 11 + k, s + 3);
      c.fillStyle = k % 2 ? biome.floorD : 'rgba(255,255,255,0.04)';
      c.fillRect(x + Math.floor(hx * 15), y + Math.floor(hy * 15), 1, 1);
    }
    if (h < 0.08) { c.fillStyle = biome.floorD; c.fillRect(x + 3, y + 5, 5, 1); c.fillRect(x + 7, y + 6, 4, 1); c.fillRect(x + 10, y + 7, 1, 3); }
  }
  // decorazioni
  for (const d of room.decals) drawDecal(c, d, biome);
  if (room.tutorial) drawTutorialFloor(c);
  // muri
  for (let ty = 0; ty < RH; ty++) for (let tx = 0; tx < RW; tx++) {
    const t = room.grid[ty][tx];
    const x = tx * TS, y = ty * TS;
    if (t === T.WALL || t === T.DOOR) drawWallTile(c, room, tx, ty, x, y, biome, s);
  }
  // ombra dei muri sul pavimento
  c.fillStyle = 'rgba(0,0,0,0.35)';
  c.fillRect(TS, TS, (RW - 2) * TS, 4);
  c.fillStyle = 'rgba(0,0,0,0.18)';
  c.fillRect(TS, TS + 4, (RW - 2) * TS, 3);
  c.fillRect(TS, TS, 3, (RH - 2) * TS);
  // rocce
  for (let ty = 1; ty < RH - 1; ty++) for (let tx = 1; tx < RW - 1; tx++) {
    const t = room.grid[ty][tx];
    if (t === T.ROCK || t === T.CRACK) drawRock(c, tx * TS, ty * TS, biome, t === T.CRACK, hash2(tx, ty, s));
  }
  room.bgDirty = false;
}

function drawWallTile(c, room, tx, ty, x, y, biome, s) {
  c.fillStyle = biome.wallD; c.fillRect(x, y, TS, TS);
  // mattoni
  const off = (ty % 2) * 8;
  c.fillStyle = biome.wall;
  for (let by = 0; by < 2; by++) for (let bx = -1; bx < 2; bx++) {
    const ox = x + bx * 8 + ((by + ty) % 2) * 4 + (off % 8);
    const rx = Math.max(x, ox), rw = Math.min(x + TS, ox + 7) - rx;
    if (rw > 0) c.fillRect(rx, y + by * 8, rw, 7);
  }
  // bordo interno illuminato
  c.fillStyle = biome.wallL;
  if (ty === 0 && tx > 0 && tx < RW - 1) c.fillRect(x, y + TS - 2, TS, 2);
  if (ty === RH - 1 && tx > 0 && tx < RW - 1) c.fillRect(x, y, TS, 1);
  if (tx === 0 && ty > 0 && ty < RH - 1) c.fillRect(x + TS - 2, y, 2, TS);
  if (tx === RW - 1 && ty > 0 && ty < RH - 1) c.fillRect(x, y, 2, TS);
  if (hash2(tx, ty, s + 77) < 0.1) { c.fillStyle = 'rgba(0,0,0,0.4)'; c.fillRect(x + 4, y + 3, 1, 5); c.fillRect(x + 5, y + 7, 2, 1); }
}

function drawRock(c, x, y, biome, cracked, h) {
  c.fillStyle = 'rgba(0,0,0,0.35)'; c.fillRect(x + 2, y + 12, 13, 3);
  c.fillStyle = '#0b0810'; c.fillRect(x + 2, y + 2, 12, 12); c.fillRect(x + 1, y + 4, 14, 8); c.fillRect(x + 4, y + 1, 8, 14);
  c.fillStyle = biome.wall; c.fillRect(x + 3, y + 3, 10, 10); c.fillRect(x + 2, y + 5, 12, 6); c.fillRect(x + 5, y + 2, 6, 12);
  c.fillStyle = biome.wallL; c.fillRect(x + 4, y + 3, 6, 2); c.fillRect(x + 3, y + 5, 2, 3);
  c.fillStyle = biome.wallD; c.fillRect(x + 4, y + 11, 8, 2); c.fillRect(x + 11, y + 6, 2, 5);
  if (h > 0.5) { c.fillStyle = biome.wallD; c.fillRect(x + 7, y + 6, 2, 2); }
  if (cracked) {
    c.fillStyle = '#0b0810';
    c.fillRect(x + 7, y + 2, 1, 3); c.fillRect(x + 8, y + 5, 1, 2); c.fillRect(x + 6, y + 7, 2, 1);
    c.fillRect(x + 5, y + 8, 1, 3); c.fillRect(x + 9, y + 7, 3, 1); c.fillRect(x + 11, y + 8, 1, 2);
  }
}

function drawDecal(c, d, biome) {
  const x = d.x - RX, y = d.y - RY;
  switch (biome.deco) {
    case 'bones':
      c.fillStyle = 'rgba(220,210,190,0.35)';
      if (d.k < 2) { c.fillRect(x, y, 5, 1); c.fillRect(x - 1, y - 1, 1, 3); c.fillRect(x + 5, y - 1, 1, 3); }
      else if (d.k < 4) { c.fillRect(x, y, 3, 3); c.fillStyle = 'rgba(0,0,0,0.5)'; c.fillRect(x, y + 1, 1, 1); c.fillRect(x + 2, y + 1, 1, 1); }
      else { c.fillStyle = 'rgba(0,0,0,0.25)'; c.fillRect(x, y, 6, 3); }
      break;
    case 'shrooms': {
      const cols = ['#a33a7a', '#c8443a', '#9fd05a', '#e88fc0'];
      c.fillStyle = 'rgba(200,190,160,0.5)'; c.fillRect(x + 1, y + 2, 1, 2);
      c.fillStyle = cols[d.k % 4]; c.fillRect(x, y + 1, 3, 1); c.fillRect(x + 1, y, 1, 1);
      if (d.s > 0.6) { c.fillStyle = 'rgba(80,140,60,0.3)'; c.fillRect(x - 3, y + 4, 8, 2); }
      break;
    }
    case 'cracks':
      c.fillStyle = d.k < 2 ? 'rgba(242,120,40,0.5)' : 'rgba(0,0,0,0.35)';
      c.fillRect(x, y, 4, 1); c.fillRect(x + 3, y + 1, 1, 2); c.fillRect(x + 4, y + 3, 3, 1);
      break;
    case 'puddles':
      c.fillStyle = 'rgba(40,90,110,0.35)';
      c.beginPath(); c.ellipse(x, y, 4 + d.s * 8, 2 + d.s * 3, 0, 0, TAU); c.fill();
      c.fillStyle = 'rgba(150,220,230,0.18)'; c.fillRect(x - 2, y - 1, 3, 1);
      break;
    case 'veins':
      c.fillStyle = 'rgba(160,70,180,0.35)';
      for (let i = 0; i < 6; i++) c.fillRect(x + i * 2, y + Math.round(Math.sin(i + d.s * 6) * 2), 2, 1);
      break;
  }
}

function drawTutorialFloor(c) {
  const lines = [
    '^dWASD muoviti   -   MOUSE mira   -   CLIC SINISTRO spara',
    '^dSPAZIO scatto   -   CLIC DESTRO o F  Vampata (consuma olio)',
    '^d1 2 3 4 consumabili   -   E interagisci   -   TAB mappa',
  ];
  c.save(); c.globalAlpha = 0.55;
  lines.forEach((l, i) => Font.draw(c, l, RW * TS / 2, 150 + i * 12, { align: 'center', shadow: false }));
  c.restore();
}
