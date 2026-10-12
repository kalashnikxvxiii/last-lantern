'use strict';
// Gira nella finestra nascosta di Electron: disegna e registra gli asset
// con il codice originale del gioco e li passa al processo principale.

const toB64 = canvas => canvas.toDataURL('image/png').split(',')[1];

async function runExport(only) {
  Save.load();
  Font.init();
  buildSprites();
  if (only.includes('sprites')) await exportSprites();
  if (only.includes('font')) await exportFont();
  if (only.includes('tiles')) await exportTiles();
  if (only.includes('sfx')) await exportSfx();
  if (only.includes('music')) await exportMusic();
}

// ogni sprite: un PNG con i frame affiancati (outline incluso) + manifest
async function exportSprites() {
  const manifest = {};
  for (const name of Object.keys(SPR)) {
    const s = SPR[name];
    const cv = makeCanvas(s.w * s.frames.length, s.h);
    const c = cv.getContext('2d');
    s.frames.forEach((f, i) => c.drawImage(f, i * s.w, 0));
    await exporter.write('sprites/' + name + '.png', toB64(cv));
    manifest[name] = { w: s.w, h: s.h, frames: s.frames.length };
  }
  await exporter.writeText('sprites/manifest.json', JSON.stringify(manifest, null, 1));
  exporter.log('sprite esportati: ' + Object.keys(manifest).length);
}

// font: atlas bianco, larghezze dei glifi e BMFont per l'editor
async function exportFont() {
  const chars = Object.keys(Font.glyphs);
  let total = 0;
  for (const ch of chars) total += Font.glyphs[ch].w + 1;
  const cv = makeCanvas(total, 8), c = cv.getContext('2d');
  c.fillStyle = '#ffffff';
  const map = {};
  const fnt = [
    'info face="lanterna" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
    'common lineHeight=10 base=7 scaleW=' + total + ' scaleH=8 pages=1 packed=0',
    // pagina separata: l'importatore BMFont di Godot marca la sua texture come "skip",
    // mentre lanterna.png deve restare una texture normale per UiDraw
    'page id=0 file="lanterna_page.png"',
    'chars count=' + (chars.length + 1),
    'char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=4 page=0 chnl=15',
  ];
  let x = 0;
  for (const ch of chars) {
    const g = Font.glyphs[ch];
    g.rows.forEach((row, ry) => row.forEach((on, rx) => { if (on) c.fillRect(x + rx, ry, 1, 1); }));
    map[ch] = [x, g.w];
    fnt.push('char id=' + ch.codePointAt(0) + ' x=' + x + ' y=0 width=' + g.w + ' height=8 xoffset=0 yoffset=0 xadvance=' + (g.w + 1) + ' page=0 chnl=15');
    x += g.w + 1;
  }
  await exporter.write('font/lanterna.png', toB64(cv));
  await exporter.write('font/lanterna_page.png', toB64(cv));
  await exporter.writeText('font/glyphs.json', JSON.stringify(map));
  await exporter.writeText('font/lanterna.fnt', fnt.join('\n') + '\n');
  exporter.log('glifi esportati: ' + chars.length);
}
// atlas dei tile per bioma: pavimento, muri e rocce di renderRoomBg (js/dungeon.js)
async function exportTiles() {
  const COLS = 8, layoutAll = {};
  for (const biome of BIOMES) {
    const tiles = [];
    for (let ci = 0; ci < 3; ci++) for (const kind of ['plain', 'seam', 'crack']) for (let g = 0; g < 6; g++)
      tiles.push(['floor_c' + ci + '_' + kind + '_g' + g, (c, x, y) => drawFloorVariant(c, x, y, biome, ci, kind, g)]);
    for (const edge of ['top', 'bottom', 'left0', 'left1', 'right0', 'right1', 'corner']) for (const crack of [0, 1])
      tiles.push(['wall_' + edge + '_' + crack, (c, x, y) => drawWallVariant(c, x, y, biome, edge, crack)]);
    for (const cracked of [0, 1]) for (const dot of [0, 1])
      tiles.push(['rock_' + cracked + '_' + dot, (c, x, y) => drawRock(c, x, y, biome, !!cracked, dot ? 0.7 : 0.2)]);
    const rows = Math.ceil(tiles.length / COLS);
    const cv = makeCanvas(COLS * TS, rows * TS), c = cv.getContext('2d');
    const layout = {};
    tiles.forEach(([k, fn], i) => { const col = i % COLS, row = Math.floor(i / COLS); fn(c, col * TS, row * TS); layout[k] = [col, row]; });
    await exporter.write('tiles/' + biome.id + '.png', toB64(cv));
    layoutAll[biome.id] = layout;
  }
  await exporter.writeText('tiles/layout.json', JSON.stringify({ tile: TS, columns: COLS, biomes: layoutAll }));
  exporter.log('atlas dei tile: ' + Object.keys(layoutAll).join(', '));
}

