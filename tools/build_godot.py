#!/usr/bin/env python3
"""Crea il pacchetto Windows per i tester della versione Godot.

Uso:  python3 tools/build_godot.py
Richiede: Godot 4.7.2 nel PATH (comando "godot") con i modelli di esportazione
installati (Editor > Gestisci modelli di esportazione). Esegue prima i test.
Risultato: dist/godot/UltimaLanterna-<versione>-Windows.zip e SHA256SUMS.txt.
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
NAME = 'UltimaLanterna-' + version.replace(' ', '-')


def step(msg):
    print('\n==> ' + msg, flush=True)


def run(cmd, cwd=ROOT):
    print('   $ ' + ' '.join(cmd), flush=True)
    subprocess.run(cmd, cwd=cwd, check=True)


def text(name):
    # i tester aprono i .txt con il Blocco note: a capo in stile Windows
    s = open(os.path.join(TESTER, name), encoding='utf-8').read().replace('{VERSION}', version)
    return s.replace('\n', '\r\n')


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    step('Versione ' + version)
    step('Test')
    run([os.path.join(ROOT, 'tools', 'test.sh')])

    step('Esportazione Windows')
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(BUILD)
    exe = os.path.join(BUILD, 'Ultima Lanterna.exe')
    run(['godot', '--headless', '--path', GODOT, '--export-release', 'Windows Desktop', exe])
    if not os.path.isfile(exe):
        raise SystemExit('Esportazione fallita: manca ' + exe)

    step('Pacchetto')
    zip_path = os.path.join(OUT, NAME + '-Windows.zip')
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(exe, 'Ultima Lanterna/Ultima Lanterna.exe')
        z.writestr('Ultima Lanterna/LEGGIMI.txt', text('LEGGIMI.txt'))
        z.writestr('Ultima Lanterna/MODULO_FEEDBACK.txt', text('MODULO_FEEDBACK.txt'))
    shutil.rmtree(BUILD, ignore_errors=True)
    with open(os.path.join(OUT, 'SHA256SUMS.txt'), 'w') as f:
        f.write(sha256(zip_path) + '  ' + os.path.basename(zip_path) + '\n')
    print('\n   %s  %.1f MB' % (os.path.basename(zip_path), os.path.getsize(zip_path) / 1e6))
    print('Pacchetto pronto in ' + OUT)


if __name__ == '__main__':
    main()
