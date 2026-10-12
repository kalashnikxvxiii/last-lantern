#!/usr/bin/env python3
"""Builds the tester package: Windows/Linux desktop builds and the browser version.

Usage:  python3 tools/build.py            (everything)
        python3 tools/build.py --web      (browser version only)
Requires: Node.js + npm. Wine is optional (only needed for the .exe icon).
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DIST = os.path.join(ROOT, 'dist')
BUILD = os.path.join(DIST, 'build')
DESK = os.path.join(ROOT, 'desktop')
TESTER = os.path.join(ROOT, 'tools', 'tester')

version = re.search(r"const VERSION = '([^']+)'", open(os.path.join(ROOT, 'js', 'core.js'), encoding='utf-8').read()).group(1)
tag = version.replace(' ', '-')
NAME = 'LastLantern-' + tag


def step(msg):
    print('\n==> ' + msg, flush=True)


def run(cmd, cwd):
    print('   $ ' + ' '.join(cmd), flush=True)
    env = dict(os.environ, WINEDEBUG='-all', WINEDLLOVERRIDES='mscoree,mshtml=')
    subprocess.run(cmd, cwd=cwd, check=True, env=env)


def text(name, crlf=False):
    s = open(os.path.join(TESTER, name), encoding='utf-8').read().replace('{VERSION}', version)
    return s.replace('\n', '\r\n') if crlf else s


def single_html():
    """index.html with all the scripts inlined: a single file to open."""
    html = open(os.path.join(ROOT, 'index.html'), encoding='utf-8').read()

    def inline(m):
        js = open(os.path.join(ROOT, m.group(1)), encoding='utf-8').read()
        assert '</script' not in js, m.group(1)
        return '<script>\n' + js + '\n</script>'
    return re.sub(r'<script src="([^"]+)"></script>', inline, html)


def zip_dir(src_dir, zip_path, root_name, extra):
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for base, _, files in os.walk(src_dir):
            for f in files:
                full = os.path.join(base, f)
                z.write(full, os.path.join(root_name, os.path.relpath(full, src_dir)))
        for arc, data in extra.items():
            z.writestr(os.path.join(root_name, arc), data)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    web_only = '--web' in sys.argv
    shutil.rmtree(DIST, ignore_errors=True)
    os.makedirs(BUILD)
    outputs = []

    step('Version ' + version)
    run([sys.executable, os.path.join(ROOT, 'tools', 'make_icon.py'), os.path.join(DESK, 'build')], ROOT)

    step('Browser version (single file)')
    html = single_html()
    web_zip = os.path.join(DIST, NAME + '-Browser.zip')
    with zipfile.ZipFile(web_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        root = NAME + '-Browser'
        z.writestr(root + '/Last Lantern.html', html)
        z.writestr(root + '/README.txt', text('README.txt', crlf=True))
        z.writestr(root + '/FEEDBACK_FORM.txt', text('FEEDBACK_FORM.txt', crlf=True))
    outputs.append(web_zip)

    if not web_only:
        step('Preparing the desktop app')
        game = os.path.join(DESK, 'game')
        shutil.rmtree(game, ignore_errors=True)
        os.makedirs(os.path.join(game, 'js'))
        shutil.copy(os.path.join(ROOT, 'index.html'), game)
        for f in os.listdir(os.path.join(ROOT, 'js')):
            shutil.copy(os.path.join(ROOT, 'js', f), os.path.join(game, 'js'))
        pkg = open(os.path.join(DESK, 'package.json'), encoding='utf-8').read()
        num = re.sub(r'[^0-9.]', '', version) or '0.0.0'
        open(os.path.join(DESK, 'package.json'), 'w', encoding='utf-8').write(re.sub(r'"version": "[^"]+"', '"version": "' + num + '"', pkg))
        if not os.path.isdir(os.path.join(DESK, 'node_modules', '@electron', 'packager')):
            run(['npm', 'install', '--no-audit', '--no-fund'], DESK)
        run(['node', 'pack.js', BUILD, 'win32', 'linux'], DESK)
        # keep only the English Chromium locale (less to download)
        for plat in ('win32', 'linux'):
            loc = os.path.join(BUILD, 'Last Lantern-%s-x64' % plat, 'locales')
            for f in os.listdir(loc):
                if f != 'en-US.pak':
                    os.remove(os.path.join(loc, f))

        step('Windows package')
        win_dir = os.path.join(BUILD, 'Last Lantern-win32-x64')
        win_zip = os.path.join(DIST, NAME + '-Windows.zip')
        zip_dir(win_dir, win_zip, 'Last Lantern', {
            'README.txt': text('README.txt', crlf=True),
            'FEEDBACK_FORM.txt': text('FEEDBACK_FORM.txt', crlf=True),
            'Last Lantern (browser).html': html,
        })
        outputs.append(win_zip)

        step('Linux package')
        lin_dir = os.path.join(BUILD, 'Last Lantern-linux-x64')
        for f in ('start.sh', 'install-shortcut.sh'):
            shutil.copy(os.path.join(TESTER, f), lin_dir)
            os.chmod(os.path.join(lin_dir, f), 0o755)
        shutil.copy(os.path.join(DESK, 'build', 'icon.png'), lin_dir)
        open(os.path.join(lin_dir, 'README.txt'), 'w', encoding='utf-8').write(text('README.txt'))
        open(os.path.join(lin_dir, 'FEEDBACK_FORM.txt'), 'w', encoding='utf-8').write(text('FEEDBACK_FORM.txt'))
        open(os.path.join(lin_dir, 'Last Lantern (browser).html'), 'w', encoding='utf-8').write(html)
        lin_tar = os.path.join(DIST, NAME + '-Linux.tar.gz')
        with tarfile.open(lin_tar, 'w:gz', compresslevel=9) as t:
            t.add(lin_dir, arcname='LastLantern')
        outputs.append(lin_tar)

    shutil.rmtree(BUILD, ignore_errors=True)
    step('Summary')
    with open(os.path.join(DIST, 'SHA256SUMS.txt'), 'w') as f:
        for p in outputs:
            line = sha256(p) + '  ' + os.path.basename(p)
            f.write(line + '\n')
    for p in outputs:
        print('   %-48s %6.1f MB' % (os.path.basename(p), os.path.getsize(p) / 1e6))
    print('\nPackages ready in ' + DIST)


if __name__ == '__main__':
    main()