// pavimento di renderRoomBg con colore, giunto e granelli scelti
function drawFloorVariant(c, x, y, biome, ci, kind, g) {
  c.fillStyle = biome.floor[ci]; c.fillRect(x, y, TS, TS);
  c.fillStyle = biome.floorD;
  c.fillRect(x, y + TS - 1, TS, 1); c.fillRect(x + TS - 1, y, 1, TS);
  if (kind === 'seam') c.fillRect(x + 8, y, 1, 8);
  for (let k = 0; k < 4; k++) {
    const hx = hash2(g * 7 + k, 3, 9), hy = hash2(g * 5, 11 + k, 3);
    c.fillStyle = k % 2 ? biome.floorD : 'rgba(255,255,255,0.04)';
    c.fillRect(x + Math.floor(hx * 15), y + Math.floor(hy * 15), 1, 1);
  }
  if (kind === 'crack') { c.fillStyle = biome.floorD; c.fillRect(x + 3, y + 5, 5, 1); c.fillRect(x + 7, y + 6, 4, 1); c.fillRect(x + 10, y + 7, 1, 3); }
}

// muro di drawWallTile per bordo e parità della riga
function drawWallVariant(c, x, y, biome, edge, crack) {
  const ty = { top: 0, bottom: RH - 1, left0: 2, left1: 1, right0: 2, right1: 1, corner: 0 }[edge];
  c.fillStyle = biome.wallD; c.fillRect(x, y, TS, TS);
  const off = (ty % 2) * 8;
  c.fillStyle = biome.wall;
  for (let by = 0; by < 2; by++) for (let bx = -1; bx < 2; bx++) {
    const ox = x + bx * 8 + ((by + ty) % 2) * 4 + (off % 8);
    const rx = Math.max(x, ox), rw = Math.min(x + TS, ox + 7) - rx;
    if (rw > 0) c.fillRect(rx, y + by * 8, rw, 7);
  }
  c.fillStyle = biome.wallL;
  if (edge === 'top') c.fillRect(x, y + TS - 2, TS, 2);
  if (edge === 'bottom') c.fillRect(x, y, TS, 1);
  if (edge === 'left0' || edge === 'left1') c.fillRect(x + TS - 2, y, 2, TS);
  if (edge === 'right0' || edge === 'right1') c.fillRect(x, y, 2, TS);
  if (crack) { c.fillStyle = 'rgba(0,0,0,0.4)'; c.fillRect(x + 4, y + 3, 1, 5); c.fillRect(x + 5, y + 7, 2, 1); }
}
const SFX_NAMES = ['shoot', 'hit', 'crit', 'kill', 'hurt', 'coin', 'xp', 'pickup', 'heal', 'oil', 'levelup', 'dash', 'flare',
  'explosion', 'door', 'lock', 'enemyShoot', 'spawn', 'roar', 'select', 'confirm', 'deny', 'chest', 'buy', 'curse', 'shield',
  'freeze', 'thud', 'bolt', 'tick', 'descend', 'warn', 'block'];

// rumore bianco come in Sound.unlock, generato con il Math.random corrente
function makeNoise(c) {
  const len = c.sampleRate * 1.0, b = c.createBuffer(1, len, c.sampleRate), d = b.getChannelData(0);
  for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
  return b;
}
function trimTail(data, sr) {
  let end = data.length;
  while (end > sr * 0.05 && Math.abs(data[end - 1]) < 1e-4) end--;
  return data.subarray(0, end);
}
// PCM 16 bit, codificato in base64
function wavB64(samples, sr) {
  const n = samples.length, buf = new ArrayBuffer(44 + n * 2), v = new DataView(buf);
  const str = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  str(0, 'RIFF'); v.setUint32(4, 36 + n * 2, true); str(8, 'WAVE'); str(12, 'fmt ');
  v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true); v.setUint32(24, sr, true);
  v.setUint32(28, sr * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true); str(36, 'data'); v.setUint32(40, n * 2, true);
  for (let i = 0; i < n; i++) v.setInt16(44 + i * 2, Math.max(-1, Math.min(1, samples[i])) * 32767, true);
  const bytes = new Uint8Array(buf);
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(bin);
}

