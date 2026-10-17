# Contributing to Last Lantern

Thanks for wanting to help. This guide explains how to set up your environment, where to make changes and how to propose them.

## The two versions of the game

- **`js/`**: the original JavaScript version (beta 0.9.0, five depths). It is the **reference for behavior**: when in doubt about how something should work, the JS code is authoritative.
- **`godot/`**: the Godot 4.7 port, where development continues. It contains the whole game: five depths, five wardens and the Infinite Abyss.

New features go into Godot. In the JS only beta bugs are fixed.

## What you need

| Tool | Used for |
|---|---|
| [Godot 4.7.2](https://godotengine.org) (`godot` command in the PATH) | developing and testing the Godot version |
| Godot 4.7.2 export templates | only to build the Windows package |
| Node.js 20 or newer | reference data for the tests (`tools/golden/`) |
| Python 3 | the tester package scripts |
| Bash, GNU `timeout` and `sed` (included in Git for Windows) | running `tools/test.sh`, also called by the Godot package builder |
| npm, ffmpeg (optional) | Electron and audio conversion, only to re-export the assets |

## First run

```bash
git clone https://github.com/kalashnikxvxiii/last-lantern.git && cd last-lantern
cp .githooks/* .git/hooks/               # refreshes the classes after every pull
godot --headless --path godot --import   # the first time, registers the classes
godot --path godot                       # starts the game
tools/test.sh                            # runs all the tests
```

Godot keeps the list of `class_name` scripts in `godot/.godot/`, which is not
tracked. After a pull that adds a class, `godot --path godot` fails with errors
like `Identifier "X" not declared` or `Nonexistent function 'new'` until the
import runs again. The hooks in `.githooks/` run it after every pull, rebase and
branch switch; without them, run `godot --headless --path godot --import` by hand.
On Windows PowerShell, install them with `Copy-Item .githooks\* .git\hooks\`.
They are copied rather than enabled with `core.hooksPath`: that would run the
hooks of whatever branch you check out, including someone else's before you
review it. Copy them again when `.githooks/` changes.

To work in the editor: `godot -e --path godot`.

On Windows, install Git for Windows and add its `bin` folder (usually
`C:\Program Files\Git\bin`) to your user PATH so Python can find `bash`.
Add the folder containing `godot.exe` to the PATH too, then restart your terminal
and the application that launched it. From PowerShell or Git Bash, run
`bash tools/test.sh`.

### Shared notes (Obsidian)

The team keeps its working notes in `notes/`, opened with [Obsidian](https://obsidian.md): choose **Open folder as vault** and pick the repository root (start from `notes/Home.md`). The shared `.obsidian/` settings are tracked; per-user state (window layout, hotkeys, cache) stays local. New Markdown outside `notes/` is still git-ignored, so put shared notes under `notes/` or add a `!path/file.md` line to `.gitignore` on purpose.

### Development arguments

After `--` you can jump straight to a situation:

```bash
godot --path godot -- --test=boss --seed=7          # boss room, reproducible floor
godot --path godot -- --test=fight --perks=multishot,comet --relics=r_anvil
godot --path godot -- --seed=7 --spawn=rat,ghoul,skull   # enemies in the starting room
godot --path godot -- --seed=7 --lv=2 --coins=50     # perk choice right away
godot --path godot -- --scene=title --screenshot=/tmp/title.png --shot-after=40
```

`--test` values: `fight`, `boss`, `shop`, `treasure`, `elite`, `shrine`, `secret`. Other arguments: `--depth=N` (start from that depth), `--lantern=`, `--ardor=`, `--sim=N` (simulated ticks), `--fire` (shoot the first enemy during `--sim`), `--pause`, `--map`. These runs write to the local save, like a real game.

### Cheat panel

During play press **F1** (or **`**) to open the cheat panel; the game stays paused while it is open. Arrows or WASD move, LEFT/RIGHT cycle a list or flip a toggle, ENTER applies, ESC goes back, F1 closes.

| Page | What it does |
|---|---|
| Player | god mode, infinite oil, noclip, one-hit kills, heal and refill, coins, keys, level up, die |
| Build | add or remove perks, relics (with their curse) and curses, give consumables, switch lantern, clear the build |
| World | kill all, clear the room, freeze enemies, spawn any enemy (optionally elite) or warden, go to a room type or depth, reveal the map, game speed (x0.25 to x4), debug readout |

