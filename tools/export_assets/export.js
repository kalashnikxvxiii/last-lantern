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
    'page id=0 file="lanterna.png"',
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
