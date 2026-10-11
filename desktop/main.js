'use strict';
// Involucro desktop (Electron) per Ultima Lanterna.
const { app, BrowserWindow, Menu } = require('electron');
const path = require('path');
const fs = require('fs');

let logFile = null;
function log(line) {
  try {
    if (!logFile) logFile = path.join(app.getPath('userData'), 'registro-errori.txt');
    fs.appendFileSync(logFile, '[' + new Date().toISOString() + '] ' + line + '\n');
  } catch (e) { /* il registro non e' essenziale */ }
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1440, height: 810, minWidth: 480, minHeight: 270,
    backgroundColor: '#050308', title: 'Ultima Lanterna', show: false,
    icon: path.join(__dirname, 'build', 'icon.png'),
    autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, sandbox: true, backgroundThrottling: false, autoplayPolicy: 'no-user-gesture-required' }
  });
  Menu.setApplicationMenu(null);
  if (!process.env.UL_SMOKE) win.once('ready-to-show', () => win.show());
  win.loadFile(path.join(__dirname, 'game', 'index.html'));

  // F11 e Alt+Invio: schermo intero
  win.webContents.on('before-input-event', (e, input) => {
    if (input.type !== 'keyDown') return;
    if (input.key === 'F11' || (input.key === 'Enter' && input.alt)) {
      win.setFullScreen(!win.isFullScreen());
      e.preventDefault();
    }
  });
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));

  // gli errori del gioco finiscono in un file da allegare ai report
  win.webContents.on('console-message', (...args) => {
    const d = args[0] && args[0].message !== undefined ? args[0] : null;
    const level = d ? d.level : args[1];
    const msg = d ? d.message : args[2];
    if (level === 'error' || level === 3) log('ERRORE ' + msg);
  });
  win.webContents.on('render-process-gone', (e, details) => log('PROCESSO TERMINATO ' + JSON.stringify(details)));

  // prova automatica della build: UL_SMOKE=<file.png> salva una schermata ed esce
  if (process.env.UL_SMOKE) {
    win.webContents.once('did-finish-load', () => setTimeout(async () => {
      try { fs.writeFileSync(process.env.UL_SMOKE, (await win.webContents.capturePage()).toPNG()); } catch (e) { log('SMOKE ' + e); }
      app.quit();
    }, 3000));
  }
}

app.whenReady().then(() => {
  log('Avvio ' + app.getVersion() + ' su ' + process.platform + ' ' + process.arch);
  createWindow();
});
app.on('window-all-closed', () => app.quit());