The panel works in debug builds (editor and `godot --path godot`) and in the `Last Lantern Dev` executables (see [Executables](#executables)). In any other exported build start it with `-- --cheats`. `--cheat-panel=World` opens a page right away (useful with `--screenshot`). Active cheats are shown in red in the bottom right corner, so screenshots taken with cheats on are recognizable. Once a cheat is used, the descent records no stats (kills, wins, best depth, wardens, Ardor), so the save's unlocks stay earned; the toggles reset with every new descent. The code is in `autoload/cheats.gd` (state and actions) and `ui/cheat_menu.gd` (pages).

## Structure of `godot/`

| Folder | Contents |
|---|---|
| `autoload/` | always-on services: `Save`, `Sfx`, `Music`, `Fx`, `Controls`, `Run` (game state), `Game` (scenes, arguments, errors) |
| `core/` | constants, numeric utilities, random generator, sprites and font |
| `data/` | perks, relics, curses, consumables (scripts) and enemies, bosses, biomes, lanterns (`.tres` Resources, editable in the Inspector) |
| `world/` | floor and room generation, run flow, interactions, light, world drawing |
| `actors/` | player, enemies, AI, bosses and attack patterns |
| `combat/` | collisions, projectiles, damage, status effects, effects, pickups |
| `ui/` | HUD, menus, panels and screens |
| `assets/` | sprites, tiles, font, sound effects, music |
| `tests/` | automated tests and reference data (`golden/`) |

The logic runs at 60 ticks per second: `scenes/play.gd` calls `Flow.update_game()`, which updates player, enemies, projectiles and effects **in the same order as the JS**.

## Code rules

- **GDScript** with explicit types wherever inference would give `Variant`. Example: `var x: Array = dictionary.field`; for rounding use `floorf`/`ceilf`/`absf` and never `floor()` with `:=`.
- **Naming:** variables and functions in `snake_case`. Dictionary keys that mirror JS objects (stats, rooms, effects, projectiles) stay in camelCase as in the JS, so they can be compared with the reference data.
- **Text:** in English, identical to the JS where it exists, with the color codes `^y`, `^r` and so on. Comments are in English too.
- **Translations:** the English text is the key of `godot/locale/strings.json`, which holds its translation in every language of `Loc.LANGS`. `UiDraw.text`, `Txt.width` and `Txt.wrap` translate whole strings by themselves; text built from pieces goes through a template, `Loc.f("Depth {0}", [n])`, and names inserted in it through `Loc.t`. A new text needs an entry in `strings.json` for every language (`tests/test_loc.gd` checks the game data, the color codes, the placeholders and the glyphs). The language is in the Gameplay options; "Auto" follows the system language.
- **Randomness:**
  - in game logic always use `U.random()`, `U.rnd()`, `U.pick()`… or a seeded `RNG`, never `randf()`/`randi()`;
  - in drawing use `Fx.vrnd()`, which does not touch the game sequence.
- **Divisions:** between stat values write `float(a) / b`. Many base values are integers and integer division gives wrong results.
- **Comparing dictionaries or arrays:** `==` compares the contents. To tell whether they are the same object use `is_same(a, b)`.
- **Lists that grow during a loop** (`Run.fx`, `Run.bullets`, `Run.enemies`): loop by index with `while i < arr.size()`.
- **Porting code from the JS:** the full table of translation rules is in [docs/porting-conventions.md](docs/porting-conventions.md).

## Tests

- `tools/test.sh` runs everything; `tools/test.sh --only=boss` only the files or functions containing `boss`.
- **A test fails** if it records a failure or if a script error appears while it runs. If a test causes an error on purpose, call `allow_errors()`.
- **Where to write tests:** a new file `godot/tests/test_<topic>.gd` that extends `TestCase`, with `test_*` functions. The assertions are `check`, `eq`, `near` and `fail`; the helpers for creating runs and rooms are in `tests/helpers.gd` (`TH.new_run`, `TH.arena`, `TH.spawn`).
- **Reference data (golden):** the files in `tests/golden/` come from the JS code (`node tools/golden/gen.js`). If a change makes the behavior differ from the JS **on purpose**, say so in the description of the change. If you change the JS, regenerate the data and check the diff.
- **Tests before code:** write the failing test, then the change that makes it pass.

## Assets

The assets in `godot/assets/` were generated once from the JS code and are now **edited directly**: PNGs with Aseprite or any pixel-art editor, WAVs and OGGs with an audio editor.

- **Sprites:** frame sizes are in `assets/sprites/manifest.json`. If you change a sprite's size, update the manifest.
- **Tiles:** after changing the atlases, regenerate the TileSets with `godot --headless --path godot -s res://tools/build_tilesets.gd`.
- **Font:** `assets/font/lantern.png` and `glyphs.json` hold the Latin and Cyrillic glyphs. Chinese, Japanese and Korean are baked from [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font) 8px (SIL OFL 1.1, `assets/font/cjk-OFL.txt`) into `cjk.png` and `cjk.json`: after changing the `zh`, `ja` or `ko` text run `python3 tools/build_cjk_font.py <folder with the fusion-pixel-8px-proportional-*.ttf files>`.
- **Re-exporting from the JS:** `tools/export_assets/` overwrites hand-made changes, so it refuses to run without `--force`. Use it only if you mean to.

## Adding content

- **Enemy:** create `data/enemies/<id>.tres` (class `EnemyDef`, copy an existing one) and add it to the biome's `pool` in `data/biomes/<biome>.tres`. If you need a new behavior, add a method in `actors/ai.gd` and its case in `AI.run`. The sprite goes in `assets/sprites/` with its entry in the manifest.
- **Perk or relic:** add the entry at the end of `Perks.ALL` or `Relics.ALL` (order matters for the draws) and its effect in `apply()`. Then add a test in `tests/test_data.gd` that checks the effect: the stat tests only cover perks that also exist in the JS.
- **Lantern:** create a new `.tres` in `data/lanterns/` and add its id to `DB.LANTERN_IDS`.

## Proposing a change

1. Run `git fetch origin`, then create a branch from the updated remote `dev`: `git checkout -b short-name origin/dev`. Never branch from another feature branch or a stale local `dev`. Pull requests go to `dev`; `dev` is merged into `master` when a version is ready.
2. Make small commits with a message saying what changes, for example "Ghoul: the charge stops against rocks".
3. Before proposing the change:
   - `tools/test.sh` must pass;
   - try the situation in the game with the development arguments;
   - if something visible changes, attach a screenshot.
4. Open a pull request and fill in the template: why the change is needed, how you tried it and any intended differences from the JS.
5. The CI checks (tests, golden data, scripts) and the PR title check must pass before merging. `dev` and `master` are protected: no force pushes, changes go through pull requests, linear history on `dev`, and only `dev` can be merged into `master` (see `.github/rulesets/`).

## Tester packages

- **Godot version (Windows):** `python3 tools/build_godot.py`. Runs the tests, exports and creates `dist/godot/LastLantern-<version>-Windows.zip` with the tester instructions (`tools/tester-godot/`). The version number is `VERSION` in `godot/core/consts.gd`.
- **JS version (Windows, Linux, browser):** `python3 tools/build.py` (see [README.md](README.md)).

## Executables

`python3 tools/export_godot.py` exports two executables per platform into `dist/godot/bin/<platform>/`: `Last Lantern` (normal start) and `Last Lantern Dev` (cheat panel on, F1 during play). It runs on Windows and Linux and exports both platforms; pass `windows` or `linux` to export only one. Each platform needs its Godot 4.7.2 export templates (Editor > Manage Export Templates); a platform without them is reported and skipped. The Dev executables come from the `Windows Desktop Dev` and `Linux Dev` presets, which add the `cheats` feature tag. Both executables use the real save file.

## Reporting a bug

Open an issue with the bug report form and include:
- what happened and what you expected;
- the game seed (shown in the pause menu);
- a screenshot;
- if there is one, the error log: `%APPDATA%\Last Lantern Godot\logs\godot.log` on Windows, `~/.local/share/Last Lantern Godot/logs/godot.log` on Linux.

## Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). In short: be kind and constructive, criticize the code, not the people. Security problems go through [SECURITY.md](SECURITY.md).

## License

By contributing you agree that your work is distributed under the project's [MIT license](LICENSE).
