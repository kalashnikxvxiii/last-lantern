# AGENTS.md

Rules for anyone (people or AI agents) changing code or history in this repository. [CONTRIBUTING.md](CONTRIBUTING.md) has the full guide and [docs/porting-conventions.md](docs/porting-conventions.md) the JS → GDScript rules: this file is the short list of what must always hold, plus the traps that are easy to fall into.

## The project in one paragraph

Last Lantern is a 2D pixel-art roguelike. `js/` is the original JavaScript game and the **reference for behavior**: only beta bugs are fixed there. `godot/` is the Godot 4.7.2 port, where development happens. Ported gameplay code must do exactly what the JS does; tests compare the two through the reference data in `godot/tests/golden/`.

## Language

- Code, comments, commit messages, PRs, docs and in-game text: **English**.
- Game text is copied verbatim from the JS when it exists, color codes (`^y`, `^r`…) included.
- Translations live in `godot/locale/strings.json`, keyed by the English text. A new or changed game text needs its entry for every language; text built from pieces uses `Loc.f` templates (see CONTRIBUTING.md).

## Git workflow

1. **Start from an up-to-date `dev`.** Run `git fetch origin` first, then branch from `origin/dev`: `git checkout -b short-name origin/dev`. Never branch from another feature branch, from `master` or from a stale local `dev`. Pull requests go to `dev`; only `dev` is merged into `master`, with a merge commit, when a version is ready.
2. **One topic per branch.** Do not mix unrelated changes. If you notice something unrelated that needs fixing, do it on its own branch.
3. **Small, focused commits.** Each commit should change one thing. Make the message a short sentence saying what changes, in the style of the existing history ("Ghoul: the charge stops against rocks"). Keep the first line within about 72 characters.
4. **No AI attribution.** No `Co-Authored-By` lines and no references to AI tools in commits or PRs.
5. **Commit and push only when asked.** Before pushing, check:
   - `git log --oneline origin/dev..HEAD` lists only your commits;
   - `git status` is clean (no forgotten files, nothing unrelated staged).
6. **Force pushes:** only on your own branch, only with `--force-with-lease`, and only to clean up history before review. Never on `dev` or `master`.
7. **`dev` and `master` are protected** (`.github/rulesets/`): no force pushes, changes only through pull requests, linear history on `dev`. A pull request into `master` must come from `dev`. The PR title must be 10-72 characters. Fill in the template in `.github/PULL_REQUEST_TEMPLATE.md`.
8. **Leave other branches alone.** Do not delete or rewrite branches you did not create.

## Before every commit

- `tools/test.sh` passes (`tools/test.sh --only=<name>` while iterating).
- If you changed `js/` or `tools/golden/gen.js`, run `node tools/golden/gen.js` and commit the regenerated files. CI fails if `godot/tests/golden/` is out of date, untracked files included.
- Every new `.gd` file has its `.gd.uid` committed next to it. Godot creates it on import: run `godot --headless --path godot --import` (`tools/test.sh` does this too).
- Files use LF line endings and UTF-8 (`.editorconfig`). GDScript, `.tscn`, `.tres` and `.cfg` files use tabs.
- **New Markdown files are ignored by `.gitignore`.** Add a `!name.md` line to `.gitignore` for each one you mean to track.

## Code conventions (Godot)

- **Faithful to the JS.** Same update order, same formulas, same random draws in the same order. Follow every rule in [docs/porting-conventions.md](docs/porting-conventions.md); the ones most often broken:
  - `U.random()` / `U.rnd()` / seeded `RNG` in game logic, never `randf()`/`randi()`; `Fx.vrnd()` in drawing code;
  - `U.jround()` instead of `round()`;
  - `is_same(a, b)` to compare object identity (`==` compares contents of dictionaries and arrays);
  - loop by index over lists that grow during the loop (`Run.fx`, `Run.bullets`, `Run.enemies`);
  - logical coordinates as separate `float`s, not `Vector2`.
- **Types:** give an explicit type wherever inference would produce `Variant`. `var a := U.ang_to(...) + x` fails to parse when the right side is untyped: write `var a: float = ...`.
- **Naming:** `snake_case` for variables and functions. Dictionary keys that mirror JS objects (stats, rooms, effects, projectiles) stay camelCase so they compare with the golden data.
- **Data order matters.** `Perks.ALL`, `Relics.ALL` and the other tables are iterated in insertion order, which drives the random draws. Append new entries at the end, never reorder.
- **Data Resources** (`godot/data/enemies|bosses|biomes|lanterns/*.tres`) mirror the tables in `js/data.js`. Integer fields that are used as loop counts (`n`, `count`, `cap`, `arms`, `ring`, `burst`, `split_n`, `land_ring`) must stay integers; the other numbers are floats.
- Match the surrounding code: comment density, naming, and the habit of citing the JS function a piece of code comes from.

## Tests

- **Write the failing test first, then the change.** New test files are `godot/tests/test_<topic>.gd`, extend `TestCase` and use `check`/`eq`/`near`/`fail`. The `TH` helpers in `tests/helpers.gd` cover runs, rooms and enemies.
- **Script errors fail the test.** Any script error during a test makes it fail, unless the test calls `allow_errors()`.
- **Freed enemies:** enemies removed from `Run.enemies` are freed. Check them with `is_instance_valid(e)` after the ticks that can kill them.
- **Drawing code is never run by the tests** (they are headless). Check visual changes with a screenshot run (next section) and look at the image.
- **`godot --check-only --script ...` is useless here:** it does not load the autoloads and reports false errors. Use `tools/test.sh`.

## Running the game for checks

```bash
godot --path godot -- --test=boss --seed=7 --sim=300 --screenshot=/tmp/shot.png --shot-after=5
```

Arguments: `--test=fight|boss|shop|treasure|elite|shrine|secret`, `--seed=`, `--spawn=rat,ghoul`, `--perks=`, `--relics=`, `--lv=`, `--coins=`, `--lantern=`, `--character=`, `--ardor=`, `--sim=N`, `--fire`, `--pause`, `--map`, `--scene=`, `--cheats`, `--cheat-panel=Player|Build|World` (F1 opens the cheat panel during play, see CONTRIBUTING.md).

**These runs write to the real save file** (`~/.local/share/Last Lantern Godot/save.json` on Linux, `%APPDATA%\Last Lantern Godot\save.json` on Windows). They can bump statistics and unlock lanterns. Back the file up before a session of dev runs and restore it afterwards. The tests use a separate `test_save.json`.

## Do not touch

- `dist/`, `godot/.godot/`, `desktop/node_modules/`: generated, not tracked.
- `godot/assets/` is edited by hand now. Do not run `tools/export_assets/`: it overwrites those edits.
- The JS game (`js/`), except to fix a bug of the beta. Any change there needs regenerated golden data.