// ogni effetto di Sound.play registrato offline in 3 varianti (Math.random con semi diversi)
async function exportSfx() {
  const SR = 44100;
  Save.data.settings.sfx = 1;
  for (let idx = 0; idx < SFX_NAMES.length; idx++) {
    const name = SFX_NAMES[idx];
    for (let v = 1; v <= 3; v++) {
      const r = new RNG(1000 * v + idx);
      Math.random = () => r.next();
      const oc = new OfflineAudioContext(1, SR * 2, SR);
      const out = oc.createGain(); out.gain.value = 1; out.connect(oc.destination);
      Sound.ctx = oc; Sound.sfxGain = out; Sound.unlocked = true; Sound.last = Object.create(null);
      Sound.noiseBuf = makeNoise(oc);
      Sound.play(name);
      const buf = await oc.startRendering();
      await exporter.write('sfx/' + name + '_' + v + '.wav', wavB64(trimTail(buf.getChannelData(0), SR), SR));
    }
  }
  exporter.log('effetti esportati: ' + SFX_NAMES.length * 3);
}
// strati della musica: ognuno riproduce una parte di Music.playStep a intensità fissa
const STEMS = {
  drone: null,                                   // Music.startDrone
  arp_lo: (s, t) => stemArp(s, t, 0),
  arp: (s, t) => stemArp(s, t, 1),
  arp_hi: (s, t) => stemArp(s, t, 2),
  bass: (s, t) => { stemBass(s, t); stemKick(s, t); },
  hats: (s, t) => stemHats(s, t),
};
function stemChord(s) { const tr = Music.track; if (s % 16 === 0) Music.chord = tr.chords[(s / 16 | 0) % tr.chords.length]; return Music.chord; }
function stemArp(s, t, I) {
  const c = Sound.ctx, ch = stemChord(s);
  const pProb = I === 0 ? 0.3 : I === 1 ? 0.5 : 0.65;
  if (Math.random() < pProb || (s % 8 === 0)) {
    const tones = [0, 2, 4, 7];
    const deg = ch + pick(tones) + (Math.random() < 0.2 ? 1 : 0);
    const f = Music.noteFreq(deg, 2 + (Math.random() < 0.3 ? 1 : 0));
    const o = c.createOscillator(), g = c.createGain();
    o.type = I >= 2 ? 'square' : 'triangle'; o.frequency.value = f;
    const vol = I >= 2 ? 0.035 : 0.06;
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.6);
    const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1600;
    o.connect(lp); lp.connect(g); g.connect(Music.bus); g.connect(Music.delayIn);
    o.start(t); o.stop(t + 0.65);
  }
}
function stemBass(s, t) {
  const c = Sound.ctx, ch = stemChord(s);
  if (s % 4 !== 0) return;
  const f = Music.noteFreq(ch, 0);
  const o = c.createOscillator(), g = c.createGain(), lp = c.createBiquadFilter();
  o.type = 'sawtooth'; o.frequency.value = f; lp.type = 'lowpass'; lp.frequency.value = 300;
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.09, t + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
  o.connect(lp); lp.connect(g); g.connect(Music.bus); o.start(t); o.stop(t + 0.4);
}
function stemKick(s, t) {
  const c = Sound.ctx;
  if (s % 4 !== 0) return;
  const o = c.createOscillator(), g = c.createGain();
  o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(38, t + 0.15);
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.15, t + 0.005);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.2);
  o.connect(g); g.connect(Music.bus); o.start(t); o.stop(t + 0.25);
}
function stemHats(s, t) {
  const c = Sound.ctx;
  stemChord(s);
  if (s % 2 !== 1) return;
  const src = c.createBufferSource(); src.buffer = Sound.noiseBuf;
  const f = c.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 6000;
  const g = c.createGain();
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.03, t + 0.003);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.05);
  src.connect(f); f.connect(g); g.connect(Music.bus); src.start(t, Math.random() * 0.5); src.stop(t + 0.06);
}

// 32 battute (256 ottavi) per strato, con preroll per il drone e chiusura ad anello:
// la coda delle note viene sommata all'inizio, il drone si dissolve incrociato.
async function renderStem(name, stem, seed) {
  const SR = 44100, PRE = 4, TAIL = 2, STEPS = 256;
  const tr = TRACKS[name], stepDur = 60 / tr.tempo / 2;
  const L = STEPS * stepDur;
  const total = Math.ceil((PRE + L + TAIL) * SR);
  const r = new RNG(seed); Math.random = () => r.next();
  const oc = new OfflineAudioContext(1, total, SR);
  const out = oc.createGain(); out.gain.value = 1; out.connect(oc.destination);
  Sound.ctx = oc; Sound.musicGain = out; Sound.noiseBuf = makeNoise(oc);
  Music.init();
  Music.track = tr; Music.chord = 0;
  Music.delay.delayTime.value = 60 / tr.tempo * 0.75;
  if (stem === 'drone') Music.startDrone();
  else for (let s = 0; s < STEPS; s++) STEMS[stem](s, PRE + s * stepDur);
  const data = (await oc.startRendering()).getChannelData(0);
  const a = Math.floor(PRE * SR), n = Math.floor(L * SR), x = Math.floor(TAIL * SR);
  const loop = new Float32Array(n);
  for (let i = 0; i < n; i++) loop[i] = data[a + i];
  for (let i = 0; i < x; i++) {
    const tail = data[a + n + i];
    if (stem === 'drone') { const k = i / x; loop[i] = loop[i] * Math.sqrt(k) + tail * Math.sqrt(1 - k); }
    else loop[i] += tail;
  }
  return loop;
}
async function exportMusic() {
  let seed = 1;
  for (const name of Object.keys(TRACKS)) for (const stem of Object.keys(STEMS)) {
    const loop = await renderStem(name, stem, seed++);
    await exporter.write('music/' + name + '_' + stem + '.wav', wavB64(loop, 44100));
  }
  exporter.log('strati musicali: ' + Object.keys(TRACKS).length * Object.keys(STEMS).length);
}
