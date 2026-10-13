#!/usr/bin/env python3
"""Exports the Godot version as standalone executables: a normal one and a
developer one with the cheat panel on (F1 or ` during play).

Usage:  python3 tools/export_godot.py [windows] [linux]   (both by default)
Requires: Godot 4.7.2 in the PATH (the "godot" command) with the export templates
of each platform installed (Editor > Manage Export Templates). Runs on Windows
and Linux; a platform whose templates are missing is reported and skipped.
Result: dist/godot/bin/<platform>/Last Lantern[.exe] and Last Lantern Dev[.exe].
The "Dev" presets in godot/export_presets.cfg add the "cheats" feature tag
(see autoload/cheats.gd).

Both executables use the same save file as every other run of the game.
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
GODOT = os.path.join(ROOT, 'godot')
OUT = os.path.join(ROOT, 'dist', 'godot', 'bin')

# platform -> (normal preset, dev preset, executable extension)
PLATFORMS = {
    'windows': ('Windows Desktop', 'Windows Desktop Dev', '.exe'),
    'linux': ('Linux', 'Linux Dev', '.x86_64'),
}


def run(cmd):
    print('   $ ' + ' '.join('"%s"' % c if ' ' in c else c for c in cmd), flush=True)
    return subprocess.run(cmd, cwd=ROOT).returncode


def export(platform):
    normal, dev, ext = PLATFORMS[platform]
    out = os.path.join(OUT, platform)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    made = []
    for preset, name in ((normal, 'Last Lantern'), (dev, 'Last Lantern Dev')):
        exe = os.path.join(out, name + ext)
        run(['godot', '--headless', '--path', GODOT, '--export-release', preset, exe])
        if not os.path.isfile(exe):
            print('   export failed: are the %s export templates installed?' % platform)
            return []
        if platform == 'linux':
            os.chmod(exe, 0o755)
        made.append(exe)
    return made


def main():
    platforms = sys.argv[1:] or list(PLATFORMS)
    for p in platforms:
        if p not in PLATFORMS:
            raise SystemExit('Unknown platform "%s" (use: %s)' % (p, ', '.join(PLATFORMS)))
    print('\n==> Import', flush=True)
    run(['godot', '--headless', '--path', GODOT, '--import'])
    made, failed = [], []
    for p in platforms:
        print('\n==> Export ' + p, flush=True)
        exes = export(p)
        made += exes
        if not exes:
            failed.append(p)
    print()
    for exe in made:
        print('   %s  %.1f MB' % (os.path.relpath(exe, ROOT), os.path.getsize(exe) / 1e6))
    if failed:
        raise SystemExit('Not exported: ' + ', '.join(failed))


if __name__ == '__main__':
    main()
