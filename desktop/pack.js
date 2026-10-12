'use strict';
// Creates the desktop builds for Windows and Linux (x64).
// Usage: node pack.js <output-folder> [win32|linux ...]
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
  appCopyright: 'Last Lantern',
  ignore: [/^\/pack\.js$/, /^\/build\/icon\.ico$/, /^\/node_modules/],
};

(async () => {
  for (const platform of platforms) {
    const opts = Object.assign({}, common, { platform });
    if (platform === 'win32') {
      opts.executableName = 'Last Lantern';
      opts.icon = path.join(__dirname, 'build', 'icon.ico');
      opts.win32metadata = { CompanyName: 'Last Lantern', FileDescription: 'Last Lantern', ProductName: 'Last Lantern', InternalName: 'Last Lantern' };
    } else {
      opts.executableName = 'last-lantern';
    }
    try {
      const paths = await packager(opts);
      console.log('OK', platform, paths.join(', '));
    } catch (e) {
      if (platform === 'win32' && opts.icon) {
        // without Wine the icon cannot be embedded: retry without it
        console.warn('Windows icon not applied (' + e.message.split('\n')[0] + '), retrying without it.');
        delete opts.icon; delete opts.win32metadata;
        const paths = await packager(opts);
        console.log('OK', platform, paths.join(', '), '(no icon)');
      } else throw e;
    }
  }
})().catch(e => { console.error(e); process.exit(1); });
