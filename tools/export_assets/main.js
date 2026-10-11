'use strict';
// Esporta in godot/assets/ grafica, font, effetti sonori e musica generati dal codice JS originale.
// Uso (senza ELECTRON_RUN_AS_NODE nell ambiente): desktop/node_modules/.bin/electron tools/export_assets/main.js [--force] [--only=sprites,font,tiles,sfx,music]
const { app, BrowserWindow, ipcMain } = require('electron');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'godot', 'assets');
const args = process.argv.slice(2);
const force = args.includes('--force');
const onlyArg = args.find(a => a.startsWith('--only='));
const only = onlyArg ? onlyArg.slice(7).split(',') : ['sprites', 'font', 'tiles', 'sfx', 'music'];

// rifiuta di sovrascrivere asset esistenti senza --force: dopo l'esportazione sono sorgenti
function prepare(dir) {
  const d = path.join(OUT, dir);
  const existing = fs.existsSync(d) ? fs.readdirSync(d).filter(f => !f.endsWith('.import')) : [];
  if (existing.length && !force) throw new Error(d + ' contiene già degli asset: usa --force per sovrascriverli');
  fs.mkdirSync(d, { recursive: true });
}
function save(rel, buf) {
  const p = path.join(OUT, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, buf);
}
ipcMain.handle('write', (e, rel, b64) => save(rel, Buffer.from(b64, 'base64')));
ipcMain.handle('writeText', (e, rel, text) => save(rel, Buffer.from(text, 'utf8')));
ipcMain.handle('log', (e, msg) => console.log(msg));

// la musica viene registrata in WAV e convertita in OGG Vorbis
function encodeMusic() {
  const dir = path.join(OUT, 'music');
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.wav'))) {
    const src = path.join(dir, f), dst = src.replace(/\.wav$/, '.ogg');
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', src, '-c:a', 'libvorbis', '-q:a', '3', dst]);
    fs.unlinkSync(src);
  }
}

app.whenReady().then(async () => {
  try {
    for (const k of only) prepare(k);
    const win = new BrowserWindow({
      show: false,
      webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: false, backgroundThrottling: false }
    });
    await win.loadFile(path.join(__dirname, 'export.html'));
    await win.webContents.executeJavaScript('runExport(' + JSON.stringify(only) + ')');
    if (only.includes('music')) encodeMusic();
    console.log('Esportazione completata in ' + OUT);
    app.exit(0);
  } catch (e) {
    console.error(e.message || e);
    app.exit(1);
  }
});
