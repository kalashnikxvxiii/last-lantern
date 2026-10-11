'use strict';
// Crea le build desktop per Windows e Linux (x64).
// Uso: node pack.js <cartella-uscita> [win32|linux ...]
const { packager } = require('@electron/packager');
const path = require('path');

const out = path.resolve(process.argv[2] || path.join(__dirname, '..', 'dist', 'build'));
const platforms = process.argv.slice(3).length ? process.argv.slice(3) : ['win32', 'linux'];

const common = {
  dir: __dirname,
  out,
  arch: 'x64',
  asar: true,
  overwrite: true,
  prune: true,
  appCopyright: 'Ultima Lanterna',
  ignore: [/^\/pack\.js$/, /^\/build\/icon\.ico$/, /^\/node_modules/],
};

(async () => {
  for (const platform of platforms) {
    const opts = Object.assign({}, common, { platform });
    if (platform === 'win32') {
      opts.executableName = 'Ultima Lanterna';
      opts.icon = path.join(__dirname, 'build', 'icon.ico');
      opts.win32metadata = { CompanyName: 'Ultima Lanterna', FileDescription: 'Ultima Lanterna', ProductName: 'Ultima Lanterna', InternalName: 'Ultima Lanterna' };
    } else {
      opts.executableName = 'ultima-lanterna';
    }
    try {
      const paths = await packager(opts);
      console.log('OK', platform, paths.join(', '));
    } catch (e) {
      if (platform === 'win32' && opts.icon) {
        // senza Wine non si puo' incorporare l'icona: riprova senza
        console.warn('Icona Windows non applicata (' + e.message.split('\n')[0] + '), riprovo senza.');
        delete opts.icon; delete opts.win32metadata;
        const paths = await packager(opts);
        console.log('OK', platform, paths.join(', '), '(senza icona)');
      } else throw e;
    }
  }
})().catch(e => { console.error(e); process.exit(1); });
