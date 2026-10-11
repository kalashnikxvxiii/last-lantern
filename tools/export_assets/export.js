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
