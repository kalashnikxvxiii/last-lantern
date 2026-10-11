'use strict';
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('exporter', {
  write: (rel, b64) => ipcRenderer.invoke('write', rel, b64),
  writeText: (rel, text) => ipcRenderer.invoke('writeText', rel, text),
  log: msg => ipcRenderer.invoke('log', msg),
});
