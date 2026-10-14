#!/usr/bin/env python3
"""Builds the Windows package for testers of the Godot version.

Usage:  python3 tools/build_godot.py
Requires: Bash in the PATH (Git Bash on Windows), and Godot 4.7.2 (the "godot" command) with the export templates
installed (Editor > Manage Export Templates). Runs the tests first.
Result: dist/godot/LastLantern-<version>-Windows.zip and SHA256SUMS.txt.
"""
import hashlib
import os
import re
import shutil
import subprocess
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
GODOT = os.path.join(ROOT, 'godot')
OUT = os.path.join(ROOT, 'dist', 'godot')
BUILD = os.path.join(OUT, 'build')
TESTER = os.path.join(ROOT, 'tools', 'tester-godot')

version = re.search(r'const VERSION := "([^"]+)"', open(os.path.join(GODOT, 'core', 'consts.gd'), encoding='utf-8').read()).group(1)
NAME = 'LastLantern-' + version.replace(' ', '-')


def step(msg):
    print('\n==> ' + msg, flush=True)


def run(cmd, cwd=ROOT):
    print('   $ ' + ' '.join(cmd), flush=True)
    subprocess.run(cmd, cwd=cwd, check=True)


def text(name):
    # testers open the .txt files with Notepad: Windows-style line endings
    s = open(os.path.join(TESTER, name), encoding='utf-8').read().replace('{VERSION}', version)
    return s.replace('\n', '\r\n')


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    step('Version ' + version)
    step('Test')
    run(['bash', 'tools/test.sh'])

    step('Windows export')
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(BUILD)
    exe = os.path.join(BUILD, 'Last Lantern.exe')
    run(['godot', '--headless', '--path', GODOT, '--export-release', 'Windows Desktop', exe])
    if not os.path.isfile(exe):
        raise SystemExit('Export failed: missing ' + exe)

    step('Package')
    zip_path = os.path.join(OUT, NAME + '-Windows.zip')
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(exe, 'Last Lantern/Last Lantern.exe')
        z.writestr('Last Lantern/README.txt', text('README.txt'))
        z.writestr('Last Lantern/FEEDBACK_FORM.txt', text('FEEDBACK_FORM.txt'))
    shutil.rmtree(BUILD, ignore_errors=True)
    with open(os.path.join(OUT, 'SHA256SUMS.txt'), 'w') as f:
        f.write(sha256(zip_path) + '  ' + os.path.basename(zip_path) + '\n')
    print('\n   %s  %.1f MB' % (os.path.basename(zip_path), os.path.getsize(zip_path) / 1e6))
    print('Package ready in ' + OUT)


if __name__ == '__main__':
    main()
