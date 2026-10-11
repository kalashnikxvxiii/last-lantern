# Ultima Lanterna in Godot — Vertical slice: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Portare in Godot 4.7 (GDScript) la Profondità 1 di Ultima Lanterna 0.9.0, giocabile dal titolo fino al guardiano, con lo stesso comportamento del JS verificato da test golden.

**Architecture:** Progetto in `godot/`. Autoload per stato e servizi (`Save`, `Sfx`, `Music`, `Fx`, `Controls`, `Run`, `Game`). Logica portata dal JS in classi statiche (`Flow`, `Combat`, `Effects`, `Bullets`, `Status`, `Coll`, ...) che operano sullo stato di `Run`. Attori (`Player`, `Enemy`, `Boss`) come `Node2D` con coordinate logiche JS e disegno in `_draw()`. Stanze su `TileMapLayer`, buio con shader. Asset esportati una volta dal codice JS con Electron.

**Tech Stack:** Godot 4.7.2 stable (GDScript), Node 24 + `vm` per i dati golden, Electron 43 (già in `desktop/node_modules`) per esportare gli asset, ffmpeg (libvorbis) per la musica.

**Spec:** `docs/superpowers/specs/2026-10-11-godot-port-vertical-slice-design.md`

## Global Constraints

- Godot **4.7.2 stable**, solo GDScript, **nessun addon**.
- Risoluzione interna **480×270**, `stretch_mode = viewport`, `aspect = keep`, scala intera, filtro `nearest`; finestra iniziale **1440×810**, minima 480×270.
- Logica a **60 tick fissi al secondo** (`Consts.DT = 1.0 / 60.0`), al massimo 6 tick per frame.
- `Consts.VERSION = "godot 0.1.0"`.
- Tutti i testi visibili sono **identici al JS** (italiano, stessa punteggiatura e codici colore `^x`).
- Tutta la casualità di gioco passa da `U.random()` / `RNG`; mai `randf()`, `randi()` o `RandomNumberGenerator`.
- Salvataggio in `user://save.json` con lo schema di `Save.defaults()` del JS; i test usano `user://test_save.json`.
- Variabili e funzioni GDScript in `snake_case`; le **chiavi dei dizionari** che rispecchiano oggetti JS (stats, stanze, piani, fx, proiettili, pickup, oggetti, stati) restano **identiche al JS** (camelCase), per confrontarle con i golden.
- Commenti in italiano, densità simile al JS.
- Prima di ogni esecuzione dei test o del gioco: `godot --headless --path godot --import` (registra le `class_name`). Lo script `tools/test.sh` lo fa da solo.
- Commit con il trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Perdita del focus della finestra** durante morte, pannelli o schermate: come nel JS, la pausa automatica si apre solo nella scena di gioco in modalità `play` con il giocatore vivo e senza vittoria in corso. Test in Task 25 (`test_screens.gd::test_autopause_only_in_active_play`).
2. **Salvataggio impossibile da scrivere** (cartella non scrivibile, disco pieno): il gioco continua senza errori e senza perdere i dati in memoria. Test in Task 4 (`test_save.gd::test_write_failure_is_silent`).
3. **Caratteri senza glifo** nei testi (apostrofo tipografico, maiuscole accentate non disegnate, simboli): devono usare il ripiego del JS (maiuscola/minuscola, poi `?`) senza rompere misura e impaginazione. Test in Task 5 (`test_text.gd::test_missing_glyph_fallback`).
4. **Passaggio tra mouse e gamepad** a metà partita: la mira segue l'ultimo dispositivo usato (mouse solo se è l'ultimo o se il tasto sinistro è premuto, altrimenti stick o frecce). Test in Task 9 (`test_controls.gd::test_aim_follows_last_device`).
5. **Cursore del mouse**: come nel JS, nascosto solo nella scena di gioco in modalità `play` (al suo posto il mirino), visibile in pausa, pannelli, menu e game over. Test in Task 23 (`test_hud.gd::test_cursor_hidden_only_in_play`).

---

## Convenzioni del porting

Il codice JS in `js/` è la **fonte di verità** del comportamento. Quando un passo dice «Porta `js/file.js:A-B`», il codice GDScript deve fare esattamente ciò che fanno quelle righe, con le regole sotto. Il passo dà comunque firma, campi e punti non meccanici. Per il codice nuovo (architettura Godot, test, strumenti) il piano dà il codice completo.

### Regole di traduzione JS → GDScript

| JS | GDScript |
|---|---|
| `Math.random()` | `U.random()` |
| `rnd(a)`, `rnd(a, b)`, `rndi`, `pick`, `chance`, `shuffle`, `weightedPick` | `U.rnd`, `U.rndi`, `U.pick`, `U.chance`, `U.shuffle`, `U.weighted_pick` |
| `Math.round(v)` | `U.jround(v)` (il `round()` di Godot porta -2.5 a -3, il JS a -2) |
| `Math.floor/ceil(v)` usato come indice | `int(floor(v))` / `int(ceil(v))` |
| `x \| 0` | `int(x)` (troncamento verso zero) |
| `Math.hypot(a, b)` | `sqrt(a * a + b * b)` |
| `Math.min/max` | `minf/maxf` (float), `mini/maxi` (int) |
| `a % b` su float | `fmod(a, b)` (stesso segno del JS) |
| `o.k \|\| d` su campi opzionali | `o.get("k", d)`; mai affidarsi alla «verità» di `0`, `""`, `null`: scrivere il confronto esplicito |
| `arr.filter(f)` / `some` / `every` | `arr.filter(f)` / `arr.any(f)` / `arr.all(f)` |
| `push`, `shift`, `splice(i, 1)` | `append`, `pop_front`, `remove_at(i)` |
| `new Set()` | `Dictionary` usato come insieme (`s[k] = true`, `s.has(k)`): conserva l'ordine di inserimento come il JS |
| `Object.keys(T)` di una tabella dati | `T.keys()` (ordine di inserimento identico: **non riordinare mai le tabelle**) |
| `for (const k in o)` con `delete o[k]` dentro | `for k in o.keys():` (copia delle chiavi) |
| `arr.sort((a, b) => ...)` | `sort_custom`, che **non è stabile**: se il JS dipende dall'ordine dei pari, aggiungere l'indice originale come spareggio |
| colori `'#rrggbb'` | `Color("#rrggbb")` |
| colori `'rgba(r,g,b,a)'` | `U.rgba(r, g, b, a)` |
| `ctx.save(); ctx.globalAlpha = a; ...; ctx.restore()` | `var ga := UiDraw.alpha; UiDraw.alpha = a; ...; UiDraw.alpha = ga` (se il JS usa `*=`, usare `*=`) |
| `setTimeout(fn, ms)` | `U.later(ms / 1000.0, fn)` |
| `Render.time` | `Fx.time` |
| `rnd`, `Math.random` dentro le funzioni di disegno (`draw*`) | `Fx.vrnd(a, b)` o `Fx.vis.next()`: il disegno non deve consumare la casualità di gioco |
| `switch (x) { case 'a': ...; break; }` | `match x: "a": ...` (nessuna caduta tra i casi) |
| accesso fuori dai limiti di un array (in JS dà `undefined`) | controllare i limiti prima: in GDScript è un errore |
| `for (const x of arr)` su un array a cui il corpo del ciclo aggiunge elementi (`run.fx`, `run.bullets`, `run.enemies`) | ciclo per indice con la dimensione ricalcolata (`var i := 0` / `while i < arr.size()`): come nel JS, anche gli elementi aggiunti durante il ciclo vengono visitati nello stesso tick |
| `a === b` tra oggetti JS (stanze, fx, pickup) | `is_same(a, b)`: in GDScript `==` tra `Dictionary` o `Array` confronta il **contenuto**; lo stesso vale per `Array.has`, `erase`, `find` |
| coordinate e valori logici | `float` separati (`x`, `y`): `Vector2` è a 32 bit e perde precisione; si usa solo per valori esatti (centri dei tile) o per il disegno |

### Mappa dei nomi principali

| JS | GDScript |
|---|---|
| `new RNG(s)`, `rng.range`, `rng.int` | `RNG.new(s)`, `rng.frange`, `rng.rint` |
| `run` | autoload `Run` (`Run.active` sostituisce `run !== null`) |
| `run.player` | `Run.player: Player` |
| `newPlayer`, `recalcStats`, `pDamage`, `pFireRate`, `pSpeed`, `pLight` | `Player.new()`, `p.recalc_stats()`, `p.damage()`, `p.fire_rate()`, `p.speed()`, `p.light()` |
| `healPlayer`, `addOil`, `addCoins`, `giveCons`, `useCons`, `addXP`, `canTakeCons` | `p.heal()`, `p.add_oil()`, `p.add_coins()`, `p.give_cons()`, `p.use_cons()`, `p.add_xp()`, `p.can_take_cons()` |
| `addStatus`, `updateStatuses`, `cleanse` | `Status.add`, `Status.update`, `Status.cleanse` |
| `collides`, `moveAxis`, `moveActor`, `lineClear`, `nudge` | `Coll.collides`, `Coll.move_axis`, `Coll.move_actor`, `Coll.line_clear`, `Coll.nudge` |
| `updateFlow`, `flowAngle` | `FlowField.update`, `FlowField.angle` |
| `hurtPlayer`, `playerDeath`, `hitEnemy`, `killEnemy`, `chainLightning`, `damageTile`, `freezeAll` | `Combat.hurt_player`, `Combat.player_death`, `Combat.hit_enemy`, `Combat.kill_enemy`, `Combat.chain_lightning`, `Combat.damage_tile`, `Combat.freeze_all` |
| `addFx`, `placeBomb`, `updateFx`, `explosionHit` | `Effects.add`, `Effects.place_bomb`, `Effects.update`, `Effects.explosion_hit` |
| `eShoot`, `updateBullets`, `updateEnemyBullets`, `bulletColor` | `Bullets.e_shoot`, `Bullets.update_player`, `Bullets.update_enemy`, `Bullets.color_of` |
| `makeEnemy`, `makeBoss` | `Enemy.make`, `Boss.make` |
| `makePickup`, `updatePickups`, `collectPickup`, `randomCons` | `Pickups.make`, `Pickups.update`, `Pickups.collect`, `Pickups.random_cons` |
| `genFloor`, `buildRoom` | `FloorGen.gen_floor`, `RoomBuilder.build_room` |
| `startRun`, `newFloor`, `enterRoom`, `updateRoomFlow`, `checkDoors`, `updateGame`, `updateCommon` | `Flow.start_run`, `Flow.new_floor`, `Flow.enter_room`, `Flow.update_room_flow`, `Flow.check_doors`, `Flow.update_game`, `Flow.update_common` |
| `toast`, `banner` | `Run.toast`, `Run.banner` |
| `Sound.play`, `Music.play`, `Music.setIntensity` | `Sfx.play`, `Music.play`, `Music.set_intensity` |
| `shake`, `hitstop`, `screenFlash` | `Fx.shake`, `Fx.hitstop`, `Fx.screen_flash` |
| `Font.draw`, `Font.width`, `Font.wrap`, `Font.drawWrapped` | `UiDraw.text`, `Txt.width`, `Txt.wrap`, `UiDraw.text_wrapped` |
| `drawSpr`, `pxRect`, `pxCircle`, `pxRing`, `shadow`, `glow`, `panel`, `keycap`, `bar` | `Spr.draw`, `UiDraw.px_rect`, `UiDraw.px_circle`, `UiDraw.px_ring`, `UiDraw.shadow`, `UiDraw.glow`, `UiDraw.panel`, `UiDraw.keycap`, `UiDraw.bar` |
| `setScene` | `Game.set_scene` |
| `class Menu`, `makeOptionsMenu` | `Menu`, `Panels.make_options_menu` |
| `drawPerkCards`, `buildEntries`, `drawBuildPanel`, `drawStatsPanel`, `runSummaryRows`, `drawSummary`, `drawIconsRow` | `PanelsDraw.perk_cards`, `.build_entries`, `.build_panel`, `.stats_panel`, `.summary_rows`, `.summary`, `.icons_row` |
| `drawMinimap`, `drawFullMap`, `roomKnown`, `drawNotices`, `drawHUD` | `MapDraw.minimap`, `MapDraw.full_map`, `MapDraw.room_known`, `Notices.draw`, `Hud._hud` |
| `drawWellBackground`, `updateEmbers`, `drawBigLantern` | `WellBg.draw`, `WellBg.update_embers`, `WellBg.big_lantern` |
| `Input`, `Act` | autoload `Controls` |

### Comandi

- Test: `tools/test.sh` (tutti) oppure `tools/test.sh --only=core` (file o funzioni che contengono `core`).
- Gioco: `godot --path godot` (dopo `--import`), con argomenti di sviluppo dopo `--`, ad esempio `godot --path godot -- --test=fight --seed=7`.
- Screenshot per il confronto visivo: `godot --path godot -- --test=fight --seed=7 --sim=120 --screenshot=/tmp/ul.png`.

---

## Mappa dei file

```
tools/test.sh                         import + test runner
tools/golden/gen.js                   dati golden dal JS (Node vm)
tools/export_assets/{main,preload,export}.js, export.html   esportazione asset (Electron)

godot/project.godot
godot/autoload/{save,sfx,music,fx,controls,run,game}.gd
godot/core/{consts,util,rng,spr,txt}.gd
godot/data/{enemy_def,boss_def,biome_def,lantern_def,db,stats,perks,relics,curses,consumables,statuses,elite_mods}.gd
godot/data/enemies/{rat,bat,skeleton,skull,ghoul}.tres
godot/data/bosses/bones.tres
godot/data/biomes/crypt.tres
godot/data/lanterns/{custode,pellegrino,spezzata,cava,nera}.tres
godot/world/{tile_pick,room_util,floor_gen,room_builder,room_view,lights,lighting,flow,interact,draw_ground,draw_air,draw_overlay}.gd
godot/actors/{player,enemy,ai,boss,boss_patterns}.gd   (create con .new(): nessuna scena .tscn)
godot/combat/{collision,flow_field,status,combat,effects,bullets,pickups,particles,floaters}.gd
godot/ui/{ui_draw,menu,notices,map_draw,panels_draw,hud,panels,well_bg}.gd
godot/ui/screens/{boot,title,options,select,records,help,gameover,demo_end}.{tscn,gd}
godot/scenes/play.tscn, play.gd
godot/shaders/{darkness,glow,vignette}.gdshader
godot/tools/build_tilesets.gd
godot/assets/{sprites,tiles,font,sfx,music}/   (generati)
godot/tests/test_main.tscn, run_tests.gd, test_case.gd, helpers.gd, test_*.gd, golden/*.json
```

---

## Fase A — Fondamenta

### Task 1: Progetto Godot e test runner

**Files:**
- Create: `godot/project.godot`
- Create: `godot/tests/test_case.gd`, `godot/tests/run_tests.gd`, `godot/tests/test_main.tscn`, `godot/tests/test_runner_selftest.gd`
- Create: `tools/test.sh`

**Interfaces:**
- Produces: `TestCase` con `check(cond, msg)`, `eq(a, b, msg)`, `near(a, b, eps, msg)`, `fail(msg)`, `allow_errors()`, `static golden(name) -> Variant`, `before()` e `after()` sovrascrivibili; runner `res://tests/test_main.tscn` con filtro `--only=`.

- [ ] **Step 1: Scrivere il test di autoverifica del runner**

`godot/tests/test_runner_selftest.gd`:
```gdscript
extends TestCase
# Verifica gli strumenti di test stessi.

func test_eq_tolera_int_e_float() -> void:
	eq(3, 3.0)
	eq({"a": [1, 2.0, {"b": true}]}, {"a": [1.0, 2, {"b": true}]})

func test_eq_rileva_differenze() -> void:
	check(TestCase.diff([1, 2], [1, 3], "x") != "", "deve rilevare elementi diversi")
	check(TestCase.diff({"a": 1}, {"a": 1, "b": 2}, "x") != "", "deve rilevare chiavi mancanti")
	check(TestCase.diff(1.0, 1.0 + 1e-12, "x") == "", "tolleranza numerica")
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `godot --headless --path godot res://tests/test_main.tscn`
Expected: errore, il progetto e il runner non esistono ancora.

- [ ] **Step 3: Creare progetto, classe base e runner**

`godot/project.godot`:
```ini
; Ultima Lanterna - porting Godot

config_version=5

[application]

config/name="Ultima Lanterna"
config/features=PackedStringArray("4.7")

[debug]

file_logging/enable_file_logging=true

[display]

window/size/viewport_width=480
window/size/viewport_height=270
window/size/window_width_override=1440
window/size/window_height_override=810
window/stretch/mode="viewport"
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"

[physics]

common/physics_ticks_per_second=60
common/max_physics_steps_per_frame=6

[rendering]

textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
environment/defaults/default_clear_color=Color(0.0196, 0.0118, 0.0314, 1)
```

`godot/tests/test_case.gd`:
```gdscript
class_name TestCase
extends RefCounted
# Base dei test: asserzioni con confronto profondo e tolleranza numerica.

var failures: Array[String] = []
var errors_allowed := false

func before() -> void:
	pass

func after() -> void:
	pass

func allow_errors() -> void:
	errors_allowed = true

func fail(msg: String) -> void:
	failures.append(msg)

func check(cond: bool, msg: String = "condizione falsa") -> void:
	if not cond:
		fail(msg)

func eq(a: Variant, b: Variant, msg: String = "") -> void:
	var d := TestCase.diff(a, b, "")
	if d != "":
		fail((msg + ": " if msg != "" else "") + d)

func near(a: float, b: float, eps: float = 1e-9, msg: String = "") -> void:
	if absf(a - b) > eps * maxf(1.0, absf(b)):
		fail("%s atteso %s, ottenuto %s" % [msg, b, a])

static func _num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

# "" se uguali, altrimenti la descrizione della prima differenza.
static func diff(a: Variant, b: Variant, path: String) -> String:
	if _num(a) and _num(b):
		var fa := float(a)
		var fb := float(b)
		if absf(fa - fb) <= 1e-9 * maxf(1.0, absf(fb)):
			return ""
		return "%s: %s != %s" % [path, fa, fb]
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s: lunghezza %d != %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	if a is Dictionary and b is Dictionary:
		for k in b:
			if not a.has(k):
				return "%s.%s: chiave mancante" % [path, k]
		for k in a:
			if not b.has(k):
				return "%s.%s: chiave in più" % [path, k]
			var d := diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		return ""
	if typeof(a) != typeof(b) or a != b:
		return "%s: %s != %s" % [path, a, b]
	return ""

static func golden(name: String) -> Variant:
	var txt := FileAccess.get_file_as_string("res://tests/golden/%s.json" % name)
	var j := JSON.new()
	if j.parse(txt) != OK:
		push_error("golden %s non leggibile" % name)
		return null
	return j.data
```

`godot/tests/run_tests.gd`:
```gdscript
extends Node
# Esegue le funzioni test_* dei file tests/test_*.gd.
# Un test fallisce se registra un fallimento o se durante la sua esecuzione
# compare un errore di script (catturato dal Logger), salvo allow_errors().

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

var catcher := ErrorCatcher.new()

func _ready() -> void:
	OS.add_logger(catcher)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	if has_node("/root/Save"):
		get_node("/root/Save").set("path", "user://test_save.json")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
		get_node("/root/Save").call("load_save")
	var passed := 0
	var failed: Array[String] = []
	var files := Array(DirAccess.get_files_at("res://tests")).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			if only != "" and not (f.contains(only) or name.contains(only)):
				continue
			var t: TestCase = script.new()
			catcher.errors.clear()
			await t.before()
			await t.call(name)
			await t.after()
			var errs := [] if t.errors_allowed else catcher.errors.duplicate()
			if t.failures.is_empty() and errs.is_empty():
				passed += 1
			else:
				failed.append("%s::%s\n    %s" % [f, name, "\n    ".join(t.failures + errs)])
	for line in failed:
		print("FAIL ", line)
	print("\n%d superati, %d falliti" % [passed, failed.size()])
	get_tree().quit(1 if failed.size() > 0 else 0)
```

`godot/tests/test_main.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/run_tests.gd" id="1"]

[node name="TestMain" type="Node"]
script = ExtResource("1")
```

`tools/test.sh`:
```bash
#!/usr/bin/env bash
# Importa il progetto Godot (registra le class_name) ed esegue i test.
# Uso: tools/test.sh [--only=filtro]
set -euo pipefail
cd "$(dirname "$0")/../godot"
godot --headless --path . --import >/dev/null 2>&1 || true
exec godot --headless --path . res://tests/test_main.tscn -- "$@"
```
Poi `chmod +x tools/test.sh`.

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh`
Expected: `3 superati, 0 falliti`, codice di uscita 0.

- [ ] **Step 5: Commit**

```bash
git add godot/project.godot godot/tests tools/test.sh
git commit -m "Godot: progetto e test runner

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Generatore dei dati golden

Esegue il codice JS originale in una sandbox `vm` di Node e salva i risultati che i test Godot confronteranno. Si genera tutto in questo task; i test che li usano arrivano nei task successivi.

**Files:**
- Create: `tools/golden/gen.js`
- Create (generati): `godot/tests/golden/{rng,util,floors,rooms,stats,formulas,enemies,movement}.json`

**Interfaces:**
- Produces (formato dei file, usato dai Task 3, 11, 12, 13, 15, 18):
  - `rng.json`: `[{seed, values: [1000 float]}]` per i semi `1, 42, 123456789, 2147483647, 4294967295`.
  - `util.json`: `{hash2: [[x, y, s, v]], imul: [[a, b, v]], round: [[x, v]], time: [[s, str]], seq: {seed, rnd, rnd10, rnd37, rndi29, pick, chance, shuffle, weighted}}`.
  - `floors.json`: `[{depth, seed, start: "gx,gy", rooms: [{key, gx, gy, type, dist, seed, cleared, found, locked, doors: {dir: "gx,gy"}}]}]`.
  - `rooms.json`: `[{seed, rooms: [{key, type, grid, tileHp, doorDir, objects, pickups, decals, waves, tutorial, reach}]}]`.
  - `stats.json`: `{cases: [{lantern, perks, relics, curses, ardore, baseHpMod, stats, derived: [{statuses, hpFrac, oilFrac, damage, fireRate, speed, light}]}], perkRolls: [{seed, perks, luck, depth, n, minRar, out}]}`.
  - `formulas.json`: `{xpNeed: [[L, v]], depthHp: [[d, v]], depthDmg: [[d, v]], basePrice: [[kind, id, depth, v]], hurt: [[amount, dmgTaken, armor, fragile, oilEmpty, v]]}`.
  - `enemies.json`: `{enemies: [{seed, type, depth, mod, small, fields}], bosses: [{seed, id, depth, fields}]}`.
  - `movement.json`: `{traces: [{seed, open, start: [x, y], steps: [[dx, dy, x, y, hit]]}], flow: [{seed, player: [x, y], probes: [[ex, ey, angle]]}], lines: [{seed, cases: [[x0, y0, x1, y1, clear]]}]}`.

- [ ] **Step 1: Scrivere lo script**

`tools/golden/gen.js`:
```js
'use strict';
// Genera i dati golden per i test del porting Godot eseguendo il codice JS originale.
// Uso: node tools/golden/gen.js
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'godot', 'tests', 'golden');
const FILES = ['core.js', 'font.js', 'gfx.js', 'sprites.js', 'audio.js', 'data.js', 'dungeon.js', 'entities.js', 'render.js', 'ui.js', 'game.js'];

const noop = () => {};
const ctx = {
  console, URLSearchParams,
  window: { addEventListener: noop },
  document: { getElementById: () => null, createElement: () => ({ getContext: () => null }) },
  localStorage: { getItem: () => null, setItem: noop },
  navigator: {}, performance: { now: () => 0 },
  addEventListener: noop, requestAnimationFrame: noop, setTimeout: noop, innerWidth: 480, innerHeight: 270,
};
vm.createContext(ctx);
for (const f of FILES) vm.runInContext(fs.readFileSync(path.join(ROOT, 'js', f), 'utf8'), ctx, { filename: f });

// codice eseguito dentro la sandbox: vede le dichiarazioni globali dei file JS
const HARNESS = String.raw`
Save.load();
function seedRandom(s) { const r = new RNG(s); Math.random = () => r.next(); }
function makeRun(lantern) {
  run = { player: newPlayer(lantern || 'custode'), offeredRelics: new Set(), ardore: 0, depth: 1, room: null,
    enemies: [], bullets: [], ebullets: [], fx: [], toasts: [], banners: [], kills: 0, dmgDealt: 0, dmgTaken: 0, coinsTotal: 0 };
  return run;
}
const key = r => r.gx + ',' + r.gy;

function genRng() {
  return [1, 42, 123456789, 2147483647, 4294967295].map(seed => {
    const r = new RNG(seed); const values = [];
    for (let i = 0; i < 1000; i++) values.push(r.next());
    return { seed, values };
  });
}

function genUtil() {
  const r = new RNG(7);
  const h = [];
  for (let i = 0; i < 300; i++) { const x = r.int(-50, 600), y = r.int(-50, 400), s = r.int(0, 1100); h.push([x, y, s, hash2(x, y, s)]); }
  h.push([0, 0, 0, hash2(0, 0)]);
  const im = [];
  for (let i = 0; i < 200; i++) { const a = r.int(0, 4294967295), b = r.int(0, 4294967295); im.push([a, b, Math.imul(a, b)]); }
  const xs = [-2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 0.49999999, -0.50000001, 3.7, -3.7, 0, 1e6 + 0.5];
  for (let i = 0; i < 50; i++) xs.push(r.range(-1000, 1000));
  const round = xs.map(x => [x, Math.round(x)]);
  const time = [0, 5, 59.9, 60, 61, 125.5, 3599, 3600].map(s => [s, fmtTime(s)]);
  seedRandom(5);
  const seq = { seed: 5, rnd: rnd(), rnd10: rnd(10), rnd37: rnd(3, 7), rndi29: rndi(2, 9), pick: pick(['a', 'b', 'c', 'd']),
    chance: chance(0.3), shuffle: shuffle([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    weighted: weightedPick([['x', 1], ['y', 3], ['z', 0.5]], k => k[1])[0] };
  return { hash2: h, imul: im, round, time, seq };
}

function floorJson(depth, seed) {
  const f = genFloor(depth, new RNG(seed));
  return {
    depth, seed, start: key(f.start),
    rooms: f.rooms.map(r => ({ key: key(r), gx: r.gx, gy: r.gy, type: r.type, dist: r.dist, seed: r.seed,
      cleared: !!r.cleared, found: !!r.found, locked: !!r.locked,
      doors: Object.fromEntries(Object.entries(r.doors).map(([d, n]) => [d, key(n)])) }))
  };
}
function genFloors() {
  const out = [];
  for (let s = 1; s <= 50; s++) out.push(floorJson(1, s));
  for (let s = 1; s <= 10; s++) { out.push(floorJson(2, s)); out.push(floorJson(3, s)); }
  return out;
}

function genRooms() {
  const out = [];
  for (let s = 1; s <= 20; s++) {
    seedRandom(s * 7919);
    makeRun();
    const f = genFloor(1, new RNG(s));
    const rooms = [];
    for (const r of f.rooms) {
      buildRoom(r, f);
      rooms.push({ key: key(r), type: r.type, grid: r.grid, tileHp: r.tileHp, doorDir: r.doorDir,
        objects: r.objects, pickups: r.pickups, decals: r.decals, waves: r.waves, tutorial: !!r.tutorial,
        reach: r.reach ? [...r.reach] : null });
    }
    out.push({ seed: s, rooms });
  }
  return out;
}

function statCase(lantern, perks, relics, curses, ardore, baseHpMod) {
  makeRun(lantern);
  run.ardore = ardore;
  const p = run.player;
  p.perks = perks; p.relics = relics; p.curses = curses; p.baseHpMod = baseHpMod;
  p.hp = 9999; p.oil = 9999; p.dashCharges = 99;
  recalcStats();
  const derived = [];
  for (const st of [{}, { rage: {} }, { weak: {} }, { fury: {} }, { slow: {}, chill: {} }, { blind: {} }]) {
    for (const [hf, of] of [[1, 1], [0.3, 0.5], [0.1, 0]]) {
      p.statuses = st; p.hp = p.stats.maxHp * hf; p.oil = p.stats.maxOil * of;
      derived.push({ statuses: Object.keys(st), hpFrac: hf, oilFrac: of, damage: pDamage(p), fireRate: pFireRate(p), speed: pSpeed(p), light: pLight(p) });
    }
  }
  return { lantern, perks, relics, curses, ardore, baseHpMod, stats: p.stats, derived };
}
function genStats() {
  const cases = [];
  for (const L of LANTERNS) cases.push(statCase(L.id, {}, [], [], 0, 0));
  for (const id in PERKS) { cases.push(statCase('custode', { [id]: 1 }, [], [], 0, 0)); cases.push(statCase('custode', { [id]: PERKS[id].max }, [], [], 0, 0)); }
  for (const id in RELICS) cases.push(statCase('custode', {}, [id], [], 0, 0));
  for (const id in CURSES) cases.push(statCase('custode', {}, [], [id], 0, 0));
  const r = new RNG(99);
  const pk = Object.keys(PERKS), rk = Object.keys(RELICS), ck = Object.keys(CURSES), lk = LANTERNS.map(l => l.id);
  for (let i = 0; i < 30; i++) {
    const perks = {};
    for (let k = 0; k < r.int(0, 8); k++) { const id = r.pick(pk); perks[id] = Math.min(PERKS[id].max, (perks[id] || 0) + 1); }
    const relics = r.shuffle(rk.slice()).slice(0, r.int(0, 4));
    const curses = r.shuffle(ck.slice()).slice(0, r.int(0, 3));
    cases.push(statCase(r.pick(lk), perks, relics, curses, r.int(0, 5), r.chance(0.3) ? -15 : 0));
  }
  const perkRolls = [];
  for (let s = 1; s <= 12; s++) {
    seedRandom(s * 31);
    makeRun();
    const p = run.player;
    p.perks = s % 3 === 0 ? { dmg: 5, rate: 2 } : {};
    if (s % 4 === 0) p.relics = ['r_clover'];
    run.depth = 1 + (s % 3);
    recalcStats();
    const n = 3 + p.stats.extraChoice, minRar = s % 5 === 0 ? 1 : 0;
    perkRolls.push({ seed: s * 31, perks: p.perks, relics: p.relics, depth: run.depth, n, minRar, out: rollPerkChoices(n, minRar) });
  }
  return { cases, perkRolls };
}

function genFormulas() {
  const xp = [], dh = [], dd = [], bp = [], hurt = [];
  for (let L = 1; L <= 40; L++) xp.push([L, xpNeed(L)]);
  for (let d = 1; d <= 12; d++) { dh.push([d, depthHp(d)]); dd.push([d, depthDmg(d)]); }
  for (let d = 1; d <= 6; d++) {
    for (const id in CONS) bp.push(['cons', id, d, basePrice({ kind: 'cons', id }, d)]);
    bp.push(['heal', '', d, basePrice({ kind: 'heal' }, d)]);
    bp.push(['key', '', d, basePrice({ kind: 'key' }, d)]);
    bp.push(['relic', '', d, basePrice({ kind: 'relic', id: 'r_eye' }, d)]);
  }
  const r = new RNG(3);
  for (let i = 0; i < 100; i++) {
    const amount = r.range(1, 40), dmgTaken = r.pick([1, 1.2, 1.44]), armor = r.int(0, 12), fragile = r.chance(0.3), oilEmpty = r.chance(0.3);
    // stessa formula di hurtPlayer (js/entities.js)
    let dmg = amount * dmgTaken * (1 - Math.min(0.6, armor * 0.07));
    if (fragile) dmg *= 1.3;
    if (oilEmpty) dmg *= 1.25;
    hurt.push([amount, dmgTaken, armor, fragile, oilEmpty, Math.max(1, Math.round(dmg))]);
  }
  return { xpNeed: xp, depthHp: dh, depthDmg: dd, basePrice: bp, hurt };
}

function genEnemies() {
  const enemies = [], bosses = [];
  const F = ['hp', 'maxHp', 'spd', 'dmg', 'xp', 'r', 'fly', 'shotCd', 'anim', 't', 'stun', 'elite', 'mod'];
  let seed = 1;
  for (const type of ['rat', 'bat', 'skeleton', 'skull', 'ghoul']) for (let depth = 1; depth <= 3; depth++)
    for (const mod of [null, ...Object.keys(ELITE_MODS)]) for (const small of [false, true]) {
      seedRandom(seed); makeRun(); run.depth = depth; recalcStats();
      const e = makeEnemy(type, 100, 100, mod, small ? { small: true } : {});
      const fields = {}; for (const k of F) fields[k] = e[k] === undefined ? null : e[k];
      fields.elite = !!e.elite;
      enemies.push({ seed, type, depth, mod, small, fields }); seed++;
    }
  for (let depth = 1; depth <= 2; depth++) {
    makeRun(); run.depth = depth;
    const b = makeBoss('bones', 100, 100);
    bosses.push({ id: 'bones', depth, fields: { hp: b.hp, maxHp: b.maxHp, spd: b.spd, dmg: b.dmg, xp: b.xp, r: b.r } });
  }
  return { enemies, bosses };
}

function genMovement() {
  const traces = [], flow = [], lines = [];
  for (let s = 1; s <= 10; s++) {
    seedRandom(s); makeRun();
    const f = genFloor(1, new RNG(s));
    const room = f.rooms.find(r => r.type === 'normal');
    buildRoom(room, f);
    run.room = room;
    for (const open of [true, false]) {
      room.cleared = open; room.combat = !open;
      const c = tileCenter(14, 7);
      const a = { x: c.x, y: c.y + 20, r: 4 };
      const start = [a.x, a.y];
      const r = new RNG(1000 + s);
      const steps = [];
      for (let i = 0; i < 400; i++) {
        const axis = r.int(0, 2);
        const dx = axis === 1 ? 0 : r.range(-6, 6), dy = axis === 0 ? 0 : r.range(-6, 6);
        // come updatePlayer: assi separati e scivolamento sugli spigoli
        const bx = moveAxis(a, dx, 0, false);
        const by = moveAxis(a, dy, 1, false);
        if (bx && Math.abs(dy) < 1) nudge(a, 0, dx);
        if (by && Math.abs(dx) < 1) nudge(a, 1, dy);
        steps.push([dx, dy, a.x, a.y, bx || by]);
      }
      traces.push({ seed: s, open, start, steps });
    }
    room.cleared = false; room.combat = true;
    const c = tileCenter(14, 7);
    run.player = Object.assign(run.player, { x: c.x, y: c.y });
    updateFlow();
    const r = new RNG(2000 + s);
    const probes = [];
    for (let i = 0; i < 40; i++) {
      const t = r.pick(reachTiles(room)); const tc = tileCenter(t[0], t[1]);
      const ex = tc.x + r.range(-5, 5), ey = tc.y + r.range(-5, 5);
      probes.push([ex, ey, flowAngle({ x: ex, y: ey }, run.player.x, run.player.y)]);
    }
    flow.push({ seed: s, player: [c.x, c.y], probes });
    const cases = [];
    for (let i = 0; i < 40; i++) {
      const x0 = r.range(RX, RX + RW * TS), y0 = r.range(RY, RY + RH * TS), x1 = r.range(RX, RX + RW * TS), y1 = r.range(RY, RY + RH * TS);
      cases.push([x0, y0, x1, y1, lineClear(x0, y0, x1, y1)]);
    }
    lines.push({ seed: s, cases });
  }
  return { traces, flow, lines };
}

JSON.stringify({ rng: genRng(), util: genUtil(), floors: genFloors(), rooms: genRooms(), stats: genStats(),
  formulas: genFormulas(), enemies: genEnemies(), movement: genMovement() });
`;

const all = JSON.parse(vm.runInContext(HARNESS, ctx, { filename: 'harness.js' }));
fs.mkdirSync(OUT, { recursive: true });
for (const k in all) {
  fs.writeFileSync(path.join(OUT, k + '.json'), JSON.stringify(all[k]));
  console.log('scritto', k + '.json');
}
```

- [ ] **Step 2: Eseguire e controllare l'output**

Run: `node tools/golden/gen.js && ls -la godot/tests/golden && node -e "const r=require('./godot/tests/golden/rooms.json');console.log(r.length, r[0].rooms.length, r[0].rooms[0].grid.length)"`
Expected: 8 file `scritto ...json`; poi `20 <numero stanze> 15`.

Se uno dei generatori lancia un'eccezione (una funzione JS che usa un campo di `run` non previsto in `makeRun`), aggiungere quel campo a `makeRun` e rieseguire: i file JS in `js/` non si modificano.

- [ ] **Step 3: Commit**

```bash
git add tools/golden godot/tests/golden
git commit -m "Dati golden generati dal codice JS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Core — costanti, utilità, RNG

**Files:**
- Create: `godot/core/consts.gd`, `godot/core/rng.gd`, `godot/core/util.gd`
- Test: `godot/tests/test_core.gd`

**Interfaces:**
- Consumes: `rng.json`, `util.json` (Task 2).
- Produces:
  - `Consts`: `VERSION`, `W`, `H`, `TS`, `RW`, `RH`, `RX`, `RY`, `DT`, `enum T { FLOOR, WALL, ROCK, CRACK, SPIKE, BARREL, BRAZIER, DOOR, URN }`.
  - `RNG.new(seed: int)`: `next() -> float`, `frange(a, b) -> float` (il `range` del JS), `rint(a: int, b: int) -> int` (il `int` del JS), `pick(arr)`, `chance(p) -> bool`, `shuffle(arr) -> Array`, `weighted(list, wf: Callable)`.
  - `U` (statiche): `random()`, `seed_random(s)`, `rnd(a = 1.0, b = null)`, `rndi(a, b)`, `pick`, `chance`, `shuffle`, `weighted_pick(list, wf)`, `dist(ax, ay, bx, by)`, `dist2`, `ang_to`, `ang_diff`, `approach`, `jround`, `fmt_time(s) -> String`, `to_int32(v: int)`, `f_to_int32(x: float)`, `imul(a, b)`, `hash2(x: int, y: int, s: int = 0) -> float`, `rgba(r, g, b, a) -> Color`, `later(sec, fn: Callable)`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_core.gd`:
```gdscript
extends TestCase
# Core: RNG e utilità devono coincidere bit per bit con il JS.

func test_rng_identico_al_js() -> void:
	for c in TestCase.golden("rng"):
		var r := RNG.new(int(c.seed))
		for i in c.values.size():
			var v := r.next()
			if v != float(c.values[i]):
				fail("seme %d, uscita %d: %s != %s" % [c.seed, i, v, c.values[i]])
				return

func test_hash2_identico_al_js() -> void:
	for h in TestCase.golden("util").hash2:
		var v := U.hash2(int(h[0]), int(h[1]), int(h[2]))
		if v != float(h[3]):
			fail("hash2(%d,%d,%d) = %s, atteso %s" % [h[0], h[1], h[2], v, h[3]])
			return

func test_imul_identico_al_js() -> void:
	for c in TestCase.golden("util").imul:
		eq(U.imul(int(c[0]), int(c[1])), int(c[2]), "imul(%d,%d)" % [c[0], c[1]])

func test_jround_come_math_round() -> void:
	for c in TestCase.golden("util").round:
		eq(U.jround(float(c[0])), float(c[1]), "round(%s)" % c[0])

func test_fmt_time() -> void:
	for c in TestCase.golden("util").time:
		eq(U.fmt_time(float(c[0])), c[1])

func test_sequenza_casuale_globale() -> void:
	var g: Dictionary = TestCase.golden("util").seq
	U.seed_random(int(g.seed))
	eq(U.rnd(), g.rnd, "rnd()")
	eq(U.rnd(10), g.rnd10, "rnd(10)")
	eq(U.rnd(3, 7), g.rnd37, "rnd(3,7)")
	eq(U.rndi(2, 9), g.rndi29, "rndi(2,9)")
	eq(U.pick(["a", "b", "c", "d"]), g.pick, "pick")
	eq(U.chance(0.3), g.chance, "chance")
	eq(U.shuffle([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]), g.shuffle, "shuffle")
	eq(U.weighted_pick([["x", 1], ["y", 3], ["z", 0.5]], func(k): return k[1])[0], g.weighted, "weighted")

func test_rng_seme_zero_diventa_uno() -> void:
	eq(RNG.new(0).next(), RNG.new(1).next())
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=core`
Expected: errori di parsing, `RNG` e `U` non dichiarati.

- [ ] **Step 3: Implementare**

`godot/core/consts.gd`:
```gdscript
class_name Consts
extends RefCounted
# Costanti condivise (da js/core.js).

const VERSION := "godot 0.1.0"
const W := 480
const H := 270
const TS := 16
const RW := 29   # dimensioni stanza in tile (muri inclusi)
const RH := 15
const RX := 8    # offset della stanza sullo schermo
const RY := 28
const DT := 1.0 / 60.0

enum T { FLOOR, WALL, ROCK, CRACK, SPIKE, BARREL, BRAZIER, DOOR, URN }
```

`godot/core/rng.gd`:
```gdscript
class_name RNG
extends RefCounted
# Generatore pseudo-casuale con seme (mulberry32), identico a RNG in js/core.js.
# Lavora su interi a 32 bit senza segno.

const M32 := 0xFFFFFFFF
var s: int

func _init(seed: int) -> void:
	s = seed & M32
	if s == 0:
		s = 1

func next() -> float:
	s = (s + 0x6D2B79F5) & M32
	var t := s
	t = U.imul(t ^ (t >> 15), t | 1) & M32
	t = (t ^ ((t + (U.imul(t ^ (t >> 7), t | 61) & M32)) & M32)) & M32
	return float((t ^ (t >> 14)) & M32) / 4294967296.0

# range() del JS (il nome range è una funzione globale di GDScript)
func frange(a: float, b: float) -> float:
	return a + next() * (b - a)

# int() del JS
func rint(a: int, b: int) -> int:
	return a + int(floor(next() * (b - a + 1)))

func pick(arr: Array) -> Variant:
	return arr[int(floor(next() * arr.size()))]

func chance(p: float) -> bool:
	return next() < p

func shuffle(arr: Array) -> Array:
	var i := arr.size() - 1
	while i > 0:
		var j := int(floor(next() * (i + 1)))
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		i -= 1
	return arr

func weighted(list: Array, wf: Callable) -> Variant:
	var tot := 0.0
	for it in list:
		tot += wf.call(it)
	var r := next() * tot
	for it in list:
		r -= wf.call(it)
		if r <= 0:
			return it
	return list[list.size() - 1]
```
`godot/core/util.gd`:
```gdscript
class_name U
extends RefCounted
# Utilità portate da js/core.js e js/dungeon.js.
# Tutta la casualità di gioco (Math.random nel JS) passa da U.random(),
# così i test possono fissarne il seme con U.seed_random().

static var rand: RNG = RNG.new(int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF)

static func random() -> float:
	return rand.next()

static func seed_random(s: int) -> void:
	rand = RNG.new(s)

# rnd(a) in [0, a), rnd(a, b) in [a, b)
static func rnd(a: float = 1.0, b: Variant = null) -> float:
	if b == null:
		return random() * a
	return a + random() * (float(b) - a)

static func rndi(a: int, b: int) -> int:
	return int(floor(rnd(a, b + 1)))

static func pick(arr: Array) -> Variant:
	return arr[int(floor(random() * arr.size()))]

static func chance(p: float) -> bool:
	return random() < p

static func shuffle(arr: Array) -> Array:
	var i := arr.size() - 1
	while i > 0:
		var j := int(floor(random() * (i + 1)))
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		i -= 1
	return arr

static func weighted_pick(list: Array, wf: Callable) -> Variant:
	var tot := 0.0
	for it in list:
		tot += wf.call(it)
	var r := random() * tot
	for it in list:
		r -= wf.call(it)
		if r <= 0:
			return it
	return list[list.size() - 1]

static func dist(ax: float, ay: float, bx: float, by: float) -> float:
	return sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))

static func dist2(ax: float, ay: float, bx: float, by: float) -> float:
	return (bx - ax) * (bx - ax) + (by - ay) * (by - ay)

static func ang_to(ax: float, ay: float, bx: float, by: float) -> float:
	return atan2(by - ay, bx - ax)

static func ang_diff(a: float, b: float) -> float:
	var d := b - a
	while d > PI:
		d -= TAU
	while d < -PI:
		d += TAU
	return d

static func approach(v: float, t: float, d: float) -> float:
	return minf(v + d, t) if v < t else maxf(v - d, t)

# Math.round del JS: le metà vanno verso +infinito
static func jround(v: float) -> float:
	return floor(v + 0.5)

static func fmt_time(sec: float) -> String:
	var s := int(floor(sec))
	var m := s / 60
	var r := s % 60
	return "%d:%s%d" % [m, "0" if r < 10 else "", r]

static func to_int32(v: int) -> int:
	v = v & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v

# ToInt32 del JS applicato a un numero in virgola mobile
static func f_to_int32(x: float) -> int:
	if is_nan(x) or is_inf(x):
		return 0
	return to_int32(int(x) & 0xFFFFFFFF)

# Math.imul: prodotto a 32 bit senza overflow a 64 bit
static func imul(a: int, b: int) -> int:
	a = a & 0xFFFFFFFF
	b = b & 0xFFFFFFFF
	var lo := (a * (b & 0xFFFF)) & 0xFFFFFFFF
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return to_int32((lo + hi) & 0xFFFFFFFF)

# hash2 di js/dungeon.js. Il secondo prodotto nel JS è in virgola mobile
# e perde precisione: va riprodotto con un float, non con un intero.
static func hash2(x: int, y: int, s: int = 0) -> float:
	var h := to_int32(x * 374761393 + y * 668265263 + s * 1442695041)
	var v := to_int32(h ^ ((h & 0xFFFFFFFF) >> 13))
	var p := float(v) * 1274126177.0
	var a := f_to_int32(p)
	var b := (a & 0xFFFFFFFF) >> 16
	return float((a ^ b) & 0xFFFFFFFF) / 4294967296.0

static func rgba(r: int, g: int, b: int, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)

static func later(sec: float, fn: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(sec).timeout.connect(fn)
```

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh --only=core`
Expected: tutti i test di `test_core.gd` superati. Se `hash2` diverge, controllare che il secondo prodotto sia in `float` e che `f_to_int32` usi il troncamento.

- [ ] **Step 5: Commit**

```bash
git add godot/core godot/tests/test_core.gd
git commit -m "Core: costanti, utilità e RNG identici al JS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Salvataggio

**Files:**
- Create: `godot/autoload/save.gd`
- Modify: `godot/project.godot` (sezione `[autoload]`)
- Test: `godot/tests/test_save.gd`

**Interfaces:**
- Produces: autoload `Save` con `path: String`, `data: Dictionary`, `static defaults() -> Dictionary`, `load_save()`, `write() -> bool`, `unlock_lantern(id) -> bool`. I valori numerici interi di `stats` e `unlocks` restano `int` anche dopo il caricamento da JSON.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_save.gd`:
```gdscript
extends TestCase
# Salvataggio: tollerante come Save.load nel JS.

const P := "user://test_save_case.json"

func before() -> void:
	Save.path = P
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))

func after() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	Save.path = "user://test_save.json"
	Save.load_save()

func _write_raw(text: String) -> void:
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_senza_file_usa_i_default() -> void:
	Save.load_save()
	eq(Save.data, Save.defaults())

func test_campi_mancanti_presi_dai_default() -> void:
	_write_raw('{"settings": {"music": 0.2}, "stats": {"runs": 4}}')
	Save.load_save()
	eq(Save.data.settings.music, 0.2)
	eq(Save.data.settings.sfx, 0.7)
	eq(Save.data.stats.runs, 4)
	check(typeof(Save.data.stats.runs) == TYPE_INT, "runs deve restare intero")
	eq(Save.data.unlocks.lanterns, ["custode"])
	eq(Save.data.seen, {})

func test_file_corrotto_usa_i_default() -> void:
	_write_raw("{non è json")
	Save.load_save()
	eq(Save.data, Save.defaults())

func test_lanterne_non_array_ripristinate() -> void:
	_write_raw('{"unlocks": {"lanterns": "custode", "ardore": 2}}')
	Save.load_save()
	eq(Save.data.unlocks.lanterns, ["custode"])
	eq(Save.data.unlocks.ardore, 2)

func test_scrittura_e_rilettura() -> void:
	Save.load_save()
	Save.data.stats.kills = 12
	check(Save.unlock_lantern("pellegrino"), "prima volta: sbloccata")
	check(not Save.unlock_lantern("pellegrino"), "seconda volta: già sbloccata")
	Save.load_save()
	eq(Save.data.stats.kills, 12)
	eq(Save.data.unlocks.lanterns, ["custode", "pellegrino"])

func test_write_failure_is_silent() -> void:
	allow_errors()
	Save.path = "user://cartella_inesistente/sotto/save.json"
	Save.data = Save.defaults()
	Save.data.stats.runs = 3
	check(not Save.write(), "la scrittura deve fallire")
	eq(Save.data.stats.runs, 3, "i dati in memoria restano")
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=save`
Expected: errore `Save` non dichiarato.

- [ ] **Step 3: Implementare**

`godot/autoload/save.gd`:
```gdscript
extends Node
# Salvataggio permanente (da Save in js/core.js), in user://save.json.

const DEFAULT_PATH := "user://save.json"
var path := DEFAULT_PATH
var data: Dictionary = {}

func _ready() -> void:
	load_save()

static func defaults() -> Dictionary:
	return {
		"settings": {"music": 0.5, "sfx": 0.7, "shake": true, "numbers": true, "fullscreenHint": true},
		"stats": {"runs": 0, "wins": 0, "bestDepth": 0, "kills": 0, "bossKills": 0, "bestTime": 0, "maxArdoreWon": -1},
		"unlocks": {"lanterns": ["custode"], "ardore": 0},
		"seen": {},
	}

func load_save() -> void:
	var d: Variant = null
	if FileAccess.file_exists(path):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK:
			d = j.data
	var def := defaults()
	if not (d is Dictionary):
		d = def
	d.settings = _merge(def.settings, d.get("settings"))
	d.stats = _ints(_merge(def.stats, d.get("stats")))
	d.unlocks = _ints(_merge(def.unlocks, d.get("unlocks")))
	if not (d.unlocks.lanterns is Array):
		d.unlocks.lanterns = ["custode"]
	if not (d.get("seen") is Dictionary):
		d.seen = {}
	data = d

static func _merge(def: Dictionary, v: Variant) -> Dictionary:
	if v is Dictionary:
		for k in v:
			def[k] = v[k]
	return def

# il JSON restituisce solo float: i contatori tornano interi
static func _ints(d: Dictionary) -> Dictionary:
	for k in d:
		if typeof(d[k]) == TYPE_FLOAT and d[k] == floor(d[k]):
			d[k] = int(d[k])
	return d

func write() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false   # storage non disponibile: come nel JS si ignora
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func unlock_lantern(id: String) -> bool:
	if not data.unlocks.lanterns.has(id):
		data.unlocks.lanterns.append(id)
		write()
		return true
	return false
```

In `godot/project.godot` aggiungere:
```ini
[autoload]

Save="*res://autoload/save.gd"
```

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh --only=save`
Expected: 6 test superati.

- [ ] **Step 5: Commit**

```bash
git add godot/autoload/save.gd godot/project.godot godot/tests/test_save.gd
git commit -m "Salvataggio in user://save.json come nel JS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
## Fase B — Asset e servizi di base

### Task 5: Grafica di base — esportazione di sprite e font, `Spr`, `Txt`, `UiDraw`

**Files:**
- Create: `tools/export_assets/main.js`, `tools/export_assets/preload.js`, `tools/export_assets/export.html`, `tools/export_assets/export.js`
- Create (generati): `godot/assets/sprites/*.png`, `godot/assets/sprites/manifest.json`, `godot/assets/font/lanterna.png`, `godot/assets/font/glyphs.json`, `godot/assets/font/lanterna.fnt` (più i `.import` creati da Godot)
- Create: `godot/core/spr.gd`, `godot/core/txt.gd`, `godot/ui/ui_draw.gd`
- Test: `godot/tests/test_text.gd`, `godot/tests/test_spr.gd`

**Interfaces:**
- Produces:
  - Esportatore: `desktop/node_modules/.bin/electron tools/export_assets/main.js [--force] [--only=sprites,font,tiles,sfx,music]`; in `export.js` la funzione `runExport(only)` chiama `exportSprites`, `exportFont`, `exportTiles`, `exportSfx`, `exportMusic` (le ultime tre arrivano nei Task 6–8); `exporter.write(rel, base64)`, `exporter.writeText(rel, text)`, `exporter.log(msg)`.
  - `Spr`: `ensure()`, `has(name) -> bool`, `size(name) -> Vector2i`, `frame_count(name) -> int`, `draw(ci, name, frame, x, y, o := {})` con `o` = `flip`, `flash`, `alpha`, `scale`, `tint`, `tintA`; `draw_sil(ci, name, frame, x, y, color, flip := false)` (sagoma colorata, contorno dei nemici d'élite).
  - `Txt`: `static var COLORS` (`TEXT_COLORS`), `LINE := 10`, `ensure()`, `glyph(ch) -> Array` (`[x, w]` con il ripiego del JS), `atlas() -> Texture2D`, `width(s, scale := 1.0) -> float`, `wrap(s, max_w, scale := 1.0) -> Array`.
  - `UiDraw`: `static var alpha := 1.0`, `static var origin`, `set_origin(ci, o)`, `UI` (`UI_COL`), `col(c) -> Color`, `px_rect`, `px_circle`, `px_ring(ci, cx, cy, r, c, thick := 1.0)`, `shadow(ci, x, y, w)`, `glow(ci, x, y, r, color, a := 0.35)`, `panel(ci, x, y, w, h, o := {})`, `keycap(ci, x, y, label, o := {}) -> float`, `bar(ci, x, y, w, h, frac, col, bg := "#120d16", hi = null)`, `text(ci, s, x, y, o := {}) -> float`, `text_wrapped(ci, s, x, y, max_w, o := {}) -> float`, `flame(ci, x, y, s, t)`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_text.gd`:
```gdscript
extends TestCase
# Misura e a capo del testo: devono coincidere con Font.width e Font.wrap del JS.

func test_larghezza_base() -> void:
	eq(Txt.width("Ciao"), 21.0)          # C5 i3 a5 o5 + 3 spazi tra glifi
	eq(Txt.width("^yCiao^w"), 21.0)      # i codici colore non contano
	eq(Txt.width("a b"), 15.0)           # lo spazio vale 3 + 1
	eq(Txt.width("Ciao", 2), 42.0)
	eq(Txt.width(""), 0.0)

func test_a_capo_conserva_il_colore() -> void:
	eq(Txt.wrap("^yuno due tre", 30), ["^yuno", "^ydue", "^ytre"])
	eq(Txt.wrap("uno\ndue", 200), ["uno", "due"])
	eq(Txt.wrap("", 50), [""])

func test_missing_glyph_fallback() -> void:
	eq(Txt.glyph("ò"), Txt.glyph("ò"))
	eq(Txt.glyph("Ò")[1], 5.0, "maiuscola accentata disegnata")
	eq(Txt.glyph("ñ"), Txt.glyph("?"), "senza glifo: punto interrogativo")
	eq(Txt.glyph("’"), Txt.glyph("?"))
	eq(Txt.width("ñ"), Txt.width("?"))
	eq(Txt.glyph("q")[1], 5.0)

func test_colori_del_testo() -> void:
	eq(Txt.COLORS.y, Color("#f6cf57"))
	eq(Txt.COLORS.k, Color("#0d0a12"))
	eq(Txt.COLORS.size(), 11)
```

`godot/tests/test_spr.gd`:
```gdscript
extends TestCase
# Sprite esportati: manifest e dimensioni come compileRows nel JS (outline incluso).

func test_manifest_caricato() -> void:
	Spr.ensure()
	check(Spr.has("player"), "player")
	eq(Spr.size("player"), Vector2i(14, 16))
	eq(Spr.frame_count("player"), 2)
	eq(Spr.frame_count("coin"), 2)
	for n in ["rat", "bat", "skeleton", "skull", "ghoul", "boss_bones", "i_blade", "s_curse", "barrel", "merchant", "chest", "goldchest"]:
		check(Spr.has(n), "manca lo sprite " + n)
	check(not Spr.has("inesistente"))
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=text`
Expected: errore di parsing, `Txt` non dichiarato.

- [ ] **Step 3: Scrivere l'esportatore (sprite e font)**

`tools/export_assets/main.js`:
```js
'use strict';
// Esporta in godot/assets/ grafica, font, effetti sonori e musica generati dal codice JS originale.
// Uso: desktop/node_modules/.bin/electron tools/export_assets/main.js [--force] [--only=sprites,font,tiles,sfx,music]
const { app, BrowserWindow, ipcMain } = require('electron');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'godot', 'assets');
const args = process.argv.slice(2);
const force = args.includes('--force');
const onlyArg = args.find(a => a.startsWith('--only='));
const only = onlyArg ? onlyArg.slice(7).split(',') : ['sprites', 'font', 'tiles', 'sfx', 'music'];

// rifiuta di sovrascrivere asset esistenti senza --force: dopo l'esportazione sono sorgenti
function prepare(dir) {
  const d = path.join(OUT, dir);
  const existing = fs.existsSync(d) ? fs.readdirSync(d).filter(f => !f.endsWith('.import')) : [];
  if (existing.length && !force) throw new Error(d + ' contiene già degli asset: usa --force per sovrascriverli');
  fs.mkdirSync(d, { recursive: true });
}
function save(rel, buf) {
  const p = path.join(OUT, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, buf);
}
ipcMain.handle('write', (e, rel, b64) => save(rel, Buffer.from(b64, 'base64')));
ipcMain.handle('writeText', (e, rel, text) => save(rel, Buffer.from(text, 'utf8')));
ipcMain.handle('log', (e, msg) => console.log(msg));

// la musica viene registrata in WAV e convertita in OGG Vorbis
function encodeMusic() {
  const dir = path.join(OUT, 'music');
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.wav'))) {
    const src = path.join(dir, f), dst = src.replace(/\.wav$/, '.ogg');
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', src, '-c:a', 'libvorbis', '-q:a', '3', dst]);
    fs.unlinkSync(src);
  }
}

app.whenReady().then(async () => {
  try {
    for (const k of only) prepare(k);
    const win = new BrowserWindow({
      show: false,
      webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: false, backgroundThrottling: false }
    });
    await win.loadFile(path.join(__dirname, 'export.html'));
    await win.webContents.executeJavaScript('runExport(' + JSON.stringify(only) + ')');
    if (only.includes('music')) encodeMusic();
    console.log('Esportazione completata in ' + OUT);
    app.exit(0);
  } catch (e) {
    console.error(e.message || e);
    app.exit(1);
  }
});
```

`tools/export_assets/preload.js`:
```js
'use strict';
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('exporter', {
  write: (rel, b64) => ipcRenderer.invoke('write', rel, b64),
  writeText: (rel, text) => ipcRenderer.invoke('writeText', rel, text),
  log: msg => ipcRenderer.invoke('log', msg),
});
```

`tools/export_assets/export.html` (solo i file JS che servono: niente `game.js`, che avvierebbe il gioco):
```html
<!DOCTYPE html>
<html lang="it">
<head><meta charset="utf-8"><title>Esportazione asset</title></head>
<body>
<script src="../../js/core.js"></script>
<script src="../../js/font.js"></script>
<script src="../../js/gfx.js"></script>
<script src="../../js/sprites.js"></script>
<script src="../../js/audio.js"></script>
<script src="../../js/data.js"></script>
<script src="../../js/dungeon.js"></script>
<script src="export.js"></script>
</body>
</html>
```

`tools/export_assets/export.js`:
```js
'use strict';
// Gira nella finestra nascosta di Electron: disegna e registra gli asset
// con il codice originale del gioco e li passa al processo principale.

const toB64 = canvas => canvas.toDataURL('image/png').split(',')[1];

async function runExport(only) {
  Save.load();
  Font.init();
  buildSprites();
  if (only.includes('sprites')) await exportSprites();
  if (only.includes('font')) await exportFont();
  if (only.includes('tiles')) await exportTiles();
  if (only.includes('sfx')) await exportSfx();
  if (only.includes('music')) await exportMusic();
}

// ogni sprite: un PNG con i frame affiancati (outline incluso) + manifest
async function exportSprites() {
  const manifest = {};
  for (const name of Object.keys(SPR)) {
    const s = SPR[name];
    const cv = makeCanvas(s.w * s.frames.length, s.h);
    const c = cv.getContext('2d');
    s.frames.forEach((f, i) => c.drawImage(f, i * s.w, 0));
    await exporter.write('sprites/' + name + '.png', toB64(cv));
    manifest[name] = { w: s.w, h: s.h, frames: s.frames.length };
  }
  await exporter.writeText('sprites/manifest.json', JSON.stringify(manifest, null, 1));
  exporter.log('sprite esportati: ' + Object.keys(manifest).length);
}

// font: atlas bianco, larghezze dei glifi e BMFont per l'editor
async function exportFont() {
  const chars = Object.keys(Font.glyphs);
  let total = 0;
  for (const ch of chars) total += Font.glyphs[ch].w + 1;
  const cv = makeCanvas(total, 8), c = cv.getContext('2d');
  c.fillStyle = '#ffffff';
  const map = {};
  const fnt = [
    'info face="lanterna" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
    'common lineHeight=10 base=7 scaleW=' + total + ' scaleH=8 pages=1 packed=0',
    'page id=0 file="lanterna.png"',
    'chars count=' + (chars.length + 1),
    'char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=4 page=0 chnl=15',
  ];
  let x = 0;
  for (const ch of chars) {
    const g = Font.glyphs[ch];
    g.rows.forEach((row, ry) => row.forEach((on, rx) => { if (on) c.fillRect(x + rx, ry, 1, 1); }));
    map[ch] = [x, g.w];
    fnt.push('char id=' + ch.codePointAt(0) + ' x=' + x + ' y=0 width=' + g.w + ' height=8 xoffset=0 yoffset=0 xadvance=' + (g.w + 1) + ' page=0 chnl=15');
    x += g.w + 1;
  }
  await exporter.write('font/lanterna.png', toB64(cv));
  await exporter.writeText('font/glyphs.json', JSON.stringify(map));
  await exporter.writeText('font/lanterna.fnt', fnt.join('\n') + '\n');
  exporter.log('glifi esportati: ' + chars.length);
}
```

- [ ] **Step 4: Eseguire l'esportazione e importare in Godot**

Run:
```bash
desktop/node_modules/.bin/electron tools/export_assets/main.js --only=sprites,font
ls godot/assets/sprites | wc -l && head -c 300 godot/assets/sprites/manifest.json
godot --headless --path godot --import
```
Expected: `sprite esportati: <N>` con N intorno a 120 (30 attori e boss, 26 oggetti, 49 icone `i_*`, 11 icone `s_*`), `glifi esportati: <M>`, `Esportazione completata`; la cartella contiene N PNG più `manifest.json`. Se Electron non trova un display, eseguirlo dentro una sessione grafica (serve solo una volta).

- [ ] **Step 5: Implementare `Spr`, `Txt`, `UiDraw`**

`godot/core/txt.gd`:
```gdscript
class_name Txt
extends RefCounted
# Font bitmap (js/font.js): glifi, misura e a capo dei testi con i codici colore ^x.

const LINE := 10
static var COLORS := {
	"w": Color("#ece6d8"), "y": Color("#f6cf57"), "r": Color("#e0574a"), "g": Color("#8fd35a"),
	"b": Color("#6fa8e8"), "o": Color("#f29c38"), "p": Color("#c57ae0"), "d": Color("#8a8294"),
	"c": Color("#7fd8e6"), "s": Color("#b8b2c2"), "k": Color("#0d0a12"),
}
static var glyphs: Dictionary = {}   # carattere -> [x nell'atlas, larghezza]
static var _atlas: Texture2D

static func ensure() -> void:
	if not glyphs.is_empty():
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://assets/font/glyphs.json")) != OK:
		push_error("glyphs.json non leggibile")
		return
	glyphs = j.data

static func atlas() -> Texture2D:
	if _atlas == null:
		_atlas = load("res://assets/font/lanterna.png")
	return _atlas

# ripiego del JS: maiuscola/minuscola, poi il punto interrogativo
static func glyph(ch: String) -> Array:
	ensure()
	if glyphs.has(ch):
		return glyphs[ch]
	var up := ch.to_upper()
	if glyphs.has(up):
		return glyphs[up]
	var lo := ch.to_lower()
	if glyphs.has(lo):
		return glyphs[lo]
	return glyphs["?"]

# larghezza ignorando i codici colore
static func width(s: String, scale: float = 1.0) -> float:
	var w := 0.0
	var n := 0
	var i := 0
	while i < s.length():
		var ch := s[i]
		if ch == "^":
			i += 2
			continue
		if ch == " ":
			w += 3
		else:
			w += float(glyph(ch)[1])
		n += 1
		i += 1
	return (w + maxi(0, n - 1)) * scale

static func _last_code(word: String) -> String:
	var res := ""
	var i := 0
	while i < word.length():
		if word[i] == "^" and i + 1 < word.length():
			res = word[i + 1]
			i += 2
		else:
			i += 1
	return res

# a capo automatico, preserva i codici colore tra le righe
static func wrap(s: String, max_w: float, scale: float = 1.0) -> Array:
	var out: Array = []
	for para in s.split("\n"):
		var line := ""
		var last_code := ""
		for word in para.split(" "):
			var test: String = line + " " + word if line != "" else word
			if width(test, scale) > max_w and line != "":
				out.append(line)
				line = ("^" + last_code if last_code != "" else "") + word
			else:
				line = test
			var code := _last_code(word)
			if code != "":
				last_code = code
		out.append(line)
	return out
```

`godot/core/spr.gd`:
```gdscript
class_name Spr
extends RefCounted
# Sprite esportati (assets/sprites) e disegno come drawSpr in js/gfx.js.
# Le sagome bianche per flash e tinta si generano al caricamento.

const DIR := "res://assets/sprites/"
static var db: Dictionary = {}   # nome -> {tex, sil, w, h, frames}

static func ensure() -> void:
	if not db.is_empty():
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(DIR + "manifest.json")) != OK:
		push_error("manifest degli sprite non leggibile")
		return
	for name in j.data:
		var m: Dictionary = j.data[name]
		var tex: Texture2D = load(DIR + name + ".png")
		db[name] = {"tex": tex, "sil": _silhouette(tex), "w": int(m.w), "h": int(m.h), "frames": int(m.frames)}

static func _silhouette(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex   # rendering fittizio (test headless): nessuna sagoma
	img = img.duplicate()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, c.a))
	return ImageTexture.create_from_image(img)

static func has(name: String) -> bool:
	ensure()
	return db.has(name)

static func size(name: String) -> Vector2i:
	ensure()
	var s: Dictionary = db[name]
	return Vector2i(s.w, s.h)

static func frame_count(name: String) -> int:
	ensure()
	return db[name].frames

static func _blit(ci: CanvasItem, tex: Texture2D, src: Rect2, dx: float, dy: float, w: float, h: float, flip: bool, c: Color) -> void:
	if flip:
		ci.draw_set_transform(Vector2(dx + w, dy) + UiDraw.origin, 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(tex, Rect2(0, 0, w, h), src, c)
		ci.draw_set_transform(UiDraw.origin)
	else:
		ci.draw_texture_rect_region(tex, Rect2(dx, dy, w, h), src, c)

# centrato su (x, y). o: flip, flash, alpha, scale, tint, tintA
static func draw(ci: CanvasItem, name: String, frame: float, x: float, y: float, o: Dictionary = {}) -> void:
	ensure()
	if not db.has(name):
		return
	var s: Dictionary = db[name]
	var f := int(frame) % int(s.frames)
	var sc: float = o.get("scale", 1.0)
	var w: float = s.w * sc
	var h: float = s.h * sc
	var dx := U.jround(x - w / 2.0)
	var dy := U.jround(y - h / 2.0)
	var a: float = o.get("alpha", 1.0) * UiDraw.alpha
	if a <= 0.0:
		return
	var src := Rect2(f * s.w, 0, s.w, s.h)
	var flip: bool = o.get("flip", false)
	_blit(ci, s.sil if o.get("flash", false) else s.tex, src, dx, dy, w, h, flip, Color(1, 1, 1, a))
	if o.get("tint") != null:
		var t := UiDraw.col(o.tint)
		_blit(ci, s.sil, src, dx, dy, w, h, flip, Color(t.r, t.g, t.b, a * o.get("tintA", 0.5)))

# sagoma colorata (sprTint del JS), disegnata con l'angolo in alto a sinistra in (dx, dy)
static func draw_sil(ci: CanvasItem, name: String, frame: float, dx: float, dy: float, color: Variant, flip: bool = false) -> void:
	ensure()
	if not db.has(name):
		return
	var s: Dictionary = db[name]
	var f := int(frame) % int(s.frames)
	var k := UiDraw.col(color)
	_blit(ci, s.sil, Rect2(f * s.w, 0, s.w, s.h), dx, dy, s.w, s.h, flip, Color(k.r, k.g, k.b, k.a * UiDraw.alpha))
```

`godot/ui/ui_draw.gd`:
```gdscript
class_name UiDraw
extends RefCounted
# Primitive pixel, pannelli e testo (da js/gfx.js e js/font.js).
# UiDraw.alpha fa da ctx.globalAlpha: moltiplica l'alfa di tutto ciò che si disegna.

static var alpha := 1.0
static var origin := Vector2.ZERO   # trasformazione di base del nodo che sta disegnando
static var _colors: Dictionary = {}
static var _glow_tex: Texture2D

# Gli attori stanno in position = (x, y) per l'ordinamento in Y, ma disegnano in
# coordinate del mondo come il JS: set_origin(self, -position) all'inizio di _draw()
# e set_origin(self, Vector2.ZERO) alla fine.
static func set_origin(ci: CanvasItem, o: Vector2) -> void:
	origin = o
	ci.draw_set_transform(o)

static var UI := {   # UI_COL del JS
	"bg": Color("#16111c"), "bg2": Color("#1f1826"), "edge": Color("#0a070d"), "brass": Color("#9a7a44"),
	"brassL": Color("#d8b46a"), "brassD": Color("#5a4428"), "ink": Color("#ece6d8"), "dim": Color("#8a8294"), "sel": Color("#f6cf57"),
}

static func col(c: Variant) -> Color:
	if c is Color:
		return c
	if not _colors.has(c):
		_colors[c] = Color(c)
	return _colors[c]

static func _a(c: Variant) -> Color:
	var k := col(c)
	return Color(k.r, k.g, k.b, k.a * alpha)

static func px_rect(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Variant) -> void:
	var rw := U.jround(w)
	var rh := U.jround(h)
	if rw == 0 or rh == 0:
		return
	ci.draw_rect(Rect2(U.jround(x), U.jround(y), rw, rh).abs(), _a(c))

static func px_circle(ci: CanvasItem, cx: float, cy: float, r: float, c: Variant) -> void:
	var k := _a(c)
	cx = U.jround(cx)
	cy = U.jround(cy)
	r = maxf(0.5, r)
	var ri := int(ceil(r))
	for yy in range(-ri, ri + 1):
		var hw := floor(sqrt(maxf(0.0, r * r - yy * yy)))
		if hw <= 0 and absf(yy) >= r:
			continue
		ci.draw_rect(Rect2(cx - hw, cy + yy, hw * 2 + 1, 1), k)

static func px_ring(ci: CanvasItem, cx: float, cy: float, r: float, c: Variant, thick: float = 1.0) -> void:
	var rr := maxf(0.5, r)
	ci.draw_arc(Vector2(U.jround(cx) + 0.5, U.jround(cy) + 0.5), rr, 0.0, TAU, maxi(12, int(rr * 1.5)), _a(c), thick)

static func shadow(ci: CanvasItem, x: float, y: float, w: float) -> void:
	var ry := maxf(1.5, w * 0.38)
	var cx := U.jround(x)
	var cy := U.jround(y)
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cx + cos(a) * w, cy + sin(a) * ry))
	ci.draw_colored_polygon(pts, _a(U.rgba(5, 3, 8, 0.45)))

# alone luminoso; nel JS è additivo ('lighter'), qui è una sfumatura normale:
# sugli sfondi scuri del gioco la differenza è minima
static func glow(ci: CanvasItem, x: float, y: float, r: float, color: Variant, a: float = 0.35) -> void:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow_tex = t
	var k := col(color)
	ci.draw_texture_rect(_glow_tex, Rect2(x - r, y - r, r * 2, r * 2), false, Color(k.r, k.g, k.b, a * alpha))
```
Poi, nello stesso file, portare da `js/gfx.js` e `js/font.js` (stesse coordinate e colori, regole di traduzione sopra):
- `panel(ci, x, y, w, h, o := {})` ← `panel` (`js/gfx.js:162-184`). `o.alpha` predefinito `0.94`, moltiplicato per `alpha` corrente; `o.border`, `o.bg`, `o.hi` sostituiscono i colori di `UI`.
- `keycap(ci, x, y, label, o := {}) -> float` ← `keycap` (`js/gfx.js:186-194`), restituisce la larghezza.
- `bar(ci, x, y, w, h, frac, c, bg := "#120d16", hi = null)` ← `bar` (`js/gfx.js:195-203`); `hi` nullo vale `U.rgba(255, 255, 255, 0.25)`.
- `flame(ci, x, y, s, t)` ← `drawFlame` (`js/render.js:154-163`) con `t` = tempo in secondi (al posto di `Render.time`).
- `text(ci, s, x, y, o := {}) -> float` ← `Font.draw` + `Font._run` (`js/font.js:163-199`): opzioni `color` (predefinito `Txt.COLORS.w`), `align` (`left`, `center`, `right`), `shadow` (predefinito vero, colore `o.shadowColor` o `U.rgba(8, 5, 12, 0.85)`, spostata di `scale` pixel), `scale`, `alpha` (moltiplica `UiDraw.alpha` e lo ripristina alla fine). Ogni glifo si disegna con `ci.draw_texture_rect_region(Txt.atlas(), Rect2(x, y, w * scale, 8 * scale), Rect2(gx, 0, w, 8), colore)`; lo spazio avanza di `4 * scale`; `^w` torna al colore di base, un codice sconosciuto pure; l'ombra ignora i codici.
- `text_wrapped(ci, s, x, y, max_w, o := {}) -> float` ← `Font.drawWrapped` (`js/font.js:219-224`), altezza di riga `o.lineH` o `Txt.LINE * scale`.

- [ ] **Step 6: Eseguire i test**

Run: `tools/test.sh --only=text && tools/test.sh --only=spr`
Expected: tutti superati.

- [ ] **Step 7: Commit**

```bash
git add tools/export_assets godot/assets/sprites godot/assets/font godot/core/spr.gd godot/core/txt.gd godot/ui/ui_draw.gd godot/tests/test_text.gd godot/tests/test_spr.gd
git commit -m "Esportazione di sprite e font, disegno di sprite, testo e pannelli

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Tile delle stanze

**Files:**
- Modify: `tools/export_assets/export.js` (aggiunge `exportTiles`, `drawFloorVariant`, `drawWallVariant`)
- Create: `godot/tools/build_tilesets.gd`, `godot/world/tile_pick.gd`
- Create (generati): `godot/assets/tiles/{crypt,fungus,forge,abyss,heart}.png`, `godot/assets/tiles/layout.json`, `godot/assets/tiles/*.tres`
- Test: `godot/tests/test_tiles.gd`

**Interfaces:**
- Produces: `TilePick` (statiche) `floor_key(tx, ty, s) -> String`, `wall_key(tx, ty, s) -> String`, `rock_key(tx, ty, s, cracked: bool) -> String`, `coords(biome_id, key) -> Vector2i`, `tileset(biome_id) -> TileSet`. Chiavi: `floor_c{0,1,2}_{plain,seam,crack}_g{0..5}`, `wall_{top,bottom,left0,left1,right0,right1,corner}_{0,1}`, `rock_{0,1}_{0,1}`. `s` è `room.seed % 1000`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_tiles.gd`:
```gdscript
extends TestCase
# Tile: ogni chiave scelta da TilePick deve esistere nell'atlas di ogni bioma.

func test_tileset_per_ogni_bioma() -> void:
	for b in ["crypt", "fungus", "forge", "abyss", "heart"]:
		var ts := TilePick.tileset(b)
		check(ts != null, "tileset " + b)
		var src := ts.get_source(0) as TileSetAtlasSource
		check(src.has_tile(TilePick.coords(b, "wall_corner_1")), "muro d'angolo in " + b)

func test_chiavi_scelte_esistono() -> void:
	for s in [0, 17, 999]:
		for ty in Consts.RH:
			for tx in Consts.RW:
				var k := TilePick.floor_key(tx, ty, s)
				check(TilePick.coords("crypt", k) != Vector2i(-1, -1), "pavimento " + k)
				if tx == 0 or ty == 0 or tx == Consts.RW - 1 or ty == Consts.RH - 1:
					var w := TilePick.wall_key(tx, ty, s)
					check(TilePick.coords("crypt", w) != Vector2i(-1, -1), "muro " + w)
	eq(TilePick.wall_key(0, 0, 5).substr(0, 11), "wall_corner")
	eq(TilePick.wall_key(5, 0, 5).substr(0, 8), "wall_top")
	eq(TilePick.wall_key(0, 3, 5).substr(0, 10), "wall_left1")
	eq(TilePick.wall_key(28, 4, 5).substr(0, 11), "wall_right0")

func test_scelta_del_pavimento_come_il_js() -> void:
	# stessa logica di renderRoomBg: colore = floor(h * 3), giunto se h > 0.55, crepa se h < 0.08
	for i in 200:
		var tx := i % 29
		var ty := i / 29
		var h := U.hash2(tx, ty, 321)
		var k := TilePick.floor_key(tx, ty, 321)
		check(k.begins_with("floor_c%d_" % int(floor(h * 3))), k)
		if h < 0.08:
			check(k.contains("_crack_"), k)
		elif h > 0.55:
			check(k.contains("_seam_"), k)
		else:
			check(k.contains("_plain_"), k)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=tiles`
Expected: errore, `TilePick` non dichiarato.

- [ ] **Step 3: Aggiungere l'esportazione dei tile**

In `tools/export_assets/export.js` aggiungere:
```js
// atlas dei tile per bioma: pavimento, muri e rocce di renderRoomBg (js/dungeon.js)
async function exportTiles() {
  const COLS = 8, layoutAll = {};
  for (const biome of BIOMES) {
    const tiles = [];
    for (let ci = 0; ci < 3; ci++) for (const kind of ['plain', 'seam', 'crack']) for (let g = 0; g < 6; g++)
      tiles.push(['floor_c' + ci + '_' + kind + '_g' + g, (c, x, y) => drawFloorVariant(c, x, y, biome, ci, kind, g)]);
    for (const edge of ['top', 'bottom', 'left0', 'left1', 'right0', 'right1', 'corner']) for (const crack of [0, 1])
      tiles.push(['wall_' + edge + '_' + crack, (c, x, y) => drawWallVariant(c, x, y, biome, edge, crack)]);
    for (const cracked of [0, 1]) for (const dot of [0, 1])
      tiles.push(['rock_' + cracked + '_' + dot, (c, x, y) => drawRock(c, x, y, biome, !!cracked, dot ? 0.7 : 0.2)]);
    const rows = Math.ceil(tiles.length / COLS);
    const cv = makeCanvas(COLS * TS, rows * TS), c = cv.getContext('2d');
    const layout = {};
    tiles.forEach(([k, fn], i) => { const col = i % COLS, row = Math.floor(i / COLS); fn(c, col * TS, row * TS); layout[k] = [col, row]; });
    await exporter.write('tiles/' + biome.id + '.png', toB64(cv));
    layoutAll[biome.id] = layout;
  }
  await exporter.writeText('tiles/layout.json', JSON.stringify({ tile: TS, columns: COLS, biomes: layoutAll }));
  exporter.log('atlas dei tile: ' + Object.keys(layoutAll).join(', '));
}

// pavimento di renderRoomBg con colore, giunto e granelli scelti
function drawFloorVariant(c, x, y, biome, ci, kind, g) {
  c.fillStyle = biome.floor[ci]; c.fillRect(x, y, TS, TS);
  c.fillStyle = biome.floorD;
  c.fillRect(x, y + TS - 1, TS, 1); c.fillRect(x + TS - 1, y, 1, TS);
  if (kind === 'seam') c.fillRect(x + 8, y, 1, 8);
  for (let k = 0; k < 4; k++) {
    const hx = hash2(g * 7 + k, 3, 9), hy = hash2(g * 5, 11 + k, 3);
    c.fillStyle = k % 2 ? biome.floorD : 'rgba(255,255,255,0.04)';
    c.fillRect(x + Math.floor(hx * 15), y + Math.floor(hy * 15), 1, 1);
  }
  if (kind === 'crack') { c.fillStyle = biome.floorD; c.fillRect(x + 3, y + 5, 5, 1); c.fillRect(x + 7, y + 6, 4, 1); c.fillRect(x + 10, y + 7, 1, 3); }
}

// muro di drawWallTile per bordo e parità della riga
function drawWallVariant(c, x, y, biome, edge, crack) {
  const ty = { top: 0, bottom: RH - 1, left0: 2, left1: 1, right0: 2, right1: 1, corner: 0 }[edge];
  c.fillStyle = biome.wallD; c.fillRect(x, y, TS, TS);
  const off = (ty % 2) * 8;
  c.fillStyle = biome.wall;
  for (let by = 0; by < 2; by++) for (let bx = -1; bx < 2; bx++) {
    const ox = x + bx * 8 + ((by + ty) % 2) * 4 + (off % 8);
    const rx = Math.max(x, ox), rw = Math.min(x + TS, ox + 7) - rx;
    if (rw > 0) c.fillRect(rx, y + by * 8, rw, 7);
  }
  c.fillStyle = biome.wallL;
  if (edge === 'top') c.fillRect(x, y + TS - 2, TS, 2);
  if (edge === 'bottom') c.fillRect(x, y, TS, 1);
  if (edge === 'left0' || edge === 'left1') c.fillRect(x + TS - 2, y, 2, TS);
  if (edge === 'right0' || edge === 'right1') c.fillRect(x, y, 2, TS);
  if (crack) { c.fillStyle = 'rgba(0,0,0,0.4)'; c.fillRect(x + 4, y + 3, 1, 5); c.fillRect(x + 5, y + 7, 2, 1); }
}
```

- [ ] **Step 4: Generatore delle TileSet**

`godot/tools/build_tilesets.gd`:
```gdscript
extends SceneTree
# Genera assets/tiles/<bioma>.tres dagli atlas esportati e da layout.json.
# Uso: godot --headless --path godot -s res://tools/build_tilesets.gd

func _initialize() -> void:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://assets/tiles/layout.json")) != OK:
		push_error("layout.json non leggibile")
		quit(1)
		return
	var px := int(j.data.tile)
	for biome in j.data.biomes:
		var ts := TileSet.new()
		ts.tile_size = Vector2i(px, px)
		var src := TileSetAtlasSource.new()
		src.texture = load("res://assets/tiles/%s.png" % biome)
		src.texture_region_size = Vector2i(px, px)
		for key in j.data.biomes[biome]:
			var c: Array = j.data.biomes[biome][key]
			src.create_tile(Vector2i(int(c[0]), int(c[1])))
		ts.add_source(src, 0)
		var err := ResourceSaver.save(ts, "res://assets/tiles/%s.tres" % biome)
		if err != OK:
			push_error("salvataggio di %s fallito: %d" % [biome, err])
			quit(1)
			return
		print("tileset ", biome)
	quit(0)
```

- [ ] **Step 5: Esportare e generare**

Run:
```bash
desktop/node_modules/.bin/electron tools/export_assets/main.js --only=tiles
godot --headless --path godot --import
godot --headless --path godot -s res://tools/build_tilesets.gd
godot --headless --path godot --import
```
Expected: `atlas dei tile: crypt, fungus, forge, abyss, heart`, poi cinque righe `tileset <bioma>`.

- [ ] **Step 6: Implementare `TilePick`**

`godot/world/tile_pick.gd`:
```gdscript
class_name TilePick
extends RefCounted
# Sceglie le varianti dei tile con lo stesso hash2 di renderRoomBg (js/dungeon.js).

static var _layout: Dictionary = {}
static var _sets: Dictionary = {}

static func _ensure() -> void:
	if not _layout.is_empty():
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://assets/tiles/layout.json")) == OK:
		_layout = j.data

static func floor_key(tx: int, ty: int, s: int) -> String:
	var h := U.hash2(tx, ty, s)
	var kind := "crack" if h < 0.08 else ("seam" if h > 0.55 else "plain")
	var g := int(floor(U.hash2(tx, ty, s + 5) * 6))
	return "floor_c%d_%s_g%d" % [int(floor(h * 3)), kind, g]

static func wall_key(tx: int, ty: int, s: int) -> String:
	var xe := tx == 0 or tx == Consts.RW - 1
	var ye := ty == 0 or ty == Consts.RH - 1
	var edge: String
	if xe and ye:
		edge = "corner"
	elif ty == 0:
		edge = "top"
	elif ty == Consts.RH - 1:
		edge = "bottom"
	elif tx == 0:
		edge = "left%d" % (ty % 2)
	else:
		edge = "right%d" % (ty % 2)
	return "wall_%s_%d" % [edge, 1 if U.hash2(tx, ty, s + 77) < 0.1 else 0]

static func rock_key(tx: int, ty: int, s: int, cracked: bool) -> String:
	return "rock_%d_%d" % [1 if cracked else 0, 1 if U.hash2(tx, ty, s) > 0.5 else 0]

static func coords(biome_id: String, key: String) -> Vector2i:
	_ensure()
	var c: Variant = _layout.biomes.get(biome_id, {}).get(key)
	if c == null:
		return Vector2i(-1, -1)
	return Vector2i(int(c[0]), int(c[1]))

static func tileset(biome_id: String) -> TileSet:
	if not _sets.has(biome_id):
		_sets[biome_id] = load("res://assets/tiles/%s.tres" % biome_id)
	return _sets[biome_id]
```

- [ ] **Step 7: Eseguire i test**

Run: `tools/test.sh --only=tiles`
Expected: 3 test superati.

- [ ] **Step 8: Commit**

```bash
git add tools/export_assets/export.js godot/tools godot/world/tile_pick.gd godot/assets/tiles godot/tests/test_tiles.gd
git commit -m "Atlas e TileSet delle stanze esportati dal JS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Effetti sonori

**Files:**
- Modify: `tools/export_assets/export.js` (aggiunge `SFX_NAMES`, `exportSfx`, `makeNoise`, `trimTail`, `wavB64`)
- Create (generati): `godot/assets/sfx/<nome>_{1,2,3}.wav`
- Create: `godot/autoload/sfx.gd`
- Modify: `godot/project.godot` (autoload `Sfx`)
- Test: `godot/tests/test_sfx.gd`

**Interfaces:**
- Produces: autoload `Sfx`: `NAMES`, `play(name, vol := 1.0) -> bool` (vero se il suono parte), `apply_volumes()`. Bus `Master` (volume 0,9 e compressore −14 dB, rapporto 4), `Sfx`, `Music`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_sfx.gd`:
```gdscript
extends TestCase
# Effetti sonori: varianti caricate, intervalli minimi, volume a zero.

func before() -> void:
	Sfx.last.clear()
	Save.data.settings.sfx = 0.7

func test_tutti_i_suoni_hanno_tre_varianti() -> void:
	eq(Sfx.NAMES.size(), 33)
	for n in Sfx.NAMES:
		eq(Sfx.streams[n].size(), 3, n)

func test_intervallo_minimo() -> void:
	check(Sfx.play("coin"), "primo coin")
	check(not Sfx.play("coin"), "secondo coin entro 0,04 s")
	check(Sfx.play("hit"), "altro suono")

func test_volume_zero_e_nomi_sconosciuti() -> void:
	check(not Sfx.play("inesistente"))
	Save.data.settings.sfx = 0.0
	check(not Sfx.play("door"))
	Save.data.settings.sfx = 0.7

func test_bus_audio() -> void:
	check(AudioServer.get_bus_index("Sfx") > 0)
	check(AudioServer.get_bus_index("Music") > 0)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=sfx`
Expected: errore, `Sfx` non dichiarato.

- [ ] **Step 3: Aggiungere l'esportazione degli effetti**

In `tools/export_assets/export.js`:
```js
const SFX_NAMES = ['shoot', 'hit', 'crit', 'kill', 'hurt', 'coin', 'xp', 'pickup', 'heal', 'oil', 'levelup', 'dash', 'flare',
  'explosion', 'door', 'lock', 'enemyShoot', 'spawn', 'roar', 'select', 'confirm', 'deny', 'chest', 'buy', 'curse', 'shield',
  'freeze', 'thud', 'bolt', 'tick', 'descend', 'warn', 'block'];

// rumore bianco come in Sound.unlock, generato con il Math.random corrente
function makeNoise(c) {
  const len = c.sampleRate * 1.0, b = c.createBuffer(1, len, c.sampleRate), d = b.getChannelData(0);
  for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
  return b;
}
function trimTail(data, sr) {
  let end = data.length;
  while (end > sr * 0.05 && Math.abs(data[end - 1]) < 1e-4) end--;
  return data.subarray(0, end);
}
// PCM 16 bit, codificato in base64
function wavB64(samples, sr) {
  const n = samples.length, buf = new ArrayBuffer(44 + n * 2), v = new DataView(buf);
  const str = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  str(0, 'RIFF'); v.setUint32(4, 36 + n * 2, true); str(8, 'WAVE'); str(12, 'fmt ');
  v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true); v.setUint32(24, sr, true);
  v.setUint32(28, sr * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true); str(36, 'data'); v.setUint32(40, n * 2, true);
  for (let i = 0; i < n; i++) v.setInt16(44 + i * 2, Math.max(-1, Math.min(1, samples[i])) * 32767, true);
  const bytes = new Uint8Array(buf);
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(bin);
}

// ogni effetto di Sound.play registrato offline in 3 varianti (Math.random con semi diversi)
async function exportSfx() {
  const SR = 44100;
  Save.data.settings.sfx = 1;
  for (let idx = 0; idx < SFX_NAMES.length; idx++) {
    const name = SFX_NAMES[idx];
    for (let v = 1; v <= 3; v++) {
      const r = new RNG(1000 * v + idx);
      Math.random = () => r.next();
      const oc = new OfflineAudioContext(1, SR * 2, SR);
      const out = oc.createGain(); out.gain.value = 1; out.connect(oc.destination);
      Sound.ctx = oc; Sound.sfxGain = out; Sound.unlocked = true; Sound.last = Object.create(null);
      Sound.noiseBuf = makeNoise(oc);
      Sound.play(name);
      const buf = await oc.startRendering();
      await exporter.write('sfx/' + name + '_' + v + '.wav', wavB64(trimTail(buf.getChannelData(0), SR), SR));
    }
  }
  exporter.log('effetti esportati: ' + SFX_NAMES.length * 3);
}
```

- [ ] **Step 4: Esportare**

Run:
```bash
desktop/node_modules/.bin/electron tools/export_assets/main.js --only=sfx
ls godot/assets/sfx/*.wav | wc -l
godot --headless --path godot --import
```
Expected: `effetti esportati: 99`, poi `99`.

- [ ] **Step 5: Implementare `Sfx`**

`godot/autoload/sfx.gd`:
```gdscript
extends Node
# Effetti sonori (da Sound in js/audio.js): varianti registrate offline,
# intervalli minimi tra ripetizioni, bus con compressore e volumi delle opzioni.

const NAMES := ["shoot", "hit", "crit", "kill", "hurt", "coin", "xp", "pickup", "heal", "oil", "levelup", "dash", "flare",
	"explosion", "door", "lock", "enemyShoot", "spawn", "roar", "select", "confirm", "deny", "chest", "buy", "curse", "shield",
	"freeze", "thud", "bolt", "tick", "descend", "warn", "block"]
const GAP := {"shoot": 0.045, "hit": 0.035, "xp": 0.03, "coin": 0.04, "enemyShoot": 0.05, "kill": 0.04, "tick": 0.05}
const VOICES := 24

var streams: Dictionary = {}   # nome -> Array di AudioStream
var last: Dictionary = {}      # nome -> secondi dell'ultima esecuzione
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var variety := RNG.new(12345)  # scelta della variante: non tocca la casualità di gioco

func _ready() -> void:
	_setup_buses()
	for n in NAMES:
		var arr: Array = []
		for v in range(1, 4):
			var p := "res://assets/sfx/%s_%d.wav" % [n, v]
			if ResourceLoader.exists(p):
				arr.append(load(p))
		streams[n] = arr
	for i in VOICES:
		var pl := AudioStreamPlayer.new()
		pl.bus = "Sfx"
		add_child(pl)
		players.append(pl)
	apply_volumes()

func _setup_buses() -> void:
	if AudioServer.get_bus_index("Sfx") != -1:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(0.9))
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 4.0
	AudioServer.add_bus_effect(0, comp)
	for bus_name in ["Sfx", "Music"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")

func apply_volumes() -> void:
	var s: Dictionary = Save.data.settings
	var si := AudioServer.get_bus_index("Sfx")
	var mi := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(si, linear_to_db(maxf(0.0001, s.sfx * 0.8)))
	AudioServer.set_bus_mute(si, s.sfx <= 0)
	AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(0.0001, s.music * 0.55)))
	AudioServer.set_bus_mute(mi, s.music <= 0)

func play(name: String, vol: float = 1.0) -> bool:
	if Save.data.settings.sfx <= 0:
		return false
	var arr: Array = streams.get(name, [])
	if arr.is_empty():
		return false
	var now := Time.get_ticks_usec() / 1000000.0
	if last.has(name) and now - last[name] < GAP.get(name, 0.02):
		return false
	last[name] = now
	var pl := players[next_voice]
	next_voice = (next_voice + 1) % VOICES
	pl.stream = variety.pick(arr)
	pl.volume_db = linear_to_db(maxf(0.0001, vol))
	pl.play()
	return true
```

In `godot/project.godot`, sezione `[autoload]`, dopo `Save`:
```ini
Sfx="*res://autoload/sfx.gd"
```

- [ ] **Step 6: Eseguire i test e ascoltare**

Run: `tools/test.sh --only=sfx`
Expected: 4 test superati.

Verifica a orecchio (una volta): aprire il file `godot/assets/sfx/flare_1.wav` con un lettore audio e confrontarlo con la Vampata del gioco JS (`index.html`, tasto F). Devono essere lo stesso suono.

- [ ] **Step 7: Commit**

```bash
git add tools/export_assets/export.js godot/assets/sfx godot/autoload/sfx.gd godot/project.godot godot/tests/test_sfx.gd
git commit -m "Effetti sonori registrati dal JS e autoload Sfx

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Musica a strati

**Files:**
- Modify: `tools/export_assets/export.js` (aggiunge `STEMS`, `stemStep`, `exportMusic`, `renderStem`)
- Create (generati): `godot/assets/music/<traccia>_<strato>.ogg` (6 tracce × 6 strati)
- Create: `godot/autoload/music.gd`
- Modify: `godot/project.godot` (autoload `Music`)
- Test: `godot/tests/test_music.gd`

**Interfaces:**
- Produces: autoload `Music`: `STEMS := ["drone", "arp_lo", "arp", "arp_hi", "bass", "hats"]`, `MIX` (volumi per intensità), `track_name: String`, `intensity: int`, `gains: Array`, `play(track)`, `set_intensity(i)`, `stop()`, `step(delta)` (avanza dissolvenze; chiamato da `_process`, usato dai test).

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_music.gd`:
```gdscript
extends TestCase
# Musica: tracce sincronizzate a strati e dissolvenza tra le intensità.

func after() -> void:
	Music.stop()

func test_tracce_complete() -> void:
	for t in ["title", "crypt", "fungus", "forge", "abyss", "heart"]:
		for s in Music.STEMS:
			check(ResourceLoader.exists("res://assets/music/%s_%s.ogg" % [t, s]), "%s_%s" % [t, s])

func test_play_e_intensita() -> void:
	Music.play("crypt")
	eq(Music.track_name, "crypt")
	var st := Music.cur.stream as AudioStreamSynchronized
	eq(st.stream_count, 6)
	Music.set_intensity(0)
	Music.step(5.0)
	eq(Music.gains, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0])
	Music.set_intensity(2)
	Music.step(0.4)
	check(Music.gains[3] > 0.0 and Music.gains[3] < 1.0, "dissolvenza in corso")
	Music.step(5.0)
	eq(Music.gains, [1.0, 0.0, 0.0, 1.0, 1.0, 1.0])

func test_stessa_traccia_non_riparte() -> void:
	Music.play("title")
	var p := Music.cur
	Music.play("title")
	check(Music.cur == p, "stesso player")
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=music`
Expected: errore, `Music` non dichiarato.

- [ ] **Step 3: Aggiungere l'esportazione della musica**

In `tools/export_assets/export.js`. Le funzioni degli strati copiano le parti di `Music.playStep` (`js/audio.js`) con l'intensità fissata; il drone è `Music.startDrone` originale.
```js
// strati della musica: ognuno riproduce una parte di Music.playStep a intensità fissa
const STEMS = {
  drone: null,                                   // Music.startDrone
  arp_lo: (s, t) => stemArp(s, t, 0),
  arp: (s, t) => stemArp(s, t, 1),
  arp_hi: (s, t) => stemArp(s, t, 2),
  bass: (s, t) => { stemBass(s, t); stemKick(s, t); },
  hats: (s, t) => stemHats(s, t),
};
function stemChord(s) { const tr = Music.track; if (s % 16 === 0) Music.chord = tr.chords[(s / 16 | 0) % tr.chords.length]; return Music.chord; }
function stemArp(s, t, I) {
  const c = Sound.ctx, ch = stemChord(s);
  const pProb = I === 0 ? 0.3 : I === 1 ? 0.5 : 0.65;
  if (Math.random() < pProb || (s % 8 === 0)) {
    const tones = [0, 2, 4, 7];
    const deg = ch + pick(tones) + (Math.random() < 0.2 ? 1 : 0);
    const f = Music.noteFreq(deg, 2 + (Math.random() < 0.3 ? 1 : 0));
    const o = c.createOscillator(), g = c.createGain();
    o.type = I >= 2 ? 'square' : 'triangle'; o.frequency.value = f;
    const vol = I >= 2 ? 0.035 : 0.06;
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.6);
    const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1600;
    o.connect(lp); lp.connect(g); g.connect(Music.bus); g.connect(Music.delayIn);
    o.start(t); o.stop(t + 0.65);
  }
}
function stemBass(s, t) {
  const c = Sound.ctx, ch = stemChord(s);
  if (s % 4 !== 0) return;
  const f = Music.noteFreq(ch, 0);
  const o = c.createOscillator(), g = c.createGain(), lp = c.createBiquadFilter();
  o.type = 'sawtooth'; o.frequency.value = f; lp.type = 'lowpass'; lp.frequency.value = 300;
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.09, t + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
  o.connect(lp); lp.connect(g); g.connect(Music.bus); o.start(t); o.stop(t + 0.4);
}
function stemKick(s, t) {
  const c = Sound.ctx;
  if (s % 4 !== 0) return;
  const o = c.createOscillator(), g = c.createGain();
  o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(38, t + 0.15);
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.15, t + 0.005);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.2);
  o.connect(g); g.connect(Music.bus); o.start(t); o.stop(t + 0.25);
}
function stemHats(s, t) {
  const c = Sound.ctx;
  stemChord(s);
  if (s % 2 !== 1) return;
  const src = c.createBufferSource(); src.buffer = Sound.noiseBuf;
  const f = c.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 6000;
  const g = c.createGain();
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.03, t + 0.003);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.05);
  src.connect(f); f.connect(g); g.connect(Music.bus); src.start(t, Math.random() * 0.5); src.stop(t + 0.06);
}

// 32 battute (256 ottavi) per strato, con preroll per il drone e chiusura ad anello:
// la coda delle note viene sommata all'inizio, il drone si dissolve incrociato.
async function renderStem(name, stem, seed) {
  const SR = 44100, PRE = 4, TAIL = 2, STEPS = 256;
  const tr = TRACKS[name], stepDur = 60 / tr.tempo / 2;
  const L = STEPS * stepDur;
  const total = Math.ceil((PRE + L + TAIL) * SR);
  const r = new RNG(seed); Math.random = () => r.next();
  const oc = new OfflineAudioContext(1, total, SR);
  const out = oc.createGain(); out.gain.value = 1; out.connect(oc.destination);
  Sound.ctx = oc; Sound.musicGain = out; Sound.noiseBuf = makeNoise(oc);
  Music.init();
  Music.track = tr; Music.chord = 0;
  Music.delay.delayTime.value = 60 / tr.tempo * 0.75;
  if (stem === 'drone') Music.startDrone();
  else for (let s = 0; s < STEPS; s++) STEMS[stem](s, PRE + s * stepDur);
  const data = (await oc.startRendering()).getChannelData(0);
  const a = Math.floor(PRE * SR), n = Math.floor(L * SR), x = Math.floor(TAIL * SR);
  const loop = new Float32Array(n);
  for (let i = 0; i < n; i++) loop[i] = data[a + i];
  for (let i = 0; i < x; i++) {
    const tail = data[a + n + i];
    if (stem === 'drone') { const k = i / x; loop[i] = loop[i] * Math.sqrt(k) + tail * Math.sqrt(1 - k); }
    else loop[i] += tail;
  }
  return loop;
}
async function exportMusic() {
  let seed = 1;
  for (const name of Object.keys(TRACKS)) for (const stem of Object.keys(STEMS)) {
    const loop = await renderStem(name, stem, seed++);
    await exporter.write('music/' + name + '_' + stem + '.wav', wavB64(loop, 44100));
  }
  exporter.log('strati musicali: ' + Object.keys(TRACKS).length * Object.keys(STEMS).length);
}
```

- [ ] **Step 4: Esportare**

Run:
```bash
desktop/node_modules/.bin/electron tools/export_assets/main.js --only=music
ls godot/assets/music/*.ogg | wc -l && du -sh godot/assets/music
godot --headless --path godot --import
```
Expected: `strati musicali: 36`, `36`, dimensione totale intorno ai 20–30 MB.

- [ ] **Step 5: Implementare `Music`**

`godot/autoload/music.gd`:
```gdscript
extends Node
# Musica (da Music in js/audio.js): ogni traccia è un AudioStreamSynchronized di
# 6 strati registrati; l'intensità sceglie quali strati suonano, con dissolvenza.

const STEMS := ["drone", "arp_lo", "arp", "arp_hi", "bass", "hats"]
const MIX := [   # volume lineare di ogni strato alle intensità 0, 1, 2
	[1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
	[1.0, 0.0, 1.0, 0.0, 1.0, 1.0],
	[1.0, 0.0, 0.0, 1.0, 1.0, 1.0],
]
const FADE_IN := 2.5     # come la salita del drone nel JS
const FADE_OUT := 1.2
const MIX_SPEED := 1.25  # una dissolvenza completa tra intensità dura 0,8 s

var track_name := ""
var intensity := 0
var gains: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var cur: AudioStreamPlayer
var cur_fade := 0.0
var old: AudioStreamPlayer
var old_fade := 0.0

func play(track: String) -> void:
	if track == track_name:
		return
	track_name = track
	if old != null:
		old.queue_free()
	old = cur
	old_fade = cur_fade
	var s := AudioStreamSynchronized.new()
	s.stream_count = STEMS.size()
	for i in STEMS.size():
		var st: AudioStreamOggVorbis = load("res://assets/music/%s_%s.ogg" % [track, STEMS[i]])
		st.loop = true
		s.set_sync_stream(i, st)
	cur = AudioStreamPlayer.new()
	cur.bus = "Music"
	cur.stream = s
	add_child(cur)
	cur_fade = 0.0
	gains = MIX[intensity].duplicate()
	_apply()
	cur.play()

func set_intensity(i: int) -> void:
	intensity = clampi(i, 0, 2)

func stop() -> void:
	track_name = ""
	if old != null:
		old.queue_free()
	old = cur
	old_fade = cur_fade
	cur = null

func _process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if cur != null:
		cur_fade = minf(1.0, cur_fade + delta / FADE_IN)
		for i in STEMS.size():
			gains[i] = U.approach(gains[i], MIX[intensity][i], MIX_SPEED * delta)
		_apply()
	if old != null:
		old_fade = maxf(0.0, old_fade - delta / FADE_OUT)
		old.volume_db = linear_to_db(maxf(0.0001, old_fade))
		if old_fade <= 0.0:
			old.queue_free()
			old = null

func _apply() -> void:
	cur.volume_db = linear_to_db(maxf(0.0001, cur_fade))
	var s := cur.stream as AudioStreamSynchronized
	for i in STEMS.size():
		s.set_sync_stream_volume(i, linear_to_db(maxf(0.0001, gains[i])))
```

In `godot/project.godot`, `[autoload]`, dopo `Sfx`:
```ini
Music="*res://autoload/music.gd"
```

- [ ] **Step 6: Eseguire i test**

Run: `tools/test.sh --only=music`
Expected: 3 test superati.

- [ ] **Step 7: Verifica a orecchio delle dissolvenze**

Creare temporaneamente nello scratchpad una scena che chiama `Music.play("crypt")`, poi `Music.set_intensity(1)` dopo 5 s e `set_intensity(2)` dopo altri 5 s, ed eseguirla con `godot --path godot <scena>`. Deve sentirsi entrare basso e charleston, poi l'arpeggio diventa a onda quadra, senza salti né sfasamenti.

Se il cambio di volume degli strati non si sente mentre la traccia suona (cioè `set_sync_stream_volume` non agisce sulla riproduzione in corso), sostituire in `music.gd` l'`AudioStreamSynchronized` con 6 `AudioStreamPlayer` figli di un nodo traccia, avviati nello stesso frame, e applicare i `gains` al loro `volume_db`. Il test `test_play_e_intensita` va adattato a controllare `cur.get_child_count() == 6`.

- [ ] **Step 8: Commit**

```bash
git add tools/export_assets/export.js godot/assets/music godot/autoload/music.gd godot/project.godot godot/tests/test_music.gd
git commit -m "Musica a strati registrata dal JS e autoload Music

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Input, particelle, numeri fluttuanti, feedback globali

**Files:**
- Create: `godot/autoload/controls.gd`, `godot/autoload/fx.gd`, `godot/combat/particles.gd`, `godot/combat/floaters.gd`
- Modify: `godot/project.godot` (autoload `Fx`, `Controls`)
- Test: `godot/tests/test_controls.gd`, `godot/tests/test_fx.gd`

**Interfaces:**
- Produces:
  - autoload `Controls`: `last_device` (`"kb"`, `"mouse"`, `"pad"`), `mouse_moved_at` (ms), `sim: Dictionary` (chiavi `move: Vector2`, `aim: float`, `fire: bool`, `mouse: Vector2`, `device: String`, `pressed: Array[String]`), `device()`, `mouse_pos() -> Vector2`, `move() -> Vector2`, `arrow_aim() -> Variant` (angolo o `null`), `aim_angle(px, py, current) -> float`, `mouse_left()`, `mouse_left_pressed()`, `firing()`, `dash()`, `flare()`, `interact()`, `pause()`, `map()`, `slot() -> int`, `digit(i) -> bool`, `up()`, `down()`, `left()`, `right()`, `confirm()`, `back()`, `reroll()`, `end_tick()`.
  - autoload `Fx`: `shake_amt`, `hitstop_t`, `flash`, `flash_col`, `time`, `vis`, `vrnd(a, b)`, `shake(v)`, `hitstop(t)`, `screen_flash(col, a)`, `decay(dt)`, `offset() -> Vector2`, `reset()`.
  - `Particles` (statiche): `list`, `add(p) -> Dictionary`, `burst(x, y, n, color, spd := 60.0, life := 0.5, o := {})`, `update(dt)`, `draw(ci, above)`, `clear()`.
  - `Floaters` (statiche): `list`, `add(x, y, text, color := Txt.COLORS.w, o := {})`, `update(dt)`, `draw(ci)`, `clear()`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_controls.gd`:
```gdscript
extends TestCase
# Input: movimento normalizzato, mira dall'ultimo dispositivo, input simulato.

func after() -> void:
	Controls.sim.clear()
	for a in ["move_right", "move_down", "aim_left"]:
		Input.action_release(a)

func test_movimento_normalizzato() -> void:
	Input.action_press("move_right")
	Input.action_press("move_down")
	var m := Controls.move()
	near(m.length(), 1.0)
	near(m.x, sqrt(0.5))

func test_aim_follows_last_device() -> void:
	Controls.sim = {"device": "pad", "mouse": Vector2(300, 100)}
	eq(Controls.aim_angle(100, 104, 1.5), 1.5, "col gamepad il mouse non conta")
	Controls.sim = {"device": "mouse", "mouse": Vector2(300, 100)}
	near(Controls.aim_angle(100, 104, 1.5), 0.0, 1e-9, "mira verso il mouse (da y - 4)")
	Controls.sim = {"device": "pad", "mouse": Vector2(100, 300), "fire": true}
	near(Controls.aim_angle(100, 104, 0.0), PI / 2, 1e-9, "tasto sinistro premuto: mouse")
	Controls.sim = {"device": "mouse", "mouse": Vector2(300, 100), "aim": PI}
	eq(Controls.aim_angle(100, 104, 0.0), PI, "le frecce hanno la precedenza")

func test_pressioni_simulate_durano_un_tick() -> void:
	Controls.sim = {"pressed": ["dash", "slot_3"]}
	check(Controls.dash())
	eq(Controls.slot(), 2)
	Controls.end_tick()
	check(not Controls.dash())
	eq(Controls.slot(), -1)
```

`godot/tests/test_fx.gd`:
```gdscript
extends TestCase
# Particelle, numeri fluttuanti e feedback globali (limiti e decadimento come nel JS).

func before() -> void:
	Particles.clear()
	Floaters.clear()
	Fx.reset()
	U.seed_random(3)

func test_particelle_limitate_e_scadute() -> void:
	for i in 950:
		Particles.add({"x": 0.0, "y": 0.0, "life": 1.0})
	eq(Particles.list.size(), 901)
	Particles.update(1.01)
	eq(Particles.list.size(), 0)

func test_burst_e_attrito() -> void:
	Particles.burst(10, 10, 5, ["#ffffff", "#000000"], 60, 0.5, {"grav": 40})
	eq(Particles.list.size(), 5)
	var p: Dictionary = Particles.list[0]
	var vx0: float = p.vx
	Particles.update(0.1)
	near(p.vx, vx0 - vx0 * 2.0 * 0.1, 1e-9, "attrito predefinito 2")

func test_numeri_fluttuanti() -> void:
	for i in 90:
		Floaters.add(0, 0, "x")
	eq(Floaters.list.size(), 81)
	Floaters.update(0.81)
	eq(Floaters.list.size(), 0)

func test_scossa_rispetta_le_opzioni() -> void:
	Save.data.settings.shake = false
	Fx.shake(5)
	eq(Fx.shake_amt, 0.0)
	Save.data.settings.shake = true
	Fx.shake(5)
	eq(Fx.shake_amt, 5.0)
	Fx.screen_flash("#c02020", 0.35)
	Fx.decay(0.1)
	near(Fx.shake_amt, 2.0)
	near(Fx.flash, 0.1)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=fx`
Expected: errore, `Particles` non dichiarato.

- [ ] **Step 3: Implementare `Controls`**

`godot/autoload/controls.gd`:
```gdscript
extends Node
# Input (da Input e Act in js/core.js): tastiera, mouse e gamepad con la stessa
# mappatura del JS, ultimo dispositivo usato e input simulato per i test.

const DEAD := 0.22
const KEYS := {
	"move_left": [KEY_A], "move_right": [KEY_D], "move_up": [KEY_W], "move_down": [KEY_S],
	"aim_left": [KEY_LEFT], "aim_right": [KEY_RIGHT], "aim_up": [KEY_UP], "aim_down": [KEY_DOWN],
	"dash": [KEY_SPACE, KEY_SHIFT], "flare": [KEY_F], "interact": [KEY_E],
	"pause": [KEY_ESCAPE, KEY_P], "map": [KEY_TAB, KEY_M],
	"slot_1": [KEY_1, KEY_KP_1], "slot_2": [KEY_2, KEY_KP_2], "slot_3": [KEY_3, KEY_KP_3], "slot_4": [KEY_4, KEY_KP_4],
	"nav_up": [KEY_UP, KEY_W], "nav_down": [KEY_DOWN, KEY_S], "nav_left": [KEY_LEFT, KEY_A], "nav_right": [KEY_RIGHT, KEY_D],
	"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E], "back": [KEY_ESCAPE, KEY_BACKSPACE], "reroll": [KEY_R],
}
const PAD := {
	"dash": [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER], "flare": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER],
	"interact": [JOY_BUTTON_X], "pause": [JOY_BUTTON_START], "map": [JOY_BUTTON_BACK],
	"slot_1": [JOY_BUTTON_DPAD_UP], "slot_2": [JOY_BUTTON_DPAD_RIGHT], "slot_3": [JOY_BUTTON_DPAD_DOWN], "slot_4": [JOY_BUTTON_DPAD_LEFT],
	"nav_up": [JOY_BUTTON_DPAD_UP], "nav_down": [JOY_BUTTON_DPAD_DOWN], "nav_left": [JOY_BUTTON_DPAD_LEFT], "nav_right": [JOY_BUTTON_DPAD_RIGHT],
	"confirm": [JOY_BUTTON_A], "back": [JOY_BUTTON_B], "reroll": [JOY_BUTTON_Y],
}
const MOUSE := {"fire": [MOUSE_BUTTON_LEFT], "flare": [MOUSE_BUTTON_RIGHT]}

var last_device := "kb"
var mouse_moved_at := 0
var sim: Dictionary = {}

func _ready() -> void:
	for a in KEYS:
		_ensure(a)
		for k in KEYS[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for a in PAD:
		_ensure(a)
		for b in PAD[a]:
			var e := InputEventJoypadButton.new()
			e.button_index = b
			e.device = -1
			InputMap.action_add_event(a, e)
	for a in MOUSE:
		_ensure(a)
		for b in MOUSE[a]:
			var e := InputEventMouseButton.new()
			e.button_index = b
			InputMap.action_add_event(a, e)

func _ensure(a: String) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a, 0.5)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		last_device = "kb"
	elif event is InputEventMouseMotion:
		last_device = "mouse"
		mouse_moved_at = Time.get_ticks_msec()
	elif event is InputEventMouseButton and event.pressed:
		last_device = "mouse"
	elif event is InputEventJoypadButton and event.pressed:
		last_device = "pad"
	elif event is InputEventJoypadMotion and absf(event.axis_value) > DEAD:
		last_device = "pad"

func device() -> String:
	return sim.get("device", last_device)

func mouse_pos() -> Vector2:
	if sim.has("mouse"):
		return sim.mouse
	return get_viewport().get_mouse_position()

func _pressed(a: String) -> bool:
	return a in sim.get("pressed", []) or Input.is_action_just_pressed(a)

func _pad() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if pads.size() > 0 else -1

func _axis(axis: JoyAxis) -> float:
	var d := _pad()
	if d < 0:
		return 0.0
	var v := Input.get_joy_axis(d, axis)
	return 0.0 if absf(v) < DEAD else v

func move() -> Vector2:
	if sim.has("move"):
		return sim.move
	var x := 0.0
	var y := 0.0
	if Input.is_action_pressed("move_left"):
		x -= 1
	if Input.is_action_pressed("move_right"):
		x += 1
	if Input.is_action_pressed("move_up"):
		y -= 1
	if Input.is_action_pressed("move_down"):
		y += 1
	x += _axis(JOY_AXIS_LEFT_X)
	y += _axis(JOY_AXIS_LEFT_Y)
	var l := sqrt(x * x + y * y)
	if l > 1:
		x /= l
		y /= l
	return Vector2(x, y)

func arrow_aim() -> Variant:
	if sim.has("aim"):
		return sim.aim
	var x := 0.0
	var y := 0.0
	if Input.is_action_pressed("aim_left"):
		x -= 1
	if Input.is_action_pressed("aim_right"):
		x += 1
	if Input.is_action_pressed("aim_up"):
		y -= 1
	if Input.is_action_pressed("aim_down"):
		y += 1
	if x != 0 or y != 0:
		return atan2(y, x)
	var ax := _axis(JOY_AXIS_RIGHT_X)
	var ay := _axis(JOY_AXIS_RIGHT_Y)
	if sqrt(ax * ax + ay * ay) > 0.4:
		return atan2(ay, ax)
	return null

# mira del giocatore (updatePlayer): frecce o stick destro, poi il mouse
# se è l'ultimo dispositivo o il tasto sinistro è premuto, altrimenti resta
func aim_angle(px: float, py: float, current: float) -> float:
	var ka: Variant = arrow_aim()
	if ka != null:
		return ka
	if device() == "mouse" or mouse_left():
		var m := mouse_pos()
		return U.ang_to(px, py - 4, m.x, m.y)
	return current

func mouse_left() -> bool:
	return sim.get("fire", false) or Input.is_action_pressed("fire")

func mouse_left_pressed() -> bool:
	return _pressed("fire")

func firing() -> bool:
	var d := _pad()
	var trigger := d >= 0 and Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	return mouse_left() or arrow_aim() != null or trigger

func dash() -> bool: return _pressed("dash")
func flare() -> bool: return _pressed("flare")
func interact() -> bool: return _pressed("interact")
func pause() -> bool: return _pressed("pause")
func map() -> bool: return _pressed("map")
func up() -> bool: return _pressed("nav_up")
func down() -> bool: return _pressed("nav_down")
func left() -> bool: return _pressed("nav_left")
func right() -> bool: return _pressed("nav_right")
func confirm() -> bool: return _pressed("confirm")
func back() -> bool: return _pressed("back")
func reroll() -> bool: return _pressed("reroll")
func digit(i: int) -> bool: return _pressed("slot_%d" % i)

func slot() -> int:
	for i in 4:
		if _pressed("slot_%d" % (i + 1)):
			return i
	return -1

func end_tick() -> void:
	sim.erase("pressed")
```

- [ ] **Step 4: Implementare `Fx`, `Particles`, `Floaters`**

`godot/autoload/fx.gd`:
```gdscript
extends Node
# Feedback globali (FX in js/entities.js) e tempo di rendering (Render.time).

var shake_amt := 0.0
var hitstop_t := 0.0
var flash := 0.0
var flash_col := Color.WHITE
var time := 0.0
var vis := RNG.new(777)   # casualità solo visiva: non consuma la sequenza di gioco

func _process(_delta: float) -> void:
	time = Time.get_ticks_msec() / 1000.0

func shake(v: float) -> void:
	if Save.data.settings.shake:
		shake_amt = maxf(shake_amt, v)

func hitstop(t: float) -> void:
	hitstop_t = maxf(hitstop_t, t)

func screen_flash(c: Variant, a: float) -> void:
	flash_col = UiDraw.col(c)
	flash = maxf(flash, a)

# parte di updateCommon
func decay(dt: float) -> void:
	shake_amt = maxf(0.0, shake_amt - dt * 30)
	flash = maxf(0.0, flash - dt * 2.5)

# casualità per il disegno (rnd del JS dentro le funzioni draw*)
func vrnd(a: float, b: float) -> float:
	return vis.frange(a, b)

# scostamento dello scuotimento (drawWorld)
func offset() -> Vector2:
	if shake_amt > 0.1:
		return Vector2(U.jround(vrnd(-1, 1) * shake_amt), U.jround(vrnd(-1, 1) * shake_amt))
	return Vector2.ZERO

func reset() -> void:
	shake_amt = 0.0
	hitstop_t = 0.0
	flash = 0.0
```

`godot/combat/particles.gd` — porta `Particles` (`js/gfx.js:208-249`):
```gdscript
class_name Particles
extends RefCounted
# Particelle (da Particles in js/gfx.js).

static var list: Array = []

static func add(p: Dictionary) -> Dictionary:
	if list.size() > 900:
		list.pop_front()
	p.t = 0.0
	if p.get("life", 0.0) == 0.0:
		p.life = 0.5
	if p.get("size", 0.0) == 0.0:
		p.size = 1.0
	p.vx = p.get("vx", 0.0)
	p.vy = p.get("vy", 0.0)
	if p.get("drag") == null:
		p.drag = 2.0
	list.append(p)
	return p

static func burst(x: float, y: float, n: int, color: Variant, spd: float = 60.0, life: float = 0.5, o: Dictionary = {}) -> void:
	var spread: float = o.spread if o.get("spread", 0.0) != 0.0 else 0.6
	for i in n:
		var a: float = o.angle + U.rnd(-spread, spread) if o.has("angle") else U.rnd(TAU)
		var s := U.rnd(spd * 0.3, spd)
		add({
			"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "life": U.rnd(life * 0.6, life),
			"color": U.pick(color) if color is Array else color,
			"size": o.size if o.get("size", 0.0) != 0.0 else (2.0 if U.chance(0.3) else 1.0),
			"grav": o.get("grav", 0.0), "drag": o.get("drag"), "glow": o.get("glow", false),
			"shrink": o.get("shrink", true) != false, "above": o.get("above", false),
		})

static func update(dt: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var p: Dictionary = list[i]
		p.t += dt
		if p.t >= p.life:
			list.remove_at(i)
		else:
			p.vx -= p.vx * p.drag * dt
			p.vy -= p.vy * p.drag * dt
			p.vy += p.get("grav", 0.0) * dt
			p.x += p.vx * dt
			p.y += p.vy * dt
		i -= 1

static func draw(ci: CanvasItem, above: bool) -> void:
	var ga := UiDraw.alpha
	for p in list:
		if p.get("above", false) != above:
			continue
		var k: float = 1.0 - p.t / p.life
		var s: float = maxf(1.0, U.jround(p.size * (0.4 + k * 0.6))) if p.get("shrink", false) else p.size
		UiDraw.alpha = ga * (1.0 if p.get("fade", true) == false else minf(1.0, k * 1.6))
		UiDraw.px_rect(ci, p.x - s / 2.0, p.y - s / 2.0, s, s, p.color)
	UiDraw.alpha = ga

static func clear() -> void:
	list.clear()
```

`godot/combat/floaters.gd` — porta `Floaters` (`js/gfx.js:251-271`):
```gdscript
class_name Floaters
extends RefCounted
# Numeri e testi fluttuanti (da Floaters in js/gfx.js).

static var list: Array = []

static func add(x: float, y: float, text: Variant, color: Variant = null, o: Dictionary = {}) -> void:
	if list.size() > 80:
		list.pop_front()
	list.append({"x": x + U.rnd(-3, 3), "y": y, "text": str(text), "color": Txt.COLORS.w if color == null else color,
		"t": 0.0, "life": o.get("life", 0.8), "vy": o.get("vy", -28.0), "scale": o.get("scale", 1.0)})

static func update(dt: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var f: Dictionary = list[i]
		f.t += dt
		f.y += f.vy * dt
		f.vy *= 1 - 2.5 * dt
		if f.t > f.life:
			list.remove_at(i)
		i -= 1

static func draw(ci: CanvasItem) -> void:
	for f in list:
		var a: float = 1.0 - (f.t - f.life * 0.6) / (f.life * 0.4) if f.t > f.life * 0.6 else 1.0
		UiDraw.text(ci, f.text, f.x, f.y, {"align": "center", "color": f.color, "alpha": a, "scale": f.scale})

static func clear() -> void:
	list.clear()
```

In `godot/project.godot`, `[autoload]`, dopo `Music`:
```ini
Fx="*res://autoload/fx.gd"
Controls="*res://autoload/controls.gd"
```

- [ ] **Step 5: Eseguire i test**

Run: `tools/test.sh --only=fx && tools/test.sh --only=controls`
Expected: tutti superati.

- [ ] **Step 6: Commit**

```bash
git add godot/autoload/controls.gd godot/autoload/fx.gd godot/combat/particles.gd godot/combat/floaters.gd godot/project.godot godot/tests/test_controls.gd godot/tests/test_fx.gd
git commit -m "Input, particelle, numeri fluttuanti e feedback globali

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
## Fase C — Regole e dati

### Task 10: Tabelle dei dati e Resource

Le tabelle restano nell'**ordine esatto del JS** (le scelte casuali pesate dipendono dall'ordine delle chiavi). Gli effetti dei doni, delle reliquie e delle maledizioni sono funzioni `apply` con un `match` sull'id, invece delle lambda del JS.

**Files:**
- Create: `godot/data/stats.gd`, `godot/data/perks.gd`, `godot/data/relics.gd`, `godot/data/curses.gd`, `godot/data/statuses.gd`, `godot/data/elite_mods.gd`, `godot/data/consumables.gd`, `godot/data/lore.gd`
- Create: `godot/data/enemy_def.gd`, `godot/data/boss_def.gd`, `godot/data/biome_def.gd`, `godot/data/lantern_def.gd`, `godot/data/db.gd`
- Create: `godot/data/enemies/{rat,bat,skeleton,skull,ghoul}.tres`, `godot/data/bosses/bones.tres`, `godot/data/biomes/crypt.tres`, `godot/data/lanterns/{custode,pellegrino,spezzata,cava,nera}.tres`
- Test: `godot/tests/test_data.gd`

**Interfaces:**
- Produces:
  - `Stats`: `base() -> Dictionary` (le 66 chiavi di `baseStats`), `static var RARITY` (`[{name, col, w}]`), `depth_hp(d)`, `depth_dmg(d)`, `xp_need(L)`.
  - `Perks.ALL` (id → `{name, rar, max, icon, desc}`, con `onTake: true` per `hp`), `Perks.apply(id, s, n)`, `Perks.on_take(id, p)`.
  - `Relics.ALL` (id → `{name, icon, desc}`, più `curse` e `onTake` dove presenti), `Relics.apply(id, s)`, `Relics.on_take(id, p)`.
  - `Curses.ALL` (id → `{name, desc}`), `Curses.apply(id, s)`.
  - `Statuses.ALL` (id → `{name, icon, col, bad}`), `EliteMods.ALL` (id → `{name, col}`), `Cons.ALL` (id → `{name, spr, w, price, desc}`, `passive` per `feather`; `use` arriva nel Task 21), `Lore.ARDORE`, `Lore.MERCHANT_LINES`.
  - Resource: `EnemyDef`, `BossDef` (`id, name, title, spr, hp, r, spd, phases: Array`), `BiomeDef` (`id, name, music, boss, dark, lore, floor: Array, floor_d, wall, wall_d, wall_l, accent, pool: Array, deco, urns, barrels`), `LanternDef` (campi numerici, `unlocked(st) -> bool`, `apply_stats(s)`, `on_start(p)`).
  - `DB`: `LANTERN_IDS`, `BIOME_IDS := ["crypt"]`, `enemy(id) -> EnemyDef`, `boss(id) -> BossDef`, `lantern(id) -> LanternDef` (ripiego su `custode`), `lanterns() -> Array`, `biome_of(depth) -> BiomeDef`.
- Regola aggiuntiva: le chiavi che coincidono con nomi di funzioni GDScript (`range`, `max`) si leggono e scrivono con le parentesi quadre (`s["range"]`, `P["max"]`).

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_data.gd`:
```gdscript
extends TestCase
# Tabelle dei dati: conteggi, ordine e valori come in js/data.js.

func test_tabelle_e_ordine() -> void:
	eq(Perks.ALL.size(), 41)
	eq(Perks.ALL.keys()[0], "dmg")
	eq(Perks.ALL.keys()[40], "sun")
	eq(Relics.ALL.size(), 26)
	eq(Relics.ALL.keys()[25], "r_gauntlet")
	eq(Curses.ALL.keys(), ["c_dark", "c_frail", "c_greed", "c_haste", "c_blood", "c_fog", "c_weak", "c_rust"])
	eq(EliteMods.ALL.keys(), ["armored", "swift", "vampiric", "volatile", "regen", "splitter", "venom"])
	eq(Cons.ALL.keys(), ["potion", "bigpotion", "oil", "bomb", "antidote", "rage", "frost", "map", "firefly", "dice", "smoke", "holy", "feather"])
	eq(Statuses.ALL.size(), 11)
	eq(Stats.base().size(), 66)

func test_valori_campione() -> void:
	eq(Perks.ALL["range"].desc, "+^y20%^w gittata e +^y12%^w velocità dei proiettili.")
	eq(Relics.ALL.r_skull.curse, "c_frail")
	eq(Cons.ALL.feather.w, 1.5)
	check(Cons.ALL.feather.passive)
	var s := Stats.base()
	Perks.apply("range", s, 2)
	near(s["range"], 200 * 1.4)
	near(s.shotSpeed, 230 * 1.24)

func test_resource_nemici_e_boss() -> void:
	var rat := DB.enemy("rat")
	eq([rat.name, rat.hp, rat.spd, rat.ai, rat.side, rat.burst], ["Ratto di Cripta", 14.0, 74.0, "chaser", true, true])
	eq(DB.enemy("skull").shot, {"kind": "orb", "col": "violet", "spd": 68.0, "cd": 3.2, "ring": 6})
	eq(DB.enemy("ghoul").charge_spd, 225.0)
	var b := DB.boss("bones")
	eq([b.hp, b.r, b.phases.size(), b.phases[1].pats.size()], [800.0, 11.0, 2, 5])
	var c := DB.biome_of(1)
	eq(c.pool, [["rat", 1, 3], ["bat", 1, 3], ["skeleton", 2, 3], ["skull", 3, 2], ["ghoul", 3, 1.5]])
	eq(c.dark, 0.68)

func test_lanterne() -> void:
	eq(DB.LANTERN_IDS, ["custode", "pellegrino", "spezzata", "cava", "nera"])
	var st := Save.defaults().stats
	check(DB.lantern("custode").unlocked(st))
	check(not DB.lantern("pellegrino").unlocked(st))
	st.bossKills = 1
	check(DB.lantern("pellegrino").unlocked(st))
	eq(DB.lantern("inesistente").id, "custode")
	var s := Stats.base()
	DB.lantern("spezzata").apply_stats(s)
	eq(s.maxHp, 39.0)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=data`
Expected: errore, `Perks` non dichiarato.

- [ ] **Step 3: Tabelle in GDScript**

`godot/data/stats.gd`:
```gdscript
class_name Stats
extends RefCounted
# Statistiche di base del giocatore, rarità e scalature (da js/data.js e js/entities.js).

static var RARITY := [
	{"name": "Comune", "col": "#c8c0b0", "w": 62},
	{"name": "Raro", "col": "#6fa8e8", "w": 27},
	{"name": "Epico", "col": "#c57ae0", "w": 9},
	{"name": "Leggendario", "col": "#f6cf57", "w": 2.5},
]

static func base() -> Dictionary:
	return {
		"maxHp": 60, "dmg": 10, "dmgMult": 1, "fireRate": 3.0, "rateMult": 1, "shotSpeed": 230, "range": 200, "shotSize": 3,
		"proj": 1, "pierce": 0, "bounce": 0, "homing": 0, "crit": 0.05, "critMult": 2.0,
		"speed": 92, "speedMult": 1, "armor": 0, "dodge": 0, "dashCharges": 1, "dashCd": 1.0, "dashDist": 1, "iframes": 0.9,
		"maxOil": 100, "oilDrain": 1, "light": 104, "lightMult": 1, "pickup": 26, "coinMult": 1, "xpMult": 1, "healMult": 1,
		"leech": 0, "thorns": 0, "burn": 0, "poison": 0, "chill": 0, "chain": 0, "explode": 0, "orbit": 0, "flareCost": 40, "flareMult": 1,
		"fury": 0, "comet": 0, "split": 0, "berserk": 0, "secondwind": 0, "ashguard": 0, "guardian": 0, "primal": 0, "echo": 0, "sun": 0,
		"dashfire": 0, "critBurn": 0, "critHeal": 0, "dashReflect": 0, "noOilDrain": 0, "bellStun": 0, "immune": {}, "chillAll": 0,
		"storm": 0, "extraChoice": 0, "luck": 0, "revive": 0, "ashTrail": 0, "lowHpDmg": 0, "priceMult": 1,
		"enemySpeed": 1, "dmgTaken": 1, "mapReveal": 0, "hideMap": 0, "goldKeys": 0, "burnMult": 1,
	}

# scalature per profondità
static func depth_hp(d: int) -> float:
	return 1 + 0.6 * (d - 1) + 0.08 * (d - 1) * (d - 1)

static func depth_dmg(d: int) -> float:
	return 1 + 0.2 * (d - 1)

static func xp_need(level: int) -> float:
	return U.jround(12 + 7 * level + 1.5 * level * level)
```

`godot/data/perks.gd` — dati da `PERKS` (`js/data.js:31-73`), stesse stringhe:
```gdscript
class_name Perks
extends RefCounted
# Doni scelti al passaggio di livello (PERKS in js/data.js). L'ordine conta: non riordinare.

static var ALL := {
	"dmg": {"name": "Braci Vive", "rar": 0, "max": 5, "icon": "i_blade", "desc": "+^y18%^w danno dei proiettili."},
	"rate": {"name": "Mano Lesta", "rar": 0, "max": 5, "icon": "i_rate", "desc": "+^y14%^w cadenza di fuoco."},
	"speed": {"name": "Passo Felpato", "rar": 0, "max": 3, "icon": "i_boot", "desc": "+^y10%^w velocità di movimento."},
	"hp": {"name": "Cuore Robusto", "rar": 0, "max": 5, "icon": "i_heart", "desc": "+^y15^w vita massima e ne curi ^y15^w.", "onTake": true},
	"armor": {"name": "Pelle Conciata", "rar": 0, "max": 4, "icon": "i_shield", "desc": "+^y1^w armatura: riduce del ^y7%^w i danni subiti."},
	"crit": {"name": "Occhio Fino", "rar": 0, "max": 4, "icon": "i_eye", "desc": "+^y7%^w probabilità di colpo critico."},
	"range": {"name": "Braccio Lungo", "rar": 0, "max": 3, "icon": "i_range", "desc": "+^y20%^w gittata e +^y12%^w velocità dei proiettili."},
	"oilmax": {"name": "Serbatoio Ampio", "rar": 0, "max": 3, "icon": "i_drop", "desc": "+^y25^w olio massimo e +^y8%^w raggio di luce."},
	"magnet": {"name": "Calamita", "rar": 0, "max": 2, "icon": "i_magnet", "desc": "+^y60%^w raggio di raccolta."},
	"greed": {"name": "Dita d'Oro", "rar": 0, "max": 3, "icon": "i_coin", "desc": "+^y30%^w monete raccolte."},
	"xp": {"name": "Mente Accesa", "rar": 0, "max": 3, "icon": "i_book", "desc": "+^y15%^w esperienza ottenuta."},
	"thorns": {"name": "Spine di Rovo", "rar": 0, "max": 2, "icon": "i_thorn", "desc": "Chi ti tocca subisce il ^y150%^w del tuo danno."},
	"medic": {"name": "Erborista", "rar": 0, "max": 2, "icon": "i_flask", "desc": "Pozioni e cuori curano il ^y40%^w in più."},
	"multishot": {"name": "Doppio Stoppino", "rar": 1, "max": 3, "icon": "i_multi", "desc": "+^y1^w proiettile per raffica, ^r-8%^w danno."},
	"pierce": {"name": "Punta di Ferro", "rar": 1, "max": 3, "icon": "i_pierce", "desc": "I proiettili trapassano ^y1^w nemico in più."},
	"bounce": {"name": "Rimbalzo", "rar": 1, "max": 3, "icon": "i_bounce", "desc": "I proiettili rimbalzano sui muri ^y1^w volta in più."},
	"homing": {"name": "Fuoco Fatuo", "rar": 1, "max": 2, "icon": "i_wisp", "desc": "I proiettili curvano verso i nemici."},
	"burn": {"name": "Tizzone", "rar": 1, "max": 3, "icon": "i_flame", "desc": "^y18%^w di probabilità di ^oincendiare^w il bersaglio."},
	"poison": {"name": "Linfa Nera", "rar": 1, "max": 3, "icon": "i_poison", "desc": "^y20%^w di probabilità di ^gavvelenare^w. Il veleno si accumula."},
	"chill": {"name": "Brina", "rar": 1, "max": 3, "icon": "i_snow", "desc": "^y18%^w di probabilità di ^craffreddare^w. Tre cariche congelano."},
	"dash": {"name": "Gambe Agili", "rar": 1, "max": 2, "icon": "i_wing", "desc": "+^y1^w carica di scatto."},
	"dashfire": {"name": "Scia Ardente", "rar": 1, "max": 1, "icon": "i_flame", "desc": "Lo scatto lascia una ^oscia di fuoco^w che brucia i nemici."},
	"fury": {"name": "Frenesia", "rar": 1, "max": 2, "icon": "i_rate", "desc": "Ogni uccisione: +^y35%^w cadenza per ^y2.5^w secondi."},
	"dodge": {"name": "Riflessi", "rar": 1, "max": 3, "icon": "i_wing", "desc": "^y10%^w di probabilità di schivare un colpo."},
	"flare": {"name": "Vampata Feroce", "rar": 1, "max": 2, "icon": "i_sun", "desc": "La Vampata costa il ^y25%^w in meno e fa +^y50%^w danno."},
	"leech": {"name": "Sete", "rar": 1, "max": 3, "icon": "i_blood", "desc": "Ogni uccisione cura ^y1^w vita."},
	"critdmg": {"name": "Colpo Mortale", "rar": 1, "max": 3, "icon": "i_skull", "desc": "+^y50%^w danno dei colpi critici."},
	"oileff": {"name": "Stoppino Pulito", "rar": 1, "max": 2, "icon": "i_lantern", "desc": "L'olio si consuma il ^y35%^w più lentamente."},
	"chain": {"name": "Arco Voltaico", "rar": 2, "max": 3, "icon": "i_bolt", "desc": "^y15%^w di probabilità che un colpo scateni un ^bfulmine^w su 3 nemici."},
	"explode": {"name": "Ceneri Instabili", "rar": 2, "max": 2, "icon": "i_urn", "desc": "I nemici uccisi ^oesplodono^w ferendo quelli vicini."},
	"orbit": {"name": "Lucciole", "rar": 2, "max": 3, "icon": "i_orbit", "desc": "+^y1^w lucciola orbitante: ferisce i nemici e para i proiettili."},
	"split": {"name": "Schegge", "rar": 2, "max": 1, "icon": "i_star", "desc": "I proiettili si spezzano in ^y3^w schegge all'impatto."},
	"comet": {"name": "Cometa", "rar": 2, "max": 2, "icon": "i_moon", "desc": "Ogni pochi colpi parte una ^ycometa^w perforante da ^y300%^w danno."},
	"berserk": {"name": "Furore del Sangue", "rar": 2, "max": 1, "icon": "i_blood", "desc": "+^y1%^w danno per ogni ^y1%^w di vita mancante."},
	"secondwind": {"name": "Ultimo Respiro", "rar": 2, "max": 1, "icon": "i_heart", "desc": "Una volta per profondità sopravvivi a un colpo mortale."},
	"ashguard": {"name": "Corazza di Cenere", "rar": 2, "max": 1, "icon": "i_shield", "desc": "Quando vieni colpito rilasci un'^oonda di fuoco^w."},
	"guardian": {"name": "Lume Custode", "rar": 3, "max": 1, "icon": "i_lamp", "desc": "Ogni ^y10^w secondi uno scudo di luce assorbe un colpo."},
	"primal": {"name": "Fiamma Prima", "rar": 3, "max": 1, "icon": "i_flame", "desc": "Tutti i colpi ^oincendiano^w e la bruciatura fa il doppio."},
	"swarm": {"name": "Sciame Ardente", "rar": 3, "max": 1, "icon": "i_multi", "desc": "+^y2^w proiettili per raffica, ^r-12%^w danno."},
	"echo": {"name": "Eco", "rar": 3, "max": 1, "icon": "i_bell", "desc": "^y30%^w di probabilità di sparare una seconda raffica."},
	"sun": {"name": "Piccolo Sole", "rar": 3, "max": 1, "icon": "i_sun", "desc": "La tua luce ^obrucia^w i nemici che ti stanno vicino."},
}

static func apply(id: String, s: Dictionary, n: int) -> void:
	match id:
		"dmg": s.dmgMult += 0.18 * n
		"rate": s.rateMult += 0.14 * n
		"speed": s.speedMult += 0.10 * n
		"hp": s.maxHp += 15 * n
		"armor": s.armor += n
		"crit": s.crit += 0.07 * n
		"range":
			s["range"] *= 1 + 0.2 * n
			s.shotSpeed *= 1 + 0.12 * n
		"oilmax":
			s.maxOil += 25 * n
			s.lightMult += 0.08 * n
		"magnet": s.pickup *= 1 + 0.6 * n
		"greed": s.coinMult += 0.3 * n
		"xp": s.xpMult += 0.15 * n
		"thorns": s.thorns += 1.5 * n
		"medic": s.healMult += 0.4 * n
		"multishot":
			s.proj += n
			s.dmgMult -= 0.08 * n
		"pierce": s.pierce += n
		"bounce": s.bounce += n
		"homing": s.homing += n
		"burn": s.burn += 0.18 * n
		"poison": s.poison += 0.2 * n
		"chill": s.chill += 0.18 * n
		"dash": s.dashCharges += n
		"dashfire": s.dashfire = n
		"fury": s.fury += 0.35 * n
		"dodge": s.dodge += 0.1 * n
		"flare":
			s.flareCost *= pow(0.75, n)
			s.flareMult += 0.5 * n
		"leech": s.leech += n
		"critdmg": s.critMult += 0.5 * n
		"oileff": s.oilDrain *= pow(0.65, n)
		"chain": s.chain += 0.15 * n
		"explode": s.explode += n
		"orbit": s.orbit += n
		"split": s.split = n
		"comet": s.comet += n
		"berserk": s.berserk = n
		"secondwind": s.secondwind = n
		"ashguard": s.ashguard = n
		"guardian": s.guardian = n
		"primal":
			s.primal = n
			s.burnMult += 1
		"swarm":
			s.proj += 2
			s.dmgMult -= 0.12
		"echo": s.echo = 0.3
		"sun": s.sun = n

static func on_take(id: String, p) -> void:
	match id:
		"hp": p.heal(15, true)
```

`godot/data/relics.gd` — dati da `RELICS` (`js/data.js:78-105`); `curse` e `onTake` come nel JS:
```gdscript
class_name Relics
extends RefCounted
# Reliquie (RELICS in js/data.js). L'ordine conta: non riordinare.

static var ALL := {
	"r_stoneheart": {"name": "Cuore di Pietra", "icon": "i_heart", "desc": "+^y30^w vita massima. ^r-5%^w velocità.", "onTake": true},
	"r_mirror": {"name": "Specchio Incrinato", "icon": "i_mirror", "desc": "Scattando ^yrifletti^w i proiettili nemici vicini."},
	"r_crown": {"name": "Corona dell'Annegato", "icon": "i_crown", "desc": "+^y40%^w monete. I mercanti fanno lo sconto del ^y25%^w."},
	"r_skull": {"name": "Teschio Ridente", "icon": "i_skull", "desc": "+^y35%^w danno. ^pMaledizione:^w Fragilità.", "curse": "c_frail"},
	"r_lens": {"name": "Lente d'Ambra", "icon": "i_lens", "desc": "+^y12%^w critico. I critici ^oincendiano^w."},
	"r_wick": {"name": "Stoppino Eterno", "icon": "i_lantern", "desc": "L'olio non si consuma più col tempo."},
	"r_bell": {"name": "Campana Muta", "icon": "i_bell", "desc": "Entrando in una stanza i nemici restano ^ystorditi^w per 1.5 secondi."},
	"r_hourglass": {"name": "Clessidra Rotta", "icon": "i_hourglass", "desc": "+^y25%^w cadenza, +^y12%^w velocità. ^pMaledizione:^w Fretta.", "curse": "c_haste"},
	"r_tooth": {"name": "Dente di Vampiro", "icon": "i_tooth", "desc": "Ogni colpo critico cura ^y1^w vita."},
	"r_eye": {"name": "Terzo Occhio", "icon": "i_eye", "desc": "Rivela la mappa e le stanze segrete. +^y10%^w luce."},
	"r_quiver": {"name": "Faretra di Ossa", "icon": "i_quiver", "desc": "+^y2^w proiettili. ^r-10%^w cadenza."},
	"r_anvil": {"name": "Incudine", "icon": "i_anvil", "desc": "+^y50%^w danno, proiettili più grossi. ^r-20%^w cadenza."},
	"r_feather": {"name": "Piuma di Corvo", "icon": "i_wing", "desc": "+^y1^w carica di scatto, scatto più lungo e rapido a ricaricarsi."},
	"r_moth": {"name": "Ali di Falena", "icon": "i_wing", "desc": "Immune a ^gveleno^w e ^slentezza^w. +^y10%^w velocità."},
	"r_ember": {"name": "Brace del Primo Fuoco", "icon": "i_flame", "desc": "+^y1^w lucciola orbitante. La Vampata costa la metà."},
	"r_key": {"name": "Chiave dello Scheletro", "icon": "i_key", "desc": "+^y3^w chiavi. I forzieri dorati sono più generosi.", "onTake": true},
	"r_blood": {"name": "Patto di Sangue", "icon": "i_cup", "desc": "+^y60%^w danno sotto il 40% di vita. ^pMaledizione:^w Sangue Amaro.", "curse": "c_blood"},
	"r_ice": {"name": "Cuore di Brina", "icon": "i_ice", "desc": "Tutti i colpi ^craffreddano^w. Immune al gelo."},
	"r_storm": {"name": "Bottiglia di Tempesta", "icon": "i_storm", "desc": "Ogni 3 secondi un ^bfulmine^w colpisce un nemico (250% danno)."},
	"r_shell": {"name": "Guscio di Tartaruga", "icon": "i_shell", "desc": "+^y4^w armatura. ^r-12%^w velocità."},
	"r_clover": {"name": "Quadrifoglio Secco", "icon": "i_clover", "desc": "Doni più rari e una ^yquarta scelta^w a ogni livello."},
	"r_lamp": {"name": "Lampada del Minatore", "icon": "i_lamp", "desc": "+^y35%^w raggio di luce, +^y10%^w critico."},
	"r_coffin": {"name": "Chiodo di Bara", "icon": "i_coffin", "desc": "Alla morte ^yrinasci^w una volta con metà vita."},
	"r_ash": {"name": "Urna di Cenere", "icon": "i_urn", "desc": "I nemici uccisi lasciano ^ofiamme^w a terra."},
	"r_mask": {"name": "Maschera del Giullare", "icon": "i_mask", "desc": "+^y20%^w schivata. ^pMaledizione:^w Nebbia.", "curse": "c_fog"},
	"r_gauntlet": {"name": "Guanto del Fabbro", "icon": "i_hand", "desc": "+^y20%^w danno, +^y2^w armatura, proiettili trapassano +^y1^w."},
}

static func apply(id: String, s: Dictionary) -> void:
	match id:
		"r_stoneheart":
			s.maxHp += 30
			s.speedMult -= 0.05
		"r_mirror": s.dashReflect = 1
		"r_crown":
			s.coinMult += 0.4
			s.priceMult *= 0.75
		"r_skull": s.dmgMult += 0.35
		"r_lens":
			s.crit += 0.12
			s.critBurn = 1
		"r_wick": s.noOilDrain = 1
		"r_bell": s.bellStun = 1.5
		"r_hourglass":
			s.rateMult += 0.25
			s.speedMult += 0.12
		"r_tooth": s.critHeal = 1
		"r_eye":
			s.mapReveal = 1
			s.lightMult += 0.1
		"r_quiver":
			s.proj += 2
			s.rateMult -= 0.1
		"r_anvil":
			s.dmgMult += 0.5
			s.rateMult -= 0.2
			s.shotSize += 1
		"r_feather":
			s.dashCharges += 1
			s.dashDist += 0.3
			s.dashCd *= 0.8
		"r_moth":
			s.immune.poison = 1
			s.immune.slow = 1
			s.speedMult += 0.1
		"r_ember":
			s.orbit += 1
			s.flareCost *= 0.5
		"r_key": s.goldKeys = 1
		"r_blood": s.lowHpDmg = 0.6
		"r_ice":
			s.chillAll = 1
			s.immune.chill = 1
		"r_storm": s.storm = 1
		"r_shell":
			s.armor += 4
			s.speedMult -= 0.12
		"r_clover":
			s.extraChoice = 1
			s.luck += 1
		"r_lamp":
			s.lightMult += 0.35
			s.crit += 0.1
		"r_coffin": s.revive = 1
		"r_ash": s.ashTrail = 1
		"r_mask": s.dodge += 0.2
		"r_gauntlet":
			s.dmgMult += 0.2
			s.armor += 2
			s.pierce += 1

static func on_take(id: String, p) -> void:
	match id:
		"r_stoneheart": p.heal(30, true)
		"r_key": p.keys += 3
```

`godot/data/curses.gd` — da `CURSES` (`js/data.js:110-119`):
```gdscript
class_name Curses
extends RefCounted
# Maledizioni (CURSES in js/data.js). L'ordine conta: non riordinare.

static var ALL := {
	"c_dark": {"name": "Buio Pesto", "desc": "^r-25%^w raggio di luce."},
	"c_frail": {"name": "Fragilità", "desc": "^r+20%^w danni subiti."},
	"c_greed": {"name": "Avarizia", "desc": "Prezzi dei mercanti ^r+40%^w."},
	"c_haste": {"name": "Fretta", "desc": "I nemici sono più veloci del ^r12%^w."},
	"c_blood": {"name": "Sangue Amaro", "desc": "Le cure sono ^r40%^w meno efficaci."},
	"c_fog": {"name": "Nebbia", "desc": "La minimappa è nascosta."},
	"c_weak": {"name": "Debolezza", "desc": "^r-12%^w danno."},
	"c_rust": {"name": "Ruggine", "desc": "^r-1^w armatura e ^r-10%^w cadenza."},
}

static func apply(id: String, s: Dictionary) -> void:
	match id:
		"c_dark": s.lightMult -= 0.25
		"c_frail": s.dmgTaken *= 1.2
		"c_greed": s.priceMult *= 1.4
		"c_haste": s.enemySpeed *= 1.12
		"c_blood": s.healMult -= 0.4
		"c_fog": s.hideMap = 1
		"c_weak": s.dmgMult -= 0.12
		"c_rust":
			s.armor -= 1
			s.rateMult -= 0.1
```

`godot/data/statuses.gd` — da `STATUS` (`js/data.js:124-136`):
```gdscript
class_name Statuses
extends RefCounted
# Stati alterati (STATUS in js/data.js).

static var ALL := {
	"burn": {"name": "Bruciatura", "icon": "s_burn", "col": "#f29c38", "bad": true},
	"poison": {"name": "Veleno", "icon": "s_poison", "col": "#8fd35a", "bad": true},
	"chill": {"name": "Gelo", "icon": "s_chill", "col": "#7fd8e6", "bad": true},
	"slow": {"name": "Lentezza", "icon": "s_slow", "col": "#b8b2c2", "bad": true},
	"weak": {"name": "Debolezza", "icon": "s_weak", "col": "#e0574a", "bad": true},
	"fragile": {"name": "Fragilità", "icon": "s_fragile", "col": "#e0574a", "bad": true},
	"blind": {"name": "Accecamento", "icon": "s_blind", "col": "#8a8294", "bad": true},
	"rage": {"name": "Ira", "icon": "s_rage", "col": "#f29c38", "bad": false},
	"immune": {"name": "Purezza", "icon": "s_shield", "col": "#7fd8e6", "bad": false},
	"invis": {"name": "Invisibile", "icon": "s_invis", "col": "#b8b2c2", "bad": false},
	"fury": {"name": "Frenesia", "icon": "s_rage", "col": "#f6cf57", "bad": false},
}
```

`godot/data/elite_mods.gd` — da `ELITE_MODS` (`js/data.js:186-194`):
```gdscript
class_name EliteMods
extends RefCounted
# Modificatori dei campioni d'élite (ELITE_MODS in js/data.js). L'ordine conta.

static var ALL := {
	"armored": {"name": "Corazzato", "col": "#a59fb0"},
	"swift": {"name": "Rapido", "col": "#f6cf57"},
	"vampiric": {"name": "Vampirico", "col": "#e0574a"},
	"volatile": {"name": "Instabile", "col": "#f29c38"},
	"regen": {"name": "Rigenerante", "col": "#8fd35a"},
	"splitter": {"name": "Scisso", "col": "#c57ae0"},
	"venom": {"name": "Velenoso", "col": "#6fc04a"},
}
```

`godot/data/consumables.gd` — dati da `CONS` (`js/data.js:141-155`), senza `use` (arriva nel Task 21):
```gdscript
class_name Cons
extends RefCounted
# Consumabili (CONS in js/data.js): 4 slot, si impilano fino a 3. L'ordine conta.

static var ALL := {
	"potion": {"name": "Pozione Rossa", "spr": "potion", "w": 10, "price": 14, "desc": "Cura ^y30^w vita."},
	"bigpotion": {"name": "Elisir Vitale", "spr": "bigpotion", "w": 2, "price": 30, "desc": "Cura ^ytutta^w la vita."},
	"oil": {"name": "Fiaschetta d'Olio", "spr": "oilflask", "w": 8, "price": 10, "desc": "Ricarica ^y60^w olio."},
	"bomb": {"name": "Bomba", "spr": "bomb", "w": 9, "price": 9, "desc": "Esplode dopo poco: ^y80^w danni ad area. Sfonda rocce incrinate e passaggi segreti."},
	"antidote": {"name": "Antidoto", "spr": "antidote", "w": 6, "price": 10, "desc": "Rimuove tutti i malus e ne protegge per ^y6^w secondi."},
	"rage": {"name": "Grappa del Minatore", "spr": "rage", "w": 6, "price": 12, "desc": "+^y50%^w danno e cadenza per ^y10^w secondi."},
	"frost": {"name": "Fiala di Gelo", "spr": "frost", "w": 5, "price": 14, "desc": "^cCongela^w tutti i nemici della stanza per ^y3^w secondi."},
	"map": {"name": "Pergamena", "spr": "scroll", "w": 4, "price": 8, "desc": "Rivela la mappa della profondità, segreti inclusi."},
	"firefly": {"name": "Barattolo di Lucciole", "spr": "jar", "w": 5, "price": 12, "desc": "^y3^w lucciole ti proteggono per ^y25^w secondi."},
	"dice": {"name": "Dado Truccato", "spr": "dice", "w": 3, "price": 18, "desc": "Ottieni un dono casuale. ^r30%^w di ricevere anche una maledizione."},
	"smoke": {"name": "Polvere d'Ombra", "spr": "pouch", "w": 4, "price": 10, "desc": "Diventi ^sinvisibile^w per ^y4^w secondi."},
	"holy": {"name": "Acqua Santa", "spr": "holy", "w": 2, "price": 28, "desc": "Rimuove una ^pmaledizione^w. Senza maledizioni cura 30 vita."},
	"feather": {"name": "Piuma di Fenice", "spr": "feather", "w": 1.5, "price": 35, "desc": "Passiva: se muori, ^yrinasci^w con metà vita (si consuma).", "passive": true},
}
```

`godot/data/lore.gd` — da `ARDORE` e `MERCHANT_LINES` (`js/data.js:381-398`):
```gdscript
class_name Lore
extends RefCounted
# Testi di contorno (ARDORE e MERCHANT_LINES in js/data.js).

const ARDORE := [
	"Il viaggio come fu tramandato.",
	"Nemici: +^r25%^w vita.",
	"In più: nemici +^r20%^w danno.",
	"In più: i campioni d'élite sono il doppio.",
	"In più: cure ^r-30%^w, meno cuori a terra.",
	"In più: boss più rapidi e l'olio brucia ^r50%^w più in fretta.",
]

const MERCHANT_LINES := [
	"Luce in cambio di monete, viandante.",
	"Non chiedere da dove vengono. Paga e basta.",
	"Ogni lanterna che scende... io la vedo risalire di rado.",
	"Questi prezzi? Il buio costa caro a tutti.",
	"Hai l'aria di chi ha bisogno di una pozione.",
]
```

- [ ] **Step 4: Resource e file `.tres`**

`godot/data/enemy_def.gd`:
```gdscript
class_name EnemyDef
extends Resource
# Statistiche di un nemico (ENEMIES in js/data.js).

@export var id := ""
@export var name := ""
@export var spr := ""
@export var hp := 0.0
@export var spd := 0.0
@export var dmg := 0.0
@export var r := 0.0
@export var ai := ""
@export var xp := 0.0
@export var fly := false
@export var side := false        # sprite di profilo (si gira con la direzione)
@export var burst := false       # avanza a scatti (ratto)
@export var anim := 0.0          # velocità d'animazione; 0 = predefinita (5)
@export var trail := false
@export var split := ""
@export var split_n := 0
@export var death_cloud := false
@export var keep := 0.0          # distanza mantenuta dai lanciatori
@export var charge_spd := 0.0
@export var hop_cd := 0.0
@export var land_ring := 0
@export var shield := false
@export var slam := false
@export var touch := ""
@export var summon := ""
@export var shot: Dictionary = {}   # kind, col, spd, cd, n, spread, ring, burst, aimed, status, arms
```

`godot/data/boss_def.gd`:
```gdscript
class_name BossDef
extends Resource
# Guardiano di fine profondità (BOSSES in js/data.js).

@export var id := ""
@export var name := ""
@export var title := ""
@export var spr := ""
@export var hp := 0.0
@export var r := 0.0
@export var spd := 0.0
@export var phases: Array = []   # [{at, gap, pats: [{p, ...}]}]
```

`godot/data/biome_def.gd`:
```gdscript
class_name BiomeDef
extends Resource
# Profondità e suo aspetto (BIOMES in js/data.js).

@export var id := ""
@export var name := ""
@export var music := ""
@export var boss := ""
@export var dark := 0.7
@export_multiline var lore := ""
@export var floor: Array = []       # tre colori del pavimento
@export var floor_d := ""
@export var wall := ""
@export var wall_d := ""
@export var wall_l := ""
@export var accent := ""
@export var pool: Array = []        # [tipo, costo, peso]
@export var deco := ""
@export var urns := false
@export var barrels := false
```

`godot/data/lantern_def.gd`:
```gdscript
class_name LanternDef
extends Resource
# Lanterna iniziale (LANTERNS in js/data.js). Effetti sulle statistiche come campi,
# così si modificano dall'Inspector.

@export var id := ""
@export var name := ""
@export var glass := "#f6cf57"
@export_multiline var desc := ""
@export var unlock_stat := ""    # chiave di Save.data.stats; "" = sempre disponibile
@export var unlock_min := 0
@export var unlock_text := ""
@export var max_hp_add := 0.0
@export var max_hp_mult := 1.0
@export var armor_add := 0.0
@export var speed_mult_add := 0.0
@export var rate_mult_add := 0.0
@export var dmg_mult_add := 0.0
@export var crit_add := 0.0
@export var max_oil_add := 0.0
@export var flare_cost_mult := 1.0
@export var light_mult_add := 0.0
@export var dash_charges_add := 0
@export var start_cons: Array[String] = []
@export var start_perks: Array[String] = []
@export var random_relics := 0
@export var random_curses := 0

func unlocked(st: Dictionary) -> bool:
	return unlock_stat == "" or st.get(unlock_stat, 0) >= unlock_min

func apply_stats(s: Dictionary) -> void:
	s.maxHp += max_hp_add
	if max_hp_mult != 1.0:
		s.maxHp = U.jround(s.maxHp * max_hp_mult)
	s.armor += armor_add
	s.speedMult += speed_mult_add
	s.rateMult += rate_mult_add
	s.dmgMult += dmg_mult_add
	s.crit += crit_add
	s.maxOil += max_oil_add
	s.flareCost *= flare_cost_mult
	s.lightMult += light_mult_add
	s.dashCharges += dash_charges_add

# start() del JS
func on_start(p) -> void:
	for c in start_cons:
		p.give_cons(c)
	for k in start_perks:
		p.perks[k] = 1
	if random_relics > 0:
		var pool := Relics.ALL.keys().filter(func(k): return not Relics.ALL[k].has("curse"))
		U.shuffle(pool)
		var cs := Curses.ALL.keys().filter(func(c): return c != "c_fog")
		U.shuffle(cs)
		for i in random_relics:
			p.relics.append(pool[i])
		for i in random_curses:
			p.curses.append(cs[i])
		for i in random_relics:
			Relics.on_take(pool[i], p)
```
Nota sull'ordine delle chiamate casuali: il JS mescola le reliquie, poi le maledizioni, poi applica `onTake`; il codice sopra rispetta lo stesso ordine.

`godot/data/db.gd`:
```gdscript
class_name DB
extends RefCounted
# Accesso alle Resource dei dati di gioco.

const LANTERN_IDS := ["custode", "pellegrino", "spezzata", "cava", "nera"]
const BIOME_IDS := ["crypt"]   # le altre profondità arriveranno con i prossimi sotto-progetti
static var _cache: Dictionary = {}

static func _res(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

static func enemy(id: String) -> EnemyDef:
	return _res("res://data/enemies/%s.tres" % id)

static func boss(id: String) -> BossDef:
	return _res("res://data/bosses/%s.tres" % id)

static func lantern(id: String) -> LanternDef:
	var l := _res("res://data/lanterns/%s.tres" % id) as LanternDef
	return l if l != null else _res("res://data/lanterns/custode.tres")

static func lanterns() -> Array:
	return LANTERN_IDS.map(func(id): return lantern(id))

static func biome_of(depth: int) -> BiomeDef:
	return _res("res://data/biomes/%s.tres" % BIOME_IDS[(depth - 1) % BIOME_IDS.size()])
```

File `.tres` (formato testuale di Godot). Esempio completo, `godot/data/enemies/rat.tres`:
```
[gd_resource type="Resource" script_class="EnemyDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/enemy_def.gd" id="1"]

[resource]
script = ExtResource("1")
id = "rat"
name = "Ratto di Cripta"
spr = "rat"
hp = 14.0
spd = 74.0
dmg = 8.0
r = 5.0
ai = "chaser"
xp = 1.0
side = true
burst = true
```
Gli altri, con la stessa intestazione e solo i campi diversi dai predefiniti (valori da `js/data.js:161-165`):
- `bat.tres`: `id = "bat"`, `name = "Pipistrello"`, `spr = "bat"`, `hp = 10.0`, `spd = 62.0`, `dmg = 7.0`, `r = 5.0`, `ai = "erratic"`, `xp = 1.0`, `fly = true`, `anim = 10.0`.
- `skeleton.tres`: `id = "skeleton"`, `name = "Scheletro"`, `spr = "skeleton"`, `hp = 28.0`, `spd = 30.0`, `dmg = 10.0`, `r = 6.0`, `ai = "shooter"`, `xp = 2.0`, `shot = {"kind": "bone", "spd": 110.0, "cd": 2.4, "n": 1}`.
- `skull.tres`: `id = "skull"`, `name = "Teschio Fatuo"`, `spr = "skull"`, `hp = 24.0`, `spd = 26.0`, `dmg = 8.0`, `r = 6.0`, `ai = "caster"`, `xp = 3.0`, `fly = true`, `keep = 90.0`, `shot = {"kind": "orb", "col": "violet", "spd": 68.0, "cd": 3.2, "ring": 6}`.
- `ghoul.tres`: `id = "ghoul"`, `name = "Ghoul"`, `spr = "ghoul"`, `hp = 46.0`, `spd = 36.0`, `dmg = 12.0`, `r = 7.0`, `ai = "charger"`, `xp = 3.0`, `charge_spd = 225.0`.

`godot/data/bosses/bones.tres` (intestazione con `script_class="BossDef"` e `path="res://data/boss_def.gd"`):
```
[resource]
script = ExtResource("1")
id = "bones"
name = "Il Custode delle Ossa"
title = "Re delle Cripte Dimenticate"
spr = "boss_bones"
hp = 800.0
r = 11.0
spd = 34.0
phases = [{"at": 1.0, "gap": 1.0, "pats": [{"p": "aimed", "n": 5, "spread": 0.5, "count": 3, "gap": 0.5, "spd": 115.0, "kind": "bone"}, {"p": "ring", "n": 12, "count": 2, "gap": 0.7, "spd": 75.0, "kind": "bone"}, {"p": "summon", "type": "skeleton", "count": 2, "cap": 4}, {"p": "charge", "count": 2, "spd": 210.0}]}, {"at": 0.5, "gap": 0.6, "pats": [{"p": "spiral", "arms": 3, "rate": 9.0, "rot": 2.2, "dur": 3.2, "spd": 85.0, "kind": "bone"}, {"p": "aimed", "n": 7, "spread": 0.8, "count": 3, "gap": 0.45, "spd": 125.0, "kind": "bone"}, {"p": "summon", "type": "rat", "count": 3, "cap": 6}, {"p": "charge", "count": 3, "spd": 245.0, "ring": 8, "kind": "bone"}, {"p": "ring", "n": 16, "count": 3, "gap": 0.55, "spd": 80.0, "kind": "bone"}]}]
```

`godot/data/biomes/crypt.tres` (`script_class="BiomeDef"`, `path="res://data/biome_def.gd"`):
```
[resource]
script = ExtResource("1")
id = "crypt"
name = "Le Cripte"
music = "crypt"
boss = "bones"
dark = 0.68
lore = "Sotto la città spenta riposano i primi custodi. Le loro ossa non hanno dimenticato come si combatte."
floor = ["#2a2430", "#241f2a", "#2e2834"]
floor_d = "#1a1520"
wall = "#3c3448"
wall_d = "#231c2a"
wall_l = "#544a62"
accent = "#6b5a80"
pool = [["rat", 1, 3], ["bat", 1, 3], ["skeleton", 2, 3], ["skull", 3, 2], ["ghoul", 3, 1.5]]
deco = "bones"
urns = true
```

Lanterne (`script_class="LanternDef"`, `path="res://data/lantern_def.gd"`), valori da `js/data.js:338-379`:
- `custode.tres`: `id = "custode"`, `name = "Lanterna del Custode"`, `glass = "#f6cf57"`, `desc = "Equilibrata e affidabile. Parti con una ^yPozione Rossa^w e una ^yBomba^w."`, `start_cons = Array[String](["potion", "bomb"])`.
- `pellegrino.tres`: `name = "Lanterna del Pellegrino"`, `glass = "#8fd35a"`, `desc = "+^y25^w vita, +^y2^w armatura, ^r-8%^w velocità e cadenza. Parti con due ^yBombe^w e una ^yPozione^w."`, `unlock_stat = "bossKills"`, `unlock_min = 1`, `unlock_text = "Sconfiggi un guardiano di profondità."`, `max_hp_add = 25.0`, `armor_add = 2.0`, `speed_mult_add = -0.08`, `rate_mult_add = -0.08`, `start_cons = Array[String](["bomb", "bomb", "potion"])`.
- `spezzata.tres`: `name = "Lanterna Spezzata"`, `glass = "#e0574a"`, `desc = "+^y35%^w danno, +^y10%^w critico, ^r-35%^w vita massima. Parti con il dono ^oTizzone^w."`, `unlock_stat = "bestDepth"`, `unlock_min = 3`, `unlock_text = "Raggiungi la terza profondità."`, `dmg_mult_add = 0.35`, `crit_add = 0.1`, `max_hp_mult = 0.65`, `start_perks = Array[String](["burn"])`.
- `cava.tres`: `name = "Lanterna Cava"`, `glass = "#7fd8e6"`, `desc = "+^y50^w olio, Vampata ^y-40%^w costo, +^y25%^w luce, +^y1^w scatto. ^r-10%^w danno."`, `unlock_stat = "bestDepth"`, `unlock_min = 4`, `unlock_text = "Raggiungi la quarta profondità."`, `max_oil_add = 50.0`, `flare_cost_mult = 0.6`, `light_mult_add = 0.25`, `dash_charges_add = 1`, `dmg_mult_add = -0.1`, `start_cons = Array[String](["oil"])`.
- `nera.tres`: `name = "Lanterna Nera"`, `glass = "#c57ae0"`, `desc = "Parti con ^ydue reliquie^w casuali e ^pdue maledizioni^w. Per chi non teme il buio."`, `unlock_stat = "wins"`, `unlock_min = 1`, `unlock_text = "Riaccendi la Fiamma Prima almeno una volta."`, `random_relics = 2`, `random_curses = 2`.

- [ ] **Step 5: Eseguire i test**

Run: `tools/test.sh --only=data`
Expected: 4 test superati.

- [ ] **Step 6: Commit**

```bash
git add godot/data godot/tests/test_data.gd
git commit -m "Dati di gioco: tabelle e Resource di nemici, boss, bioma e lanterne

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Giocatore — statistiche ed economia; stato della run

**Files:**
- Create: `godot/actors/player.gd` (campi e metodi senza aggiornamento né disegno)
- Create: `godot/autoload/run.gd`
- Modify: `godot/project.godot` (autoload `Run` dopo `Controls`)
- Modify: `godot/data/stats.gd` (aggiunge `ard_hp`, `ard_dmg`)
- Modify: `godot/data/perks.gd` (aggiunge `roll_choices`)
- Test: `godot/tests/test_stats.gd`, `godot/tests/test_player.gd`

**Interfaces:**
- Consumes: `stats.json`, `formulas.json` (Task 2); tabelle del Task 10.
- Produces:
  - `Player extends Node2D`: campi `x, y, vx, vy, r, hp, oil, xp, level, coins, keys, aim, fire_cd, dash_t, dash_cd, dash_charges, dash_dx, dash_dy, inv, statuses, perks, relics, curses, cons, shot_count, flare_cd, guard_t, guard_up, secondwind_used, coffin_used, temp_orbit, temp_orbit_t, orbit_a, sun_t, storm_t, trail_t, echo_t, anim, moving, lantern, stats, dead, last_hit, facing, base_hp_mod`; metodi `recalc_stats()`, `damage() -> float`, `fire_rate() -> float`, `speed() -> float`, `light() -> float`, `damage_taken(amount) -> int`, `heal(v, raw := false)`, `add_oil(v)`, `add_coins(v) -> int`, `give_cons(id) -> bool`, `can_take_cons(id) -> bool`, `add_xp(v)`.
  - autoload `Run`: tutti i campi della `run` del JS in `snake_case` (vedi codice), `reset()`, `toast(text, col := "#ece6d8", sub := "")`, `banner(title, desc, col, icon)`, `update_notices(dt)`.
  - `Stats.ard_hp()`, `Stats.ard_dmg()`; `Perks.roll_choices(n, min_rar := 0) -> Array`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_stats.gd`:
```gdscript
extends TestCase
# recalcStats, pDamage, pFireRate, pSpeed, pLight, rollPerkChoices e formule: confronto con il JS.

func after() -> void:
	Run.reset()

func _player(c: Dictionary) -> Player:
	Run.reset()
	Run.active = true
	Run.ardore = int(c.get("ardore", 0))
	var p := Player.new()
	p.lantern = c.get("lantern", "custode")
	for k in c.get("perks", {}):
		p.perks[k] = int(c.perks[k])
	p.relics = Array(c.get("relics", []))
	p.curses = Array(c.get("curses", []))
	p.base_hp_mod = c.get("baseHpMod", 0.0)
	p.hp = 9999
	p.oil = 9999
	p.dash_charges = 99
	Run.player = p
	p.recalc_stats()
	return p

func test_statistiche_come_il_js() -> void:
	for c in TestCase.golden("stats").cases:
		var p := _player(c)
		var d := TestCase.diff(p.stats, c.stats, "stats")
		if d != "":
			fail("%s %s %s %s: %s" % [c.lantern, c.perks, c.relics, c.curses, d])
			return
		for dv in c.derived:
			p.statuses = {}
			for k in dv.statuses:
				p.statuses[k] = {"t": 1.0, "stacks": 1, "tick": 0.0, "power": 0.0}
			p.hp = p.stats.maxHp * dv.hpFrac
			p.oil = p.stats.maxOil * dv.oilFrac
			near(p.damage(), dv.damage, 1e-9, "damage %s" % [dv])
			near(p.fire_rate(), dv.fireRate, 1e-9, "fireRate %s" % [dv])
			near(p.speed(), dv.speed, 1e-9, "speed %s" % [dv])
			near(p.light(), dv.light, 1e-9, "light %s" % [dv])

func test_scelta_dei_doni_come_il_js() -> void:
	for c in TestCase.golden("stats").perkRolls:
		var p := _player({"perks": c.perks, "relics": c.relics})
		Run.depth = int(c.depth)
		U.seed_random(int(c.seed))
		eq(Perks.roll_choices(int(c.n), int(c.minRar)), c.out, "seme %d" % c.seed)

func test_formule() -> void:
	var f: Dictionary = TestCase.golden("formulas")
	for c in f.xpNeed:
		eq(Stats.xp_need(int(c[0])), c[1])
	for c in f.depthHp:
		eq(Stats.depth_hp(int(c[0])), c[1])
	for c in f.depthDmg:
		eq(Stats.depth_dmg(int(c[0])), c[1])
	var p := _player({})
	for c in f.hurt:
		p.stats.dmgTaken = c[1]
		p.stats.armor = c[2]
		p.statuses = {"fragile": {"t": 1.0}} if c[3] else {}
		p.oil = 0.0 if c[4] else 50.0
		eq(p.damage_taken(c[0]), c[5], "hurt %s" % [c])
```

`godot/tests/test_player.gd`:
```gdscript
extends TestCase
# Economia del giocatore: cure, olio, monete, consumabili, esperienza.

var p: Player

func before() -> void:
	Run.reset()
	Run.active = true
	p = Player.new()
	Run.player = p
	p.recalc_stats()
	p.hp = 30
	p.oil = 50

func after() -> void:
	Run.reset()

func test_cura_e_moltiplicatore() -> void:
	p.stats.healMult = 0.5
	p.heal(20)
	eq(p.hp, 40.0)
	p.heal(100, true)
	eq(p.hp, 60.0, "non oltre la vita massima")

func test_monete_arrotondate() -> void:
	p.stats.coinMult = 1.3
	eq(p.add_coins(1), 1)
	eq(p.add_coins(5), 7)
	eq(p.coins, 8)
	eq(Run.coins_total, 8)

func test_consumabili_si_impilano_fino_a_tre() -> void:
	for i in 3:
		check(p.give_cons("bomb"))
	eq(p.cons[0], {"id": "bomb", "n": 3})
	check(p.give_cons("bomb"), "va nello slot successivo")
	eq(p.cons[1], {"id": "bomb", "n": 1})
	p.cons = [{"id": "a", "n": 3}, {"id": "b", "n": 3}, {"id": "c", "n": 3}, {"id": "d", "n": 3}]
	check(not p.give_cons("potion"))
	check(not p.can_take_cons("potion"))

func test_esperienza_e_livelli() -> void:
	p.add_xp(19)     # xpNeed(1) = 21
	eq(p.level, 1)
	p.add_xp(40)     # 59 totali: livello 2 (21) e livello 3 (33)
	eq(p.level, 3)
	eq(Run.pending_levels, 2)
	near(p.xp, 5.0)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=stats`
Expected: errore, `Player` non dichiarato.

- [ ] **Step 3: Implementare `Run`**

`godot/autoload/run.gd`:
```gdscript
extends Node
# Stato della run corrente (l'oggetto run di js/game.js e js/entities.js).
# active sostituisce il controllo "run !== null" del JS.

var active := false
var seed := 0
var rng: RNG
var depth := 1
var ardore := 0
var player: Player
var floor: Dictionary = {}
var room: Dictionary = {}
var bullets: Array = []
var ebullets: Array = []
var enemies: Array = []
var fx: Array = []
var kills := 0
var time := 0.0
var dmg_dealt := 0.0
var dmg_taken := 0.0
var coins_total := 0
var pending_levels := 0
var reroll_cost := 5
var offered_relics: Dictionary = {}
var oil_fx: Array = []
var flash_light: Variant = null
var toasts: Array = []
var banners: Array = []
var focus: Variant = null
var pull: Variant = null
var won := false
var endless := false
var rooms_cleared := 0
var new_unlocks: Array = []
var trans: Variant = null
var intro: Variant = null
var boss_intro: Variant = null
var flow_t := 0.0
var level_delay := 0.0
var lock_msg_t := 0.0
var death_t := 0.0
var victory_t := 0.0
var flow: PackedInt32Array = PackedInt32Array()
var boss_ref: Variant = null
var lock_fire := false
var forced_choices: Variant = null
var blood_paid := 0
var abandoned := false
var win_recorded := false
var actors: Node2D = null   # nodo della scena di gioco che ospita gli attori

func reset() -> void:
	if player != null and is_instance_valid(player):
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		player.free()
	for e in enemies:
		if is_instance_valid(e):
			e.free()
	# spezza i riferimenti circolari tra le stanze del piano precedente
	for r in floor.get("rooms", []):
		r.doors.clear()
	active = false
	seed = 0
	rng = null
	depth = 1
	ardore = 0
	player = null
	floor = {}
	room = {}
	bullets = []
	ebullets = []
	enemies = []
	fx = []
	kills = 0
	time = 0.0
	dmg_dealt = 0.0
	dmg_taken = 0.0
	coins_total = 0
	pending_levels = 0
	reroll_cost = 5
	offered_relics = {}
	oil_fx = []
	flash_light = null
	toasts = []
	banners = []
	focus = null
	pull = null
	won = false
	endless = false
	rooms_cleared = 0
	new_unlocks = []
	trans = null
	intro = null
	boss_intro = null
	flow_t = 0.0
	level_delay = 0.0
	lock_msg_t = 0.0
	death_t = 0.0
	victory_t = 0.0
	flow = PackedInt32Array()
	boss_ref = null
	lock_fire = false
	forced_choices = null
	blood_paid = 0
	abandoned = false
	win_recorded = false

# notifiche (toast e banner in js/ui.js)
func toast(text: String, col: Variant = "#ece6d8", sub: String = "") -> void:
	if not active:
		return
	toasts.append({"text": text, "col": col, "sub": sub, "t": 0.0, "life": 3.2 if sub != "" else 2.4})
	if toasts.size() > 4:
		toasts.pop_front()

func banner(title: String, desc: String, col: Variant, icon: String) -> void:
	if not active:
		return
	banners.append({"title": title, "desc": desc, "col": col, "icon": icon, "t": 0.0, "life": 3.6})
	if banners.size() > 2:
		banners.pop_front()

func update_notices(dt: float) -> void:
	for t in toasts:
		t.t += dt
	toasts = toasts.filter(func(t): return t.t < t.life)
	if not banners.is_empty():
		banners[0].t += dt
		if banners[0].t > banners[0].life:
			banners.pop_front()
```
In `godot/project.godot`, `[autoload]`, dopo `Controls`: `Run="*res://autoload/run.gd"`.

- [ ] **Step 4: Implementare `Player` (statistiche ed economia)**

`godot/actors/player.gd`:
```gdscript
class_name Player
extends Node2D
# Il portatore di lanterna (newPlayer e funzioni del giocatore in js/entities.js).
# x, y sono le coordinate logiche del JS; position si allinea a fine tick.

var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var r := 4.0
var hp := 1.0
var oil := 1.0
var xp := 0.0
var level := 1
var coins := 0
var keys := 1
var aim := 0.0
var fire_cd := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_charges := 1
var dash_dx := 0.0
var dash_dy := 0.0
var inv := 0.0
var statuses: Dictionary = {}
var perks: Dictionary = {}
var relics: Array = []
var curses: Array = []
var cons: Array = [null, null, null, null]
var shot_count := 0
var flare_cd := 0.0
var guard_t := 0.0
var guard_up := false
var secondwind_used := false
var coffin_used := false
var temp_orbit := 0
var temp_orbit_t := 0.0
var orbit_a := 0.0
var sun_t := 0.0
var storm_t := 3.0
var trail_t := 0.0
var echo_t := 0.0
var anim := 0.0
var moving := false
var lantern := "custode"
var stats: Dictionary = Stats.base()
var dead := false
var last_hit := ""
var facing := 1
var base_hp_mod := 0.0
```
Poi portare, come metodi:
- `recalc_stats()` ← `recalcStats` (`js/entities.js:34-57`): `DB.lantern(lantern).apply_stats(s)`, poi `Perks.apply(id, s, perks[id])`, `Relics.apply(id, s)`, `Curses.apply(id, s)`, `s.maxHp += base_hp_mod`, Ardore da `Run.ardore`, limiti; `dash_charges = mini(dash_charges, int(s.dashCharges))`.
- `damage()`, `fire_rate()`, `speed()`, `light()` ← `pDamage`, `pFireRate`, `pSpeed`, `pLight` (`js/entities.js:59-87`); `p.statuses.rage` diventa `statuses.has("rage")`.
- `damage_taken(amount) -> int`: la formula pura di `hurtPlayer` (`js/entities.js:495-498`):
```gdscript
func damage_taken(amount: float) -> int:
	var d: float = amount * stats.dmgTaken * (1 - minf(0.6, stats.armor * 0.07))
	if statuses.has("fragile"):
		d *= 1.3
	if oil <= 0:
		d *= 1.25
	return int(maxf(1, U.jround(d)))
```
- `heal(v, raw := false)` ← `healPlayer` (`js/entities.js:89-100`) con `Floaters.add`, `Particles.burst(..., {"grav": -40})`, `Sfx.play("heal")`.
- `add_oil(v)`, `add_coins(v) -> int`, `give_cons(id) -> bool`, `can_take_cons(id) -> bool`, `add_xp(v)` ← `addOil`, `addCoins`, `giveCons`, `canTakeCons`, `addXP` (`js/entities.js:101-117`, `131-143`, `1732-1735`). In `add_coins` il risultato è `int(maxf(1, U.jround(v * stats.coinMult)))`; in `give_cons` gli slot sono dizionari `{"id": id, "n": 1}`; `add_xp` usa `Stats.xp_need`, `Run.pending_levels`, il testo `"LIVELLO " + str(level)`.

In `godot/data/stats.gd` aggiungere:
```gdscript
static func ard_hp() -> float:
	return 1.25 if Run.ardore >= 1 else 1.0

static func ard_dmg() -> float:
	return 1.2 if Run.ardore >= 2 else 1.0
```

In `godot/data/perks.gd` aggiungere `roll_choices` ← `rollPerkChoices` (`js/entities.js:1927-1942`):
```gdscript
# scelta dei doni pesata per rarità
static func roll_choices(n: int, min_rar: int = 0) -> Array:
	var p = Run.player
	var luck: float = p.stats.luck + (Run.depth - 1) * 0.25
	var pool: Array = ALL.keys().filter(func(id): return p.perks.get(id, 0) < ALL[id]["max"] and ALL[id].rar >= min_rar)
	var wf := func(k):
		var r: int = ALL[k].rar
		return Stats.RARITY[r].w * (1.0 if r == 0 else 1 + luck * (0.3 + r * 0.35))
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var id: String = U.weighted_pick(pool, wf)
		out.append(id)
		pool.erase(id)
	return out
```

- [ ] **Step 5: Eseguire i test**

Run: `tools/test.sh --only=stats && tools/test.sh --only=player`
Expected: tutti superati. Una differenza su `stats` indica di solito un effetto copiato male in `Perks.apply` o `Relics.apply`: il messaggio riporta il caso e la chiave.

- [ ] **Step 6: Commit**

```bash
git add godot/actors/player.gd godot/autoload/run.gd godot/project.godot godot/data/stats.gd godot/data/perks.gd godot/tests/test_stats.gd godot/tests/test_player.gd
git commit -m "Giocatore: statistiche ed economia identiche al JS; stato della run

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Generazione del piano

**Files:**
- Create: `godot/world/room_util.gd`, `godot/world/floor_gen.gd`
- Test: `godot/tests/test_floor.gd`

**Interfaces:**
- Consumes: `floors.json`.
- Produces:
  - `RoomU` (statiche): `DIRS` (`n`, `s`, `w`, `e` con `dx, dy, opp, tiles`), `key(r) -> String` (`"gx,gy"`), `room_at(floor, gx, gy)`, `door_entry(dir) -> Vector2`, `door_center(dir) -> Vector2`, `tile_at(room, tx, ty) -> int`, `door_visible(room, dir) -> bool`, `door_locked`, `door_open`, `is_solid_tile(room, tx, ty, fly) -> bool`, `blocks_shot(room, tx, ty) -> bool`, `world_to_tile(x, y) -> Vector2i`, `tile_center(tx, ty) -> Vector2`, `walkable(t) -> bool`, `flood_from(room, sx, sy) -> Dictionary`, `check_reachable(room) -> bool`, `reach_tiles(room) -> Array` (di `Vector2i`).
  - `FloorGen.gen_floor(depth, rng, target := 0) -> Dictionary` con chiavi `depth`, `rooms` (Array), `map` (Dictionary `"gx,gy"` → stanza), `start`.
  - Stanza (Dictionary, chiavi del JS): `gx, gy, type, dist, doors, seed, built, visited, seen, cleared, found` (+ `locked` per il tesoro).

- [ ] **Step 1: Scrivere il test**

`godot/tests/test_floor.gd`:
```gdscript
extends TestCase
# genFloor: stesso piano del JS per ogni seme e profondità.

func test_piani_come_il_js() -> void:
	for g in TestCase.golden("floors"):
		var f := FloorGen.gen_floor(int(g.depth), RNG.new(int(g.seed)))
		eq(RoomU.key(f.start), g.start, "inizio, seme %d" % g.seed)
		eq(f.rooms.size(), g.rooms.size(), "numero di stanze, seme %d" % g.seed)
		for i in g.rooms.size():
			var r: Dictionary = f.rooms[i]
			var e: Dictionary = g.rooms[i]
			var doors := {}
			for d in r.doors:
				doors[d] = RoomU.key(r.doors[d])
			var got := {"key": RoomU.key(r), "gx": r.gx, "gy": r.gy, "type": r.type, "dist": r.dist, "seed": r.seed,
				"cleared": r.cleared, "found": r.found, "locked": r.get("locked", false), "doors": doors}
			var d := TestCase.diff(got, e, "stanza %d" % i)
			if d != "":
				fail("profondità %d seme %d: %s" % [g.depth, g.seed, d])
				return
		for r in f.rooms:
			r.doors.clear()

func test_utilita_delle_porte() -> void:
	eq(RoomU.door_entry("n"), Vector2(8 + 14.5 * 16, 28 + 1.9 * 16))
	eq(RoomU.door_center("e"), Vector2(8 + 28.5 * 16, 28 + 7.5 * 16))
	eq(RoomU.world_to_tile(8, 28), Vector2i(0, 0))
	eq(RoomU.world_to_tile(7.9, 27.9), Vector2i(-1, -1))
	eq(RoomU.tile_center(14, 7), Vector2(8 + 14.5 * 16, 28 + 7.5 * 16))
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=floor`
Expected: errore, `FloorGen` non dichiarato.

- [ ] **Step 3: Implementare**

`godot/world/room_util.gd`, con le costanti e le funzioni di `js/dungeon.js:34-52` e `143-182`, `289-319`:
```gdscript
class_name RoomU
extends RefCounted
# Utilità delle stanze (js/dungeon.js): porte, tile, coordinate, raggiungibilità.

const DIRS := {
	"n": {"dx": 0, "dy": -1, "opp": "s", "tiles": [[13, 0], [14, 0], [15, 0]]},
	"s": {"dx": 0, "dy": 1, "opp": "n", "tiles": [[13, 14], [14, 14], [15, 14]]},
	"w": {"dx": -1, "dy": 0, "opp": "e", "tiles": [[0, 6], [0, 7], [0, 8]]},
	"e": {"dx": 1, "dy": 0, "opp": "w", "tiles": [[28, 6], [28, 7], [28, 8]]},
}

static func key(r: Dictionary) -> String:
	return "%d,%d" % [r.gx, r.gy]

static func room_at(fl: Dictionary, gx: int, gy: int) -> Variant:
	return fl.map.get("%d,%d" % [gx, gy])

# punto di ingresso del giocatore quando arriva da una porta
static func door_entry(dir: String) -> Vector2:
	match dir:
		"n": return Vector2(Consts.RX + 14.5 * Consts.TS, Consts.RY + 1.9 * Consts.TS)
		"s": return Vector2(Consts.RX + 14.5 * Consts.TS, Consts.RY + 13.1 * Consts.TS)
		"w": return Vector2(Consts.RX + 1.9 * Consts.TS, Consts.RY + 7.5 * Consts.TS)
	return Vector2(Consts.RX + 27.1 * Consts.TS, Consts.RY + 7.5 * Consts.TS)

static func door_center(dir: String) -> Vector2:
	var t: Array = DIRS[dir].tiles[1]
	return Vector2(Consts.RX + (t[0] + 0.5) * Consts.TS, Consts.RY + (t[1] + 0.5) * Consts.TS)

static func world_to_tile(x: float, y: float) -> Vector2i:
	return Vector2i(int(floor((x - Consts.RX) / Consts.TS)), int(floor((y - Consts.RY) / Consts.TS)))

static func tile_center(tx: int, ty: int) -> Vector2:
	return Vector2(Consts.RX + (tx + 0.5) * Consts.TS, Consts.RY + (ty + 0.5) * Consts.TS)
```
Poi portare nello stesso file: `tile_at`, `door_visible`, `door_locked`, `door_open`, `is_solid_tile`, `blocks_shot` (`js/dungeon.js:148-180`; `room.doorDir[ty * RW + tx]` è un dizionario con chiavi intere), `walkable`, `flood_from` (restituisce un `Dictionary` usato come insieme ordinato: chiave `ty * RW + tx`, valore `true`; la coda è uno stack con `pop_back`), `check_reachable` (`room.reach` = l'insieme o `null`; le porte si leggono con `room.doors.keys()`), `reach_tiles` (`[Vector2i(k % RW, k / RW)]` nell'ordine di inserimento) (`js/dungeon.js:289-319`).

`godot/world/floor_gen.gd` — porta `genFloor` (`js/dungeon.js:57-141`):
```gdscript
class_name FloorGen
extends RefCounted
# Mappa della profondità (genFloor in js/dungeon.js). Stesso seme, stesso piano del JS.

const GW := 9
const GH := 8
const NB := [[1, 0], [-1, 0], [0, 1], [0, -1]]

static func gen_floor(depth: int, rng: RNG, target: int = 0) -> Dictionary:
	var n_target := target if target > 0 else mini(20, 9 + depth * 2 + rng.rint(0, 2))
	# ... porting delle righe 61-139
	return gen_floor(depth, rng, n_target - 1)
```
Punti non meccanici del porting:
- `cells` è un `Dictionary` `"x,y"` → cella `{gx, gy}`; `queue.shift()` è `pop_front()`; `rng.shuffle([[1,0],...])` mescola una **copia nuova** a ogni cella (in GDScript: `rng.shuffle(NB.duplicate(true))`).
- `rng.pick([...cells.values()])` è `rng.pick(cells.values())`.
- `distM` usa come chiave la stringa `"x,y"` della cella.
- `dead.sort((a, b) => distM.get(b) - distM.get(a))`: l'ordinamento del JS è **stabile**. In GDScript decorare ogni cella con l'indice originale e ordinare con `sort_custom(func(a, b): return a.d > b.d or (a.d == b.d and a.i < b.i))`.
- Le stanze si creano in `rooms` (Dictionary `"gx,gy"` → stanza) **nell'ordine di `list`** (cioè di `cells`), la segreta si aggiunge per ultima: `floor.rooms` è `rooms.values()`.
- `R(rest[0]).locked = depth >= 2` imposta `locked` solo sulla stanza del tesoro.
- La ricerca della stanza segreta usa `rng.chance(0.4)` solo quando `adj.size() == best_n` e `best != null`, come nel JS (cortocircuito dell'`&&`).
- Le porte: `for d in RoomU.DIRS: var n = rooms.get(...); if n != null: r.doors[d] = n`.

- [ ] **Step 4: Eseguire il test**

Run: `tools/test.sh --only=floor`
Expected: 2 test superati.

- [ ] **Step 5: Commit**

```bash
git add godot/world/room_util.gd godot/world/floor_gen.gd godot/tests/test_floor.gd
git commit -m "Generazione del piano identica al JS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Costruzione delle stanze

**Files:**
- Create: `godot/world/room_builder.gd`, `godot/combat/pickups.gd` (solo `make` e `random_cons`)
- Test: `godot/tests/test_rooms.gd`

**Interfaces:**
- Consumes: `rooms.json`, `formulas.json`; `RoomU`, `FloorGen`, `Cons`, `Relics`, `EliteMods`, `DB`, `Run`, `Lore`.
- Produces:
  - `RoomBuilder` (statiche): `QUADS`, `QUAD_BOSS`, `QUAD_SPECIAL`, `expand_quad(q) -> Array`, `build_room(room, fl)`, `clear_door_zone(room, d)`, `plan_waves(room, fl, rng, biome)`, `make_shop(room, fl, rng)`, `base_price(it, depth) -> float`, `make_shrine(room, fl, rng)`, `random_relics(n, rng = null) -> Array` (con `rng == null` mescola con `U.shuffle`, come la chiamata `{shuffle: a => shuffle(a)}` del JS).
  - Campi aggiunti alla stanza da `build_room` (chiavi del JS): `built, grid, doorDir, tileHp, objects, pickups, decals, spikeT, waves, combat, bgDirty, reach`, `tutorial` per l'iniziale della Profondità 1.
  - `Pickups.make(type, x, y, o := {}) -> Dictionary` (`{type, x, y, vx, vy, z, vz, t, value, id, magnet}`), `Pickups.random_cons() -> String`.

- [ ] **Step 1: Scrivere il test**

`godot/tests/test_rooms.gd`:
```gdscript
extends TestCase
# buildRoom: griglia, oggetti, raccoglibili, decorazioni, ondate e raggiungibilità come nel JS.

func after() -> void:
	Run.reset()

static func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out

func test_stanze_come_il_js() -> void:
	for g in TestCase.golden("rooms"):
		U.seed_random(int(g.seed) * 7919)
		Run.reset()
		Run.active = true
		Run.player = Player.new()
		Run.player.recalc_stats()
		var f := FloorGen.gen_floor(1, RNG.new(int(g.seed)))
		for i in f.rooms.size():
			var r: Dictionary = f.rooms[i]
			RoomBuilder.build_room(r, f)
			var e: Dictionary = g.rooms[i]
			var got := {"key": RoomU.key(r), "type": r.type, "grid": r.grid, "tileHp": _str_keys(r.tileHp),
				"doorDir": _str_keys(r.doorDir), "objects": r.objects, "pickups": r.pickups, "decals": r.decals,
				"waves": r.waves, "tutorial": r.get("tutorial", false),
				"reach": null if r.reach == null else r.reach.keys()}
			var d := TestCase.diff(got, e, "stanza %s" % e.key)
			if d != "":
				fail("seme %d: %s" % [g.seed, d])
				return

func test_prezzi_base() -> void:
	for c in TestCase.golden("formulas").basePrice:
		var it := {"kind": c[0]}
		if c[0] == "cons":
			it.id = c[1]
		eq(RoomBuilder.base_price(it, int(c[2])), c[3], "%s" % [c])
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=rooms`
Expected: errore, `RoomBuilder` non dichiarato.

- [ ] **Step 3: Implementare**

`godot/combat/pickups.gd` (per ora solo `make` e `random_cons`, da `js/entities.js:1694-1701`):
```gdscript
class_name Pickups
extends RefCounted
# Raccoglibili (makePickup, randomCons, updatePickups, collectPickup in js/entities.js).

static func make(type: String, x: float, y: float, o: Dictionary = {}) -> Dictionary:
	var a := U.rnd(TAU)
	var s := U.rnd(20, 70)
	return {"type": type, "x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "z": 0, "vz": 30 if type == "xp" else 70,
		"t": 0, "value": o.value if o.get("value", 0) else 1, "id": o.id if o.get("id") else null, "magnet": false}

static func random_cons() -> String:
	return U.weighted_pick(Cons.ALL.keys(), func(k): return Cons.ALL[k].w)
```

`godot/world/room_builder.gd`:
```gdscript
class_name RoomBuilder
extends RefCounted
# Costruzione delle stanze (js/dungeon.js): layout dai quadranti, porte, contenuti, ondate.

# Quadranti 14x7 (colonna 13 e riga 6 sono gli assi di simmetria).
# '.' pavimento  '#' roccia  '%' roccia incrinata  'b' barile  'u' urna
# '^' spuntoni  'o' braciere  '?' roccia casuale
const QUADS := [
	["..............", "..............", "..............", "..............", "..............", "..............", ".............."],
	["..............", "..............", "..............", ".....##.......", ".....##.......", "..............", ".............."],
	["..............", "..............", "..............", "..........o###", "...........###", "...........###", "...........###"],
	["..............", "..............", "...#######....", "..............", "..............", "..............", ".............."],
	["..............", "..b...........", ".....#........", "..........#...", "...#..........", ".......b....%.", ".............."],
	["..............", "..............", ".............#", ".............#", ".............#", ".........#####", ".............."],
	["..............", "..............", "....^^^.......", "....^^^.......", "..............", ".........^^^^^", ".............."],
	["..............", "..............", "......####....", "......#.......", "......#.......", "..............", ".............."],
	["..............", ".#............", "..#...........", "...#.......o..", "....#.........", ".....#........", ".............."],
	["..............", ".b.....u......", "..............", "...u.......#..", "..........###.", "...........#..", ".............."],
	["..............", "..............", "...?...#...?..", "..............", "..............", "...#...?...#..", ".............."],
	["..............", "..#####.......", "..#...........", "..#....#######", "..............", "..............", ".............."],
	["..............", "..............", "..............", ".........^^^^^", ".........^....", ".........^....", ".............."],
	["..............", "..u.......u...", "....%%........", "....%%........", "..............", ".......b......", ".............."],
	["..............", "...b..........", "..............", ".......##.....", ".......##..^^^", "...........^..", ".............."],
]
const QUAD_BOSS := ["..............", ".o............", "..............", "..............", "..............", "..............", ".............."]
const QUAD_SPECIAL := ["..............", "..o...........", "..............", "..............", "..............", "..............", ".............."]
const CHAR_TILE := {".": Consts.T.FLOOR, "#": Consts.T.ROCK, "%": Consts.T.CRACK, "b": Consts.T.BARREL,
	"u": Consts.T.URN, "^": Consts.T.SPIKE, "o": Consts.T.BRAZIER}

static func expand_quad(q: Array) -> Array:
	var top: Array = []
	for row in q:
		var mirror := ""
		for i in range(12, -1, -1):
			mirror += row[i]
		top.append(row + mirror)
	var out := top.duplicate()
	for i in range(5, -1, -1):
		out.append(top[i])
	return out
```
Poi portare nello stesso file, con le regole di traduzione:
- `build_room(room, fl)` ← `buildRoom` (`js/dungeon.js:184-278`): `var rng := RNG.new(room.seed)`; `rng.pick(QUADS.slice(1))`; il carattere sconosciuto vale `FLOOR` (`CHAR_TILE.get(ch, Consts.T.FLOOR)`, ma `tileHp` si imposta solo se il tile è `BARREL` o `URN` *dal carattere*, come nel JS); `room.tileHp` e `room.doorDir` sono dizionari con chiave intera `ty * RW + tx`; `for d in RoomU.DIRS` (ordine n, s, w, e); decorazioni `{x, y, k, s}` con `rng.rint` e `rng.next()`; oggetti con le **stesse chiavi del JS** e nello stesso ordine di inserimento (relic: `{type, id, x, y, group}`; chest: `{type, gold, x, y}`; chest segreta: `{type, gold, open, x, y}`); i pickup della stanza segreta con `Pickups.make(... "coin5" if rng.chance(0.2) else "coin", c.x + rng.frange(-50, 50), c.y + rng.frange(-30, 40))`, rispettando l'ordine degli argomenti.
- `clear_door_zone`, `plan_waves`, `make_shop`, `base_price`, `make_shrine`, `random_relics` ← `js/dungeon.js:280-287`, `324-402`. In `plan_waves`: `elite_chance` dall'array `[0, 0.06, 0.12, 0.18, 0.24]`, `Run.ardore`, `rng.weighted(opts, func(o): return o[2])`, `rng.pick(EliteMods.ALL.keys())`, onde `[{"type": t, "mod": m}]` con `mod` `null` se assente. In `make_shop` le voci sono `{"kind": "cons", "id": k}`, `{"kind": "heal"}`, `{"kind": "key" | "cons", "id": "bomb"}`, `{"kind": "relic", "id": r}`; gli oggetti `{"type": "merchant", "x", "y", "line"}` e `{"type": "shopitem", "item", "x", "y", "price"}`. `random_relics` usa `Run.player.relics` e `Run.offered_relics` (dizionario usato come insieme).
- Il bioma è `DB.biome_of(fl.depth)`; `biome.urns` è un campo della Resource.

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh --only=rooms`
Expected: 2 test superati. Una differenza su `pickups` di una stanza segreta indica un ordine diverso delle chiamate casuali; su `reach`, un ordine diverso della visita in `flood_from`.

- [ ] **Step 5: Commit**

```bash
git add godot/world/room_builder.gd godot/combat/pickups.gd godot/tests/test_rooms.gd
git commit -m "Costruzione delle stanze identica al JS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
## Fase D — Il gioco

### Task 14: Collisioni e campo di flusso

**Files:**
- Create: `godot/combat/collision.gd`, `godot/combat/flow_field.gd`
- Test: `godot/tests/test_movement.gd`

**Interfaces:**
- Consumes: `movement.json`; `RoomU`, `Run.room`, `Run.player`, `Run.flow`.
- Produces:
  - `Coll` (statiche): `collides(room, x, y, r, fly) -> bool`, `move_axis(a, d, axis, fly) -> bool`, `move_actor(a, dx, dy, fly) -> bool`, `line_clear(x0, y0, x1, y1) -> bool`, `nudge(p, axis, d)`. `a` e `p` sono qualunque oggetto o dizionario con `x`, `y`, `r`.
  - `FlowField` (statiche): `update()`, `angle(e, tx, ty) -> float`.

- [ ] **Step 1: Scrivere il test**

`godot/tests/test_movement.gd`:
```gdscript
extends TestCase
# Movimento ad assi separati, scivolamento sugli spigoli, campo di flusso e linea di tiro: come il JS.

func after() -> void:
	Run.reset()

func _room(seed: int) -> Dictionary:
	U.seed_random(seed)
	Run.reset()
	Run.active = true
	Run.player = Player.new()
	Run.player.recalc_stats()
	var f := FloorGen.gen_floor(1, RNG.new(seed))
	Run.floor = f
	var room: Dictionary = f.rooms.filter(func(x): return x.type == "normal")[0]
	RoomBuilder.build_room(room, f)
	Run.room = room
	return room

func test_tracce_di_movimento() -> void:
	for tr in TestCase.golden("movement").traces:
		var room := _room(int(tr.seed))
		room.cleared = tr.open
		room.combat = not tr.open
		var a := {"x": float(tr.start[0]), "y": float(tr.start[1]), "r": 4.0}
		for i in tr.steps.size():
			var st: Array = tr.steps[i]
			var dx: float = st[0]
			var dy: float = st[1]
			var bx := Coll.move_axis(a, dx, 0, false)
			var by := Coll.move_axis(a, dy, 1, false)
			if bx and absf(dy) < 1:
				Coll.nudge(a, 0, dx)
			if by and absf(dx) < 1:
				Coll.nudge(a, 1, dy)
			if absf(a.x - st[2]) > 1e-9 or absf(a.y - st[3]) > 1e-9 or (bx or by) != st[4]:
				fail("seme %d porte %s passo %d: (%s, %s) != (%s, %s)" % [tr.seed, tr.open, i, a.x, a.y, st[2], st[3]])
				return

func test_campo_di_flusso() -> void:
	for fl in TestCase.golden("movement").flow:
		var room := _room(int(fl.seed))
		room.cleared = false
		room.combat = true
		Run.player.x = fl.player[0]
		Run.player.y = fl.player[1]
		FlowField.update()
		for pr in fl.probes:
			near(FlowField.angle({"x": pr[0], "y": pr[1]}, Run.player.x, Run.player.y), pr[2], 1e-9, "seme %d %s" % [fl.seed, pr])

func test_linea_di_tiro() -> void:
	for ln in TestCase.golden("movement").lines:
		var room := _room(int(ln.seed))
		room.cleared = false
		room.combat = true
		for c in ln.cases:
			eq(Coll.line_clear(c[0], c[1], c[2], c[3]), c[4], "seme %d %s" % [ln.seed, c])
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=movement`
Expected: errore, `Coll` non dichiarato.

- [ ] **Step 3: Implementare**

`godot/combat/collision.gd`:
```gdscript
class_name Coll
extends RefCounted
# Collisioni con la griglia della stanza (js/entities.js:192-223 e 373-383).

static func collides(room: Dictionary, x: float, y: float, r: float, fly: bool) -> bool:
	var x0 := int(floor((x - r - Consts.RX) / Consts.TS))
	var x1 := int(floor((x + r - 0.01 - Consts.RX) / Consts.TS))
	var y0 := int(floor((y - r - Consts.RY) / Consts.TS))
	var y1 := int(floor((y + r - 0.01 - Consts.RY) / Consts.TS))
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if RoomU.is_solid_tile(room, tx, ty, fly):
				return true
	return false

static func move_axis(a, d: float, axis: int, fly: bool) -> bool:
	if d == 0 or is_nan(d):
		return false
	var room := Run.room
	var steps := int(ceil(absf(d)))
	var inc := d / steps
	for i in steps:
		if axis == 0:
			a.x += inc
		else:
			a.y += inc
		if collides(room, a.x, a.y, a.r, fly):
			if axis == 0:
				a.x -= inc
			else:
				a.y -= inc
			return true
	return false

static func move_actor(a, dx: float, dy: float, fly: bool) -> bool:
	var hx := move_axis(a, dx, 0, fly)
	var hy := move_axis(a, dy, 1, fly)
	return hx or hy

static func line_clear(x0: float, y0: float, x1: float, y1: float) -> bool:
	var room := Run.room
	var n := int(ceil(U.dist(x0, y0, x1, y1) / 6))
	for i in range(1, n):
		var t := RoomU.world_to_tile(lerpf(x0, x1, float(i) / n), lerpf(y0, y1, float(i) / n))
		if RoomU.blocks_shot(room, t.x, t.y):
			return false
	return true

# scivolamento sugli spigoli: se il passo è bloccato prova a spostarti di lato
static func nudge(p, axis: int, d: float) -> void:
	var room := Run.room
	var fx := signf(d) if axis == 0 else 0.0
	var fy := signf(d) if axis == 1 else 0.0
	for k in range(1, 7):
		for s in [1, -1]:
			var ox := float(s * k) if axis == 1 else 0.0
			var oy := float(s * k) if axis == 0 else 0.0
			if not collides(room, p.x + ox, p.y + oy, p.r, false) and not collides(room, p.x + ox + fx, p.y + oy + fy, p.r, false):
				move_axis(p, signf(ox) * 0.8, 0, false)
				move_axis(p, signf(oy) * 0.8, 1, false)
				return
```

`godot/combat/flow_field.gd` — porta `updateFlow` e `flowAngle` (`js/entities.js:226-266`):
```gdscript
class_name FlowField
extends RefCounted
# Campo di flusso verso il giocatore (inseguimento attorno agli ostacoli).

static func update() -> void:
	var rw := Consts.RW
	var rh := Consts.RH
	if Run.flow.size() != rw * rh:
		Run.flow.resize(rw * rh)
	Run.flow.fill(-1)
	var room := Run.room
	var pt := RoomU.world_to_tile(Run.player.x, Run.player.y)
	if pt.x < 0 or pt.y < 0 or pt.x >= rw or pt.y >= rh:
		return
	var q: Array[int] = [pt.y * rw + pt.x]
	Run.flow[pt.y * rw + pt.x] = 0
	var h := 0
	while h < q.size():
		var k := q[h]
		h += 1
		var x := k % rw
		var y := k / rw
		for dd in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = x + dd[0]
			var ny: int = y + dd[1]
			if nx < 1 or ny < 1 or nx >= rw - 1 or ny >= rh - 1:
				continue
			var nk := ny * rw + nx
			if Run.flow[nk] >= 0:
				continue
			if RoomU.is_solid_tile(room, nx, ny, false):
				continue
			Run.flow[nk] = Run.flow[k] + 1
			q.append(nk)
```
Poi `angle(e, tx, ty) -> float`, portando `flowAngle` riga per riga. Il JS legge celle del `Int16Array` fuori dai limiti (risultato `undefined`, che rende falsi tutti i confronti): in GDScript usare una funzione `_at(i) -> Variant` che restituisce `null` fuori da `[0, RW * RH)` e trattare `null` come «confronto falso» (`v == null or v < 0` per `continue`, `v != null and v < best` per il minimo). Se la cella dell'attore stesso è fuori dai limiti, il JS restituisce l'angolo verso il centro di quella cella: fare lo stesso. `tx != p.x` confronta il bersaglio con la `x` del giocatore (vale `true` quando il bersaglio è un punto di vagabondaggio).

- [ ] **Step 4: Eseguire il test**

Run: `tools/test.sh --only=movement`
Expected: 3 test superati.

- [ ] **Step 5: Commit**

```bash
git add godot/combat/collision.gd godot/combat/flow_field.gd godot/tests/test_movement.gd
git commit -m "Collisioni e campo di flusso identici al JS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Scena di gioco — stanza, giocatore che si muove, porte

**Files:**
- Create: `godot/autoload/game.gd`, `godot/ui/screens/boot.tscn`, `godot/ui/screens/boot.gd`
- Create: `godot/scenes/play.tscn`, `godot/scenes/play.gd`
- Create: `godot/world/flow.gd`, `godot/world/room_view.gd`, `godot/world/draw_ground.gd`
- Modify: `godot/actors/player.gd` (aggiunge `tick`, `sync`, `_draw`, `_process`)
- Modify: `godot/autoload/run.gd` (aggiunge `add_enemy`, `clear_enemies`, `prune_enemies`)
- Modify: `godot/world/room_util.gd` (aggiunge `spikes_up`, `spikes_warn`)
- Modify: `godot/project.godot` (autoload `Game`, `run/main_scene`)
- Create: `godot/tests/helpers.gd`
- Test: `godot/tests/test_flow.gd`

**Interfaces:**
- Produces:
  - autoload `Game`: `SCENES` (per ora solo `"play"`), `scene_name`, `scene_arg`, `dev: Dictionary`, `error: String`, `static parse_args(args) -> Dictionary`, `set_scene(name, arg = null)`, `boot()`, `dev_start()`.
  - `Flow` (statiche): `start_run(lantern_id, ardore, seed := -1)` (non cambia scena), `new_floor()`, `check_unlocks()`, `enter_room(room, from_dir)` (`from_dir` è `null` o `"n"`/`"s"`/`"w"`/`"e"`), `check_doors(dt)`, `update_trans(dt)`, `trans_alpha() -> float`, `descend()`, `update_game(dt)`, `update_common(dt)`.
  - `Player.tick(dt)`, `Player.sync()` (allinea `position` e chiede il ridisegno).
  - `Run.add_enemy(e)`, `Run.clear_enemies()`, `Run.prune_enemies()`.
  - `RoomU.spikes_up(room) -> bool`, `RoomU.spikes_warn(room) -> bool`.
  - Scena `res://scenes/play.tscn` (radice `Play`, script `play.gd` con `mode`, `tick(dt)`, `update_play(dt)`), nodi `World` (con `Room`, `Ground`, `Actors` a `y_sort_enabled`).
  - `TH` (aiuti dei test): `new_run(seed := 7, lantern := "custode")`, `room_of(type) -> Dictionary`, `enter(type) -> Dictionary`, `arena() -> Dictionary`, `spawn(type, x, y, mod = null)` (dal Task 17), `ticks(n)`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/helpers.gd`:
```gdscript
class_name TH
extends RefCounted
# Aiuti per i test di gioco senza scena.

static func new_run(seed: int = 7, lantern: String = "custode") -> void:
	U.seed_random(seed)
	Flow.start_run(lantern, 0, seed)

static func room_of(type: String) -> Dictionary:
	for r in Run.floor.rooms:
		if r.type == type:
			return r
	return {}

static func enter(type: String) -> Dictionary:
	var r := room_of(type)
	Flow.enter_room(r, null)
	return r

# stanza di combattimento senza ondate: le porte restano chiuse finché vive un nemico
static func arena() -> Dictionary:
	var r := enter("normal")
	r.waves = []
	r.combat = true
	return r

static func ticks(n: int) -> void:
	for i in n:
		Flow.update_common(Consts.DT)
		Flow.update_game(Consts.DT)
		Controls.end_tick()
```

`godot/tests/test_flow.gd`:
```gdscript
extends TestCase
# Avvio della run, ingresso nelle stanze, porte e transizioni, movimento del giocatore.

func before() -> void:
	TH.new_run(7)

func after() -> void:
	Controls.sim.clear()
	Run.reset()

func test_avvio_della_run() -> void:
	var p := Run.player
	eq(p.hp, p.stats.maxHp)
	eq(p.oil, p.stats.maxOil)
	eq(p.cons[0], {"id": "potion", "n": 1})
	eq(p.cons[1], {"id": "bomb", "n": 1})
	eq(Run.room.type, "start")
	check(Run.room.visited and Run.room.built)
	check(Run.room.get("tutorial", false))
	eq(Music.track_name, "crypt")
	eq(Run.toasts.back().text, "Trova il guardiano e scendi più in basso.")
	var runs: int = Save.data.stats.runs
	TH.new_run(8)
	eq(Save.data.stats.runs, runs + 1)

func test_ingresso_da_una_porta() -> void:
	var start := Run.room
	var d: String = start.doors.keys()[0]
	var n: Dictionary = start.doors[d]
	Flow.enter_room(n, d)
	check(is_same(Run.room, n))
	var e := RoomU.door_entry(RoomU.DIRS[d].opp)
	eq([Run.player.x, Run.player.y], [e.x, e.y])
	if n.type == "normal":
		check(n.combat, "stanza normale: combattimento")

func test_porta_aperta_e_transizione() -> void:
	var start := Run.room
	var d: String = start.doors.keys()[0]
	var dc := RoomU.door_center(d)
	var p := Run.player
	p.x = dc.x
	p.y = dc.y
	match d:
		"n":
			p.y = Consts.RY + 10
		"s":
			p.y = Consts.RY + (Consts.RH - 1) * Consts.TS + 6
		"w":
			p.x = Consts.RX + 10
		"e":
			p.x = Consts.RX + (Consts.RW - 1) * Consts.TS + 6
	Flow.check_doors(Consts.DT)
	check(Run.trans != null and Run.trans.kind == "room")
	for i in 9:
		Flow.update_trans(Consts.DT)
	check(is_same(Run.room, start.doors[d]), "dopo 0,13 s si cambia stanza")

func test_movimento_e_scatto() -> void:
	var p := Run.player
	var x0 := p.x
	Controls.sim = {"move": Vector2(1, 0)}
	p.tick(Consts.DT)
	near(p.x - x0, p.speed() * Consts.DT, 1e-6)
	Controls.sim = {"move": Vector2(1, 0), "pressed": ["dash"]}
	p.tick(Consts.DT)
	eq(p.dash_charges, 0)
	near(p.dash_t, 0.16 - Consts.DT, 1e-9)

func test_scena_di_gioco_si_avvia() -> void:
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	for i in 30:
		play.tick(Consts.DT)
	check(Run.player.get_parent() == play.get_node("World/Actors"))
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	check(Run.player.get_parent() == null, "il giocatore resta vivo dopo la scena")
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=flow`
Expected: errore, `Flow` non dichiarato.

- [ ] **Step 3: `Run`, `RoomU`, `Flow`**

In `godot/autoload/run.gd` aggiungere:
```gdscript
func add_enemy(e) -> void:
	enemies.append(e)
	if actors != null:
		actors.add_child(e)

func clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free() if e.is_inside_tree() else e.free()
	enemies = []

# run.enemies = run.enemies.filter(e => !e.dead), liberando i nodi
func prune_enemies() -> void:
	var alive: Array = []
	for e in enemies:
		if e.dead:
			e.queue_free() if e.is_inside_tree() else e.free()
		else:
			alive.append(e)
	enemies = alive
```

In `godot/world/room_util.gd` aggiungere (da `js/render.js:11-12`):
```gdscript
static func spikes_up(room: Dictionary) -> bool:
	return fmod(room.spikeT, 3.0) > 2.0

static func spikes_warn(room: Dictionary) -> bool:
	var k := fmod(room.spikeT, 3.0)
	return k > 1.6 and k <= 2.0
```

`godot/world/flow.gd`:
```gdscript
class_name Flow
extends RefCounted
# Flusso della run (js/game.js): avvio, piani, stanze, porte, transizioni, aggiornamento.

static func start_run(lantern_id: String, ardore: int, seed: int = -1) -> void:
	Run.reset()
	if seed < 0:
		seed = int(U.random() * 2147483648.0)
	Run.active = true
	Run.seed = seed
	Run.rng = RNG.new(seed)
	Run.ardore = ardore
	var p := Player.new()
	p.lantern = lantern_id
	Run.player = p
	p.recalc_stats()
	DB.lantern(lantern_id).on_start(p)
	p.recalc_stats()
	p.hp = p.stats.maxHp
	p.oil = p.stats.maxOil
	p.dash_charges = int(p.stats.dashCharges)
	p.guard_t = 2.0
	Save.data.stats.runs += 1
	Save.write()
	Particles.clear()
	Floaters.clear()
	new_floor()
	Run.toast("Trova il guardiano e scendi più in basso.", "#e8dcc0", "Premi TAB per la mappa, ESC per la pausa.")
```
Poi portare nello stesso file, con le regole di traduzione:
- `new_floor()` ← `newFloor` (`js/game.js:42-53`): `FloorGen.gen_floor(Run.depth, Run.rng)`; `Run.intro = {"t": 0.0, "depth": Run.depth}`; `Music.play(DB.biome_of(Run.depth).music)`; `Music.set_intensity(0)`.
- `check_unlocks()` ← `checkUnlocks` (`js/game.js:55-63`), con `DB.lanterns()` e `L.unlocked(Save.data.stats)`.
- `enter_room(room, from_dir)` ← `enterRoom` (`js/game.js:65-95`), senza il disegno dello sfondo (lo fa `RoomView`): `RoomBuilder.build_room` se `not room.built`; `Run.bullets = []`, `Run.ebullets = []`, `Run.clear_enemies()`, `Run.fx = []`, `Run.pull = null`, `Run.flow = PackedInt32Array()`, `Run.flow_t = 0.0`, `Run.boss_ref = null`, `Particles.clear()`; boss: `Run.boss_intro = {"t": 0.0, "B": DB.boss(room.waves[0][0].boss)}`.
- `check_doors(dt)`, `update_trans(dt)`, `trans_alpha()`, `descend()` ← `js/game.js:182-227` (in `update_trans`, per `kind == "descend"`: `Run.depth += 1` e `new_floor()`; il Task 22 lo sostituisce con la fine della demo).
- `update_game(dt)` ← `updateGame` (`js/game.js:229-245`), per ora solo: `Run.time += dt`, `Run.player.tick(dt)`, aggiornamento del campo di flusso ogni 0,18 s, `check_doors` se il giocatore è vivo. I task successivi aggiungono le altre righe **nello stesso ordine del JS**.
- `update_common(dt)` ← `updateCommon` (`js/game.js:246-255`): `Particles.update`, `Floaters.update`, `Run.update_notices`, `Fx.decay`, `Run.flash_light`, timer di `Run.intro` (4,5 s) e `Run.boss_intro` (2,8 s).

- [ ] **Step 4: Giocatore — aggiornamento del movimento e disegno**

In `godot/actors/player.gd` aggiungere `tick(dt)`, portando `updatePlayer` (`js/entities.js:271-320`) fino al movimento compreso:
```gdscript
# aggiornamento (updatePlayer); il resto del corpo arriva nei Task 17, 18 e 21
func tick(dt: float) -> void:
	var s := stats
	anim += dt
	if dead:
		return
	inv = maxf(0.0, inv - dt)
	flare_cd = maxf(0.0, flare_cd - dt)
	# mira
	aim = Controls.aim_angle(x, y, aim)
	facing = 1 if cos(aim) >= 0 else -1
	# scatto
	if dash_charges < s.dashCharges:
		dash_cd -= dt
		if dash_cd <= 0:
			dash_charges += 1
			dash_cd = s.dashCd
	else:
		dash_cd = s.dashCd
	var mv := Controls.move()
	if Controls.dash() and dash_charges > 0 and dash_t <= 0:
		var dx := mv.x
		var dy := mv.y
		if dx == 0 and dy == 0:
			dx = cos(aim)
			dy = sin(aim)
		var l := sqrt(dx * dx + dy * dy)
		dash_dx = dx / l
		dash_dy = dy / l
		dash_t = 0.16 * s.dashDist
		dash_charges -= 1
		Sfx.play("dash")
		Particles.burst(x, y + 4, 8, ["#8a8294", "#55505e"], 40, 0.4)
	var mvx := 0.0
	var mvy := 0.0
	if dash_t > 0:
		dash_t -= dt
		mvx = dash_dx * 330
		mvy = dash_dy * 330
		if U.random() < 0.7:
			Particles.add({"x": x + U.rnd(-2, 2), "y": y + U.rnd(-4, 4), "life": 0.3, "color": U.rgba(160, 190, 210, 0.6), "size": 2})
	else:
		var sp := speed()
		mvx = mv.x * sp
		mvy = mv.y * sp
	moving = sqrt(mvx * mvx + mvy * mvy) > 5
	# risucchio del Divoratore
	if Run.pull != null:
		mvx += Run.pull.x
		mvy += Run.pull.y
	var bx := Coll.move_axis(self, mvx * dt, 0, false)
	var by := Coll.move_axis(self, mvy * dt, 1, false)
	# scivolamento sugli spigoli (aiuta a imboccare le porte)
	if bx and absf(mvy) < 1:
		Coll.nudge(self, 0, mvx)
	if by and absf(mvx) < 1:
		Coll.nudge(self, 1, mvy)

func sync() -> void:
	position = Vector2(x, y)
	visible = not dead
	queue_redraw()

func _process(_delta: float) -> void:
	sync()
```
Poi `_draw()` portando `drawLantern` e `drawPlayer` (`js/render.js:409-435`) **senza le lucciole** (arrivano nel Task 18): iniziare con `UiDraw.set_origin(self, -position)` e chiudere con `UiDraw.set_origin(self, Vector2.ZERO)`; l'alfa del lampeggio va in `UiDraw.alpha` come `ctx.globalAlpha`; lo sprite è `Spr.draw(self, "player", frame, x, y + bob, {"flip": facing < 0, "flash": dash_t > 0 and Fx.vis.next() < 0.3})`; la lanterna usa il colore `DB.lantern(lantern).glass`.

- [ ] **Step 5: Vista della stanza e disegno a terra**

`godot/world/room_view.gd`:
```gdscript
extends Node2D
# Sfondo della stanza (renderRoomBg in js/dungeon.js): TileMapLayer per pavimento,
# muri e rocce; decorazioni, testo del tutorial e ombra dei muri disegnati dal codice.

class DrawCall extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)

var floor_layer := TileMapLayer.new()
var decals := DrawCall.new()
var walls := TileMapLayer.new()
var shadow := DrawCall.new()
var rocks := TileMapLayer.new()
var shown: Dictionary = {}

func _ready() -> void:
	position = Vector2(Consts.RX, Consts.RY)
	decals.fn = _draw_decals
	shadow.fn = _draw_wall_shadow
	for n in [floor_layer, decals, walls, shadow, rocks]:
		add_child(n)

func _process(_delta: float) -> void:
	if not Run.active or Run.room.is_empty():
		return
	if not is_same(Run.room, shown) or Run.room.get("bgDirty", false):
		show_room(Run.room)

func show_room(room: Dictionary) -> void:
	shown = room
	var biome := DB.biome_of(Run.floor.depth)
	var ts := TilePick.tileset(biome.id)
	for layer in [floor_layer, walls, rocks]:
		layer.tile_set = ts
		layer.clear()
	var s: int = room.seed % 1000
	for ty in Consts.RH:
		for tx in Consts.RW:
			var cell := Vector2i(tx, ty)
			var t: int = room.grid[ty][tx]
			if t == Consts.T.WALL or t == Consts.T.DOOR:
				walls.set_cell(cell, 0, TilePick.coords(biome.id, TilePick.wall_key(tx, ty, s)))
			else:
				floor_layer.set_cell(cell, 0, TilePick.coords(biome.id, TilePick.floor_key(tx, ty, s)))
			if t == Consts.T.ROCK or t == Consts.T.CRACK:
				rocks.set_cell(cell, 0, TilePick.coords(biome.id, TilePick.rock_key(tx, ty, s, t == Consts.T.CRACK)))
	room.bgDirty = false
	decals.queue_redraw()
	shadow.queue_redraw()
```
Poi, nello stesso file:
- `_draw_decals(ci)` ← `drawDecal` + `drawTutorialFloor` (`js/dungeon.js:491-532`), in coordinate locali della stanza (`d.x - RX`, `d.y - RY`), con il bioma corrente; il testo del tutorial con `UiDraw.text` e `UiDraw.alpha = 0.55`, `shadow: false`.
- `_draw_wall_shadow(ci)` ← le tre righe «ombra dei muri sul pavimento» di `renderRoomBg` (`js/dungeon.js:441-445`).

`godot/world/draw_ground.gd`:
```gdscript
extends Node2D
# Disegno a terra nell'ordine di drawWorld (js/render.js): indizi dei segreti, porte,
# tile dinamici, effetti a terra, oggetti, raccoglibili.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	var room := Run.room
	_secret_hints(room)
	_doors(room)
	_dynamic_tiles(room)
```
e portare `_secret_hints` ← `drawSecretHints`, `_door_style` ← `doorStyle`, `_doors` ← `drawDoors`, `_dynamic_tiles` ← `drawDynamicTiles` (`js/render.js:56-153`), con `RoomU.spikes_up`, `RoomU.spikes_warn`, `UiDraw.flame(self, cx, cy - 3, 1, Fx.time)` per i bracieri, `U.hash2(i, int(x), int(y))` per il varco segreto.

- [ ] **Step 6: Scena di gioco, `Game` e avvio**

`godot/scenes/play.tscn`:
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scenes/play.gd" id="1"]
[ext_resource type="Script" path="res://world/room_view.gd" id="2"]
[ext_resource type="Script" path="res://world/draw_ground.gd" id="3"]

[node name="Play" type="Node"]
script = ExtResource("1")

[node name="World" type="Node2D" parent="."]

[node name="Room" type="Node2D" parent="World"]
script = ExtResource("2")

[node name="Ground" type="Node2D" parent="World"]
script = ExtResource("3")

[node name="Actors" type="Node2D" parent="World"]
y_sort_enabled = true
```

`godot/scenes/play.gd`:
```gdscript
extends Node
# Scena di gioco (Scenes.play in js/game.js): aggiorna il mondo a tick fissi nello
# stesso ordine del JS; i nodi figli disegnano i livelli.

var mode := "play"
@onready var world: Node2D = $World
@onready var actors: Node2D = $World/Actors

func _ready() -> void:
	Run.actors = actors
	if Run.player != null:
		actors.add_child(Run.player)
	for e in Run.enemies:
		if e.get_parent() == null:
			actors.add_child(e)
	mode = "play"
	_dev_sim()

func _exit_tree() -> void:
	if Run.player != null and Run.player.get_parent() == actors:
		actors.remove_child(Run.player)
	for e in Run.enemies:
		if is_instance_valid(e) and e.get_parent() == actors:
			actors.remove_child(e)
	Run.actors = null

func _physics_process(_delta: float) -> void:
	tick(Consts.DT)
	Controls.end_tick()

func _process(_delta: float) -> void:
	world.position = Fx.offset()

func tick(dt: float) -> void:
	match mode:
		"play":
			update_play(dt)

# updatePlay (js/game.js:335-357); pausa, mappa e livelli arrivano nel Task 24
func update_play(dt: float) -> void:
	Flow.update_common(dt)
	if Run.trans != null:
		Flow.update_trans(dt)
		return
	if Fx.hitstop_t > 0:
		Fx.hitstop_t -= dt
		return
	if Run.player.dead:
		Run.death_t += dt
		Flow.update_game(dt * 0.25)
		if Run.death_t > 2.4 and Game.SCENES.has("gameover"):
			Game.set_scene("gameover")
		return
	if Run.lock_fire and not Controls.mouse_left():
		Run.lock_fire = false
	Flow.update_game(dt)

# --sim=N [--fire]: N tick simulati prima del primo disegno (devStart del JS)
func _dev_sim() -> void:
	var n := int(Game.dev.get("sim", 0))
	for i in n:
		if Game.dev.has("fire"):
			var e: Variant = Run.enemies[0] if not Run.enemies.is_empty() else null
			Controls.sim = {"fire": e != null, "device": "mouse"}
			if e != null:
				Controls.sim.mouse = Vector2(e.x, e.y)
		tick(Consts.DT)
		Controls.end_tick()
	Controls.sim.clear()
```

`godot/autoload/game.gd`:
```gdscript
extends Node
# Scene, argomenti di sviluppo, screenshot e cattura degli errori
# (setScene, boot e devStart in js/game.js).

var SCENES := {
	"play": "res://scenes/play.tscn",
}
var scene_name := ""
var scene_arg: Variant = null
var dev: Dictionary = {}
var error := ""
var frames := 0

class ErrorLogger extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		var g := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Game")
		if g != null and g.error == "":
			g.error = rationale if rationale != "" else code
	func _log_message(message: String, error: bool) -> void:
		pass

func _ready() -> void:
	OS.add_logger(ErrorLogger.new())
	dev = parse_args(OS.get_cmdline_user_args())
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(Consts.W, Consts.H))

static func parse_args(args: PackedStringArray) -> Dictionary:
	var d := {}
	for a in args:
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		d[kv[0]] = kv[1] if kv.size() > 1 else true
	return d

func set_scene(name: String, arg: Variant = null) -> void:
	scene_name = name
	scene_arg = arg
	Controls.sim.erase("pressed")
	get_tree().change_scene_to_file(SCENES[name])

# chiamata dalla scena di avvio
func boot() -> void:
	dev_start()

func _process(_delta: float) -> void:
	if dev.has("screenshot") and scene_name != "":
		frames += 1
		if frames == int(dev.get("shot-after", 30)):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(str(dev.screenshot))
			get_tree().quit()
```
Poi `dev_start()` portando `devStart` (`js/game.js:867-901`) con gli argomenti di `dev`: `--seed` (chiama `U.seed_random(seed)` prima di `Flow.start_run(lantern, ardore, seed)`), `--lantern`, `--ardore`, `--test=fight|boss|shop|treasure|shrine|secret` (per `secret` impostare anche `room.found = true` prima di entrare), `--perks=a,b`, `--relics=a,b` (poi `Run.player.recalc_stats()`), `--lv`, `--coins`; `Run.intro = null`; infine `set_scene("play")`. La simulazione `--sim` la esegue `play.gd` (`_dev_sim`); `--pause`, `--map`, `--scene` arrivano nei Task 24–25.

`godot/ui/screens/boot.gd`:
```gdscript
extends Node
# Scena di avvio: lascia a Game la scelta della prima schermata.

func _ready() -> void:
	Game.boot.call_deferred()
```
`godot/ui/screens/boot.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/screens/boot.gd" id="1"]

[node name="Boot" type="Node"]
script = ExtResource("1")
```
In `godot/project.godot`: `run/main_scene="res://ui/screens/boot.tscn"` nella sezione `[application]` e, in `[autoload]` dopo `Run`, `Game="*res://autoload/game.gd"`.

- [ ] **Step 7: Eseguire i test**

Run: `tools/test.sh --only=flow`
Expected: 5 test superati.

- [ ] **Step 8: Verifica visiva**

Run:
```bash
godot --headless --path godot --import
godot --path godot -- --seed=7 --screenshot=/tmp/ul_t15_start.png --shot-after=20
godot --path godot -- --seed=7 --test=shop --screenshot=/tmp/ul_t15_shop.png --shot-after=20
```
Aprire le due immagini: stanza iniziale con pavimento, muri, ombra, ossa a terra, testo del tutorial, porte con la cornice del colore giusto, giocatore con la lanterna al centro. Il buio arriva nel Task 16. Poi `godot --path godot -- --seed=7` e controllare a mano: WASD muove, Spazio scatta, si attraversa una porta con transizione.

- [ ] **Step 9: Commit**

```bash
git add godot/autoload godot/ui/screens godot/scenes godot/world godot/actors/player.gd godot/project.godot godot/tests/helpers.gd godot/tests/test_flow.gd
git commit -m "Scena di gioco: stanza su TileMapLayer, giocatore, porte e transizioni

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Luce e buio

**Files:**
- Create: `godot/world/lights.gd`, `godot/world/lighting.gd`, `godot/shaders/darkness.gdshader`, `godot/shaders/glow.gdshader`, `godot/shaders/vignette.gdshader`
- Modify: `godot/scenes/play.tscn` (nodo `Lighting`), `godot/scenes/play.gd` (passa lo scuotimento alla luce)
- Test: `godot/tests/test_lights.gd`

**Interfaces:**
- Produces:
  - `Lights.collect() -> Array` di `{x, y, r, a, col, ga}` (`col` `null` se senza bagliore), portando `collectLights`.
  - `Lighting extends CanvasLayer`: `static ambient(dark, depth, cleared, is_boss, oil_empty, combat) -> float`, `refresh(offset: Vector2)`, `MAX_LIGHTS := 128`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_lights.gd`:
```gdscript
extends TestCase
# Luci raccolte come collectLights e buio ambientale come drawLighting.

func before() -> void:
	TH.new_run(7)

func after() -> void:
	Run.reset()

func test_luce_del_giocatore_e_bracieri() -> void:
	var L := Lights.collect()
	var p := Run.player
	check(L[0].r > p.light() * 0.97 and L[0].r < p.light() * 1.03, "tremolio entro il 3%")
	eq(L[0].col, "#f2a040")
	var braziers := 0
	for row in Run.room.grid:
		braziers += row.count(Consts.T.BRAZIER)
	eq(L.size(), 1 + braziers)

func test_buio_ambientale() -> void:
	near(Lighting.ambient(0.68, 1, false, false, false, false), 0.68)
	near(Lighting.ambient(0.68, 1, true, false, false, false), 0.68 * 0.84)
	near(Lighting.ambient(0.68, 1, true, true, false, false), 0.68, 1e-9, "la stanza del boss non si schiarisce")
	near(Lighting.ambient(0.9, 1, false, false, true, true), 0.94, 1e-9, "senza olio in combattimento, al massimo 0,94")
	near(Lighting.ambient(0.68, 8, false, false, false, false), 0.68 + 0.045)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=lights`
Expected: errore, `Lights` non dichiarato.

- [ ] **Step 3: Shader**

`godot/shaders/darkness.gdshader`:
```glsl
shader_type canvas_item;
// Strato di buio di drawLighting (js/render.js): colore #050309 con opacità amb;
// ogni luce toglie opacità con il gradiente radiale del JS (raggio interno 0,12 r,
// arresti alfa a / 0,6 a / 0), e le luci si combinano moltiplicando (destination-out).

uniform float amb = 0.68;
uniform int count = 0;
uniform vec4 lights[128];   // x, y, raggio, alfa in coordinate dello schermo 480x270

const vec3 DARK = vec3(5.0, 3.0, 9.0) / 255.0;
const float R0 = 0.12;
const float R1 = 0.12 + 0.55 * 0.88;   // secondo arresto del gradiente

float falloff(float k) {
	if (k <= R0) return 1.0;
	if (k <= R1) return mix(1.0, 0.6, (k - R0) / (R1 - R0));
	if (k < 1.0) return mix(0.6, 0.0, (k - R1) / (1.0 - R1));
	return 0.0;
}

void fragment() {
	vec2 p = UV * vec2(480.0, 270.0);
	float a = amb;
	for (int i = 0; i < count; i++) {
		vec4 L = lights[i];
		float d = distance(p, L.xy);
		if (d < L.z) a *= 1.0 - L.w * falloff(d / L.z);
	}
	COLOR = vec4(DARK, a);
}
```

`godot/shaders/glow.gdshader`:
```glsl
shader_type canvas_item;
render_mode blend_add;
// Bagliore caldo additivo di drawLighting: gradiente dal colore al nero entro 0,8 r.

uniform int count = 0;
uniform vec4 lights[128];   // x, y, raggio, alfa
uniform vec4 colors[128];   // r, g, b, intensità (0 = nessun bagliore)

void fragment() {
	vec2 p = UV * vec2(480.0, 270.0);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < count; i++) {
		if (colors[i].a <= 0.0) continue;
		float r = lights[i].z * 0.8;
		float d = distance(p, lights[i].xy);
		if (d < r) sum += colors[i].rgb * colors[i].a * (1.0 - d / r);
	}
	COLOR = vec4(sum, 1.0);
}
```

`godot/shaders/vignette.gdshader`:
```glsl
shader_type canvas_item;
// Vignettatura di drawLighting: da trasparente a nero 0,55 tra 0,35 H e 0,95 H dal punto (W/2, H/2 + 14).

void fragment() {
	vec2 p = UV * vec2(480.0, 270.0);
	float d = distance(p, vec2(240.0, 149.0));
	float t = clamp((d - 270.0 * 0.35) / (270.0 * 0.6), 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, 0.55 * t);
}
```

- [ ] **Step 4: `Lights` e `Lighting`**

`godot/world/lights.gd`: `class_name Lights`, `static func collect() -> Array` che porta `collectLights` (`js/render.js:542-573`) riga per riga. Il tremolio usa `Fx.time`; `col` resta la stringa del JS o `null`; gli oggetti della stanza, i nemici (`e.boss`, `e.type`), i proiettili e gli effetti si leggono dai campi del JS. Fermarsi a 120 luci per i proiettili nemici come il JS.

`godot/world/lighting.gd`:
```gdscript
class_name Lighting
extends CanvasLayer
# Buio, bagliore e vignettatura (drawLighting in js/render.js) come shader a schermo intero.

const MAX_LIGHTS := 128
var dark := ColorRect.new()
var glow := ColorRect.new()
var vignette := ColorRect.new()

func _ready() -> void:
	layer = 1
	for pair in [[dark, "darkness"], [glow, "glow"], [vignette, "vignette"]]:
		var rect: ColorRect = pair[0]
		rect.size = Vector2(Consts.W, Consts.H)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/%s.gdshader" % pair[1])
		rect.material = m
		add_child(rect)

static func ambient(dark_: float, depth: int, cleared: bool, is_boss: bool, oil_empty: bool, combat: bool) -> float:
	var amb := dark_ + minf(0.08, maxf(0.0, depth - 5) * 0.015)
	if cleared and not is_boss:
		amb *= 0.84
	if oil_empty and combat:
		amb = minf(0.94, amb + 0.06)
	return amb

func refresh(offset: Vector2) -> void:
	visible = Run.active and not Run.room.is_empty()
	if not visible:
		return
	var room := Run.room
	var amb := ambient(DB.biome_of(Run.depth).dark, Run.depth, room.cleared, room.type == "boss", Run.player.oil <= 0, room.combat)
	var L := Lights.collect()
	var n := mini(L.size(), MAX_LIGHTS)
	var pos := PackedVector4Array()
	var cols := PackedVector4Array()
	pos.resize(MAX_LIGHTS)
	cols.resize(MAX_LIGHTS)
	for i in n:
		var l: Dictionary = L[i]
		pos[i] = Vector4(l.x + offset.x, l.y + offset.y, maxf(4.0, l.r), l.a)
		if l.get("col") != null:
			var c := UiDraw.col(l.col)
			cols[i] = Vector4(c.r, c.g, c.b, l.get("ga", 0.1))
	var dm := dark.material as ShaderMaterial
	dm.set_shader_parameter("amb", amb)
	dm.set_shader_parameter("count", n)
	dm.set_shader_parameter("lights", pos)
	var gm := glow.material as ShaderMaterial
	gm.set_shader_parameter("count", n)
	gm.set_shader_parameter("lights", pos)
	gm.set_shader_parameter("colors", cols)
```

In `godot/scenes/play.tscn` aggiungere la risorsa e il nodo (dopo `Actors`):
```
[ext_resource type="Script" path="res://world/lighting.gd" id="4"]

[node name="Lighting" type="CanvasLayer" parent="."]
script = ExtResource("4")
```
(aggiornare `load_steps`). In `play.gd`, `_process` diventa:
```gdscript
func _process(_delta: float) -> void:
	var off := Fx.offset()
	world.position = off
	$Lighting.refresh(off)
```

- [ ] **Step 5: Eseguire i test**

Run: `tools/test.sh --only=lights`
Expected: 2 test superati.

- [ ] **Step 6: Verifica visiva e taratura**

Run: `godot --path godot -- --seed=7 --screenshot=/tmp/ul_t16.png --shot-after=20` e, per confronto, aprire `index.html` nel browser e iniziare una discesa (stanza iniziale). Il cerchio di luce attorno al giocatore, i bracieri e il bagliore arancio devono avere la stessa estensione e la stessa morbidezza. Se il bagliore risulta molto più forte o più debole del JS, cambiare il termine `(1.0 - d / r)` di `glow.gdshader` in `(1.0 - d / r) * (1.0 - d / r)` e riconfrontare: è l'unico punto in cui il JS dipende da come il browser interpola i gradienti.

- [ ] **Step 7: Commit**

```bash
git add godot/world/lights.gd godot/world/lighting.gd godot/shaders godot/scenes godot/tests/test_lights.gd
git commit -m "Luce: buio, bagliore e vignettatura con shader identici a drawLighting

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: Nucleo del combattimento

Logica senza disegno, verificata da test headless: dati dei nemici, stati alterati, danni, effetti, proiettili, raccoglibili.

**Files:**
- Create: `godot/actors/enemy.gd` (campi e `make`; aggiornamento e disegno nel Task 19)
- Create: `godot/combat/status.gd`, `godot/combat/combat.gd`, `godot/combat/effects.gd`, `godot/combat/bullets.gd`
- Modify: `godot/combat/pickups.gd` (aggiunge `update`, `collect`)
- Modify: `godot/actors/player.gd` (in `tick`, `Status.update(self, dt, true)` subito dopo `anim += dt`, come nel JS)
- Modify: `godot/tests/helpers.gd` (aggiunge `spawn`)
- Test: `godot/tests/test_enemy_make.gd`, `godot/tests/test_status.gd`, `godot/tests/test_combat.gd`, `godot/tests/test_bullets.gd`, `godot/tests/test_effects.gd`

**Interfaces:**
- Consumes: `enemies.json`.
- Produces:
  - `Enemy extends Node2D`: campi (vedi codice), `static make(type, x, y, mod = null, o := {}) -> Enemy`. Il nome mostrato è `display_name` (`name` è già il nome del nodo).
  - `Status`: `add(a, name, dur, power := 0.0)`, `update(a, dt, is_p)`, `cleanse(a)`.
  - `Combat`: `hurt_player(amount, src := "", o := {}) -> bool`, `player_death()`, `revive_burst(p)`, `hit_enemy(e, dmg, o := {})`, `kill_enemy(e, o := {})`, `chain_lightning(from, dmg)`, `damage_tile(tx, ty, dmg)`, `explode_barrel(tx, ty)`, `break_urn(tx, ty)`, `freeze_all(t)`, `enemy_colors(e) -> Array`.
  - `Effects`: `add(f) -> Dictionary`, `place_bomb(x, y, owner)`, `update(dt)`, `explosion_hit(f)`. Tipi: `explosion`, `bomb`, `shockwave`, `warn`, `cloud`, `fire`, `spawn` (solo nemici; il boss nel Task 22), `bolt`, `flare`.
  - `Bullets`: `e_shoot(e, ang, spd, o := {})`, `shot_opts(e) -> Dictionary`, `update_player(dt)`, `spawn_shards(b)`, `bullet_hit(b, e)`, `update_enemy(dt)`, `color_of(b) -> String`.
  - `Pickups.update(dt)`, `Pickups.collect(k)`.
  - Proiettile del giocatore: `{x, y, vx, vy, r, dmg, crit, life, pierce, bounce, hit: {}, kind, t}`; proiettile nemico: `{x, y, vx, vy, r, dmg, life, kind, col, status, src, accel, curve, t, big}` (+ `ghost`).
  - `TH.spawn(type, x, y, mod = null) -> Enemy`.

- [ ] **Step 1: Scrivere i test**

In `godot/tests/helpers.gd` aggiungere:
```gdscript
static func spawn(type: String, x: float, y: float, mod: Variant = null) -> Enemy:
	var e := Enemy.make(type, x, y, mod)
	e.stun = 0.0
	Run.add_enemy(e)
	return e
```

`godot/tests/test_enemy_make.gd`:
```gdscript
extends TestCase
# makeEnemy: statistiche scalate per profondità, élite e versioni piccole come nel JS.

func after() -> void:
	Run.reset()

func test_nemici_come_il_js() -> void:
	for c in TestCase.golden("enemies").enemies:
		U.seed_random(int(c.seed))
		Run.reset()
		Run.active = true
		Run.depth = int(c.depth)
		Run.player = Player.new()
		Run.player.recalc_stats()
		var e := Enemy.make(c.type, 100, 100, c.mod, {"small": true} if c.small else {})
		var got := {"hp": e.hp, "maxHp": e.max_hp, "spd": e.spd, "dmg": e.dmg, "xp": e.xp, "r": e.r, "fly": e.fly,
			"shotCd": e.shot_cd, "anim": e.anim, "t": e.t, "stun": e.stun, "elite": e.elite, "mod": e.mod}
		var d := TestCase.diff(got, c.fields, "")
		e.free()
		if d != "":
			fail("%s prof. %d %s %s: %s" % [c.type, c.depth, c.mod, c.small, d])
			return
```

`godot/tests/test_status.gd`:
```gdscript
extends TestCase
# Stati alterati (addStatus, updateStatuses, cleanse).

func before() -> void:
	TH.new_run(3)
	TH.arena()

func after() -> void:
	Run.reset()

func test_veleno_si_accumula_con_limiti() -> void:
	var p := Run.player
	for i in 6:
		Status.add(p, "poison", 3)
	eq(p.statuses.poison.stacks, 3, "giocatore: massimo 3")
	var e := TH.spawn("ghoul", 200, 120)
	for i in 7:
		Status.add(e, "poison", 3, 2.0)
	eq(e.statuses.poison.stacks, 5, "nemico: massimo 5")

func test_tre_cariche_di_gelo_congelano() -> void:
	var e := TH.spawn("ghoul", 200, 120)
	Status.add(e, "chill", 2.2)
	Status.add(e, "chill", 2.2)
	eq(e.frozen, 0.0)
	Status.add(e, "chill", 2.2)
	eq(e.frozen, 1.6)
	check(not e.statuses.has("chill"))

func test_immunita() -> void:
	var p := Run.player
	Status.add(p, "immune", 6)
	Status.add(p, "burn", 3)
	check(not p.statuses.has("burn"))
	p.statuses.clear()
	p.stats.immune.poison = 1
	Status.add(p, "poison", 3)
	check(not p.statuses.has("poison"))
	Status.add(p, "rage", 3)
	Status.add(p, "weak", 3)
	Status.cleanse(p)
	eq(p.statuses.keys(), ["rage"])

func test_bruciatura_ferisce_ogni_mezzo_secondo() -> void:
	var p := Run.player
	var hp := p.hp
	Status.add(p, "burn", 2)
	Status.update(p, 0.49, true)
	eq(p.hp, hp)
	Status.update(p, 0.02, true)
	eq(p.hp, hp - 2)
```

`godot/tests/test_combat.gd`:
```gdscript
extends TestCase
# Danni al giocatore e ai nemici, morte e rinascita, uccisioni e ricompense, tile distruttibili.

func before() -> void:
	TH.new_run(5)
	TH.arena()
	Run.player.inv = 0.0

func after() -> void:
	Run.reset()

func test_invulnerabilita_e_scatto() -> void:
	var p := Run.player
	p.inv = 0.5
	check(not Combat.hurt_player(10, "x"))
	p.inv = 0.0
	p.dash_t = 0.1
	check(not Combat.hurt_player(10, "x"))
	p.dash_t = 0.0
	check(Combat.hurt_player(10, "x"))
	eq(p.inv, p.stats.iframes)
	eq(p.last_hit, "x")

func test_scudo_del_lume() -> void:
	var p := Run.player
	p.guard_up = true
	check(not Combat.hurt_player(10, "x"))
	check(not p.guard_up)
	eq(p.guard_t, 10.0)

func test_corazza_di_cenere() -> void:
	Run.player.stats.ashguard = 1
	Combat.hurt_player(10, "x")
	eq(Run.fx.filter(func(f): return f.type == "shockwave").size(), 1)

func test_ultimo_respiro_poi_bara_poi_piuma_poi_morte() -> void:
	var p := Run.player
	p.stats.secondwind = 1
	p.stats.revive = 1
	p.cons[2] = {"id": "feather", "n": 1}
	for expected in [1.0, 30.0, 30.0]:
		p.inv = 0.0
		Combat.hurt_player(999, "x")
		eq(p.hp, expected)
		check(not p.dead)
	p.inv = 0.0
	Combat.hurt_player(999, "x")
	check(p.dead)
	eq(p.cons[2], null)

func test_nemico_corazzato_e_congelato() -> void:
	var e := TH.spawn("ghoul", 300, 120, "armored")
	var hp := e.hp
	Combat.hit_enemy(e, 10)
	near(e.hp, hp - 7)
	e.frozen = 1.0
	Combat.hit_enemy(e, 10)
	near(e.hp, hp - 7 - 10 * 0.7 * 1.15)

func test_uccisione_e_ricompense() -> void:
	var e := TH.spawn("skeleton", 300, 120)
	var oil := Run.player.oil
	Run.player.oil = 10
	Combat.hit_enemy(e, 9999)
	check(e.dead)
	eq(Run.kills, 1)
	var xp := Run.room.pickups.filter(func(k): return k.type == "xp")
	eq(xp.size(), int(clampf(U.jround(e.xp / 2), 1, 8)))
	near(Run.player.oil, 12.5)
	Run.player.oil = oil

func test_scisso_genera_due_piccoli() -> void:
	var e := TH.spawn("ghoul", 300, 120, "splitter")
	Combat.kill_enemy(e)
	var small := Run.enemies.filter(func(x): return not x.dead)
	eq(small.size(), 2)
	check(small[0].no_split)

func test_instabile_spara_otto_colpi() -> void:
	var e := TH.spawn("ghoul", 300, 120, "volatile")
	Combat.kill_enemy(e)
	eq(Run.ebullets.size(), 8)

func test_barile_e_urna() -> void:
	var room := Run.room
	room.grid[5][5] = Consts.T.BARREL
	room.tileHp[5 * Consts.RW + 5] = 18
	Combat.damage_tile(5, 5, 10)
	eq(room.grid[5][5], Consts.T.BARREL)
	Combat.damage_tile(5, 5, 10)
	eq(room.grid[5][5], Consts.T.FLOOR)
	eq(Run.fx.back().type, "explosion")
	room.grid[6][6] = Consts.T.URN
	Combat.damage_tile(6, 6, 1)
	eq(room.grid[6][6], Consts.T.FLOOR)
```

`godot/tests/test_bullets.gd`:
```gdscript
extends TestCase
# Proiettili: muri, rimbalzi, perforazione, schegge, colpi al giocatore, uscita di scena.

func before() -> void:
	TH.new_run(9)
	var room := TH.arena()
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			room.grid[ty][tx] = Consts.T.FLOOR
	Run.player.inv = 0.0

func after() -> void:
	Run.reset()

func _shot(x: float, y: float, vx: float, vy: float, o: Dictionary = {}) -> Dictionary:
	var b := {"x": x, "y": y, "vx": vx, "vy": vy, "r": 3.0, "dmg": 10.0, "crit": false, "life": 5.0,
		"pierce": 0, "bounce": 0, "hit": {}, "kind": "ember", "t": 0.0}
	b.merge(o, true)
	Run.bullets.append(b)
	return b

func test_muro_senza_rimbalzo() -> void:
	_shot(Consts.RX + 20, 120, -600, 0)
	for i in 10:
		Bullets.update_player(Consts.DT)
	eq(Run.bullets.size(), 0)

func test_rimbalzo() -> void:
	var b := _shot(Consts.RX + 20, 120, -600, 0, {"bounce": 1})
	for i in 4:
		Bullets.update_player(Consts.DT)
	check(b.vx > 0, "rimbalzato")
	eq(b.bounce, 0)

func test_perforazione() -> void:
	var a := TH.spawn("ghoul", 200, 120)
	var c := TH.spawn("ghoul", 240, 120)
	_shot(170, 120, 300, 0, {"pierce": 1})
	for i in 30:
		Bullets.update_player(Consts.DT)
	check(a.hp < a.max_hp and c.hp < c.max_hp, "entrambi colpiti")
	eq(Run.bullets.size(), 0)

func test_schegge_sul_muro() -> void:
	Run.player.stats.split = 1
	_shot(Consts.RX + 20, 120, -600, 0)
	for i in 3:
		Bullets.update_player(Consts.DT)
	eq(Run.bullets.filter(func(b): return b.kind == "shard").size(), 3)

func test_colpo_nemico_e_stato() -> void:
	var p := Run.player
	var hp := p.hp
	Run.ebullets.append({"x": p.x - 20, "y": p.y - 1, "vx": 300.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "violet", "status": "slow", "src": "Prova", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false})
	for i in 10:
		Bullets.update_enemy(Consts.DT)
	check(p.hp < hp)
	check(p.statuses.has("slow"))
	eq(Run.ebullets.size(), 0)

func test_colpi_fantasma_escono_dal_bordo() -> void:
	Run.ebullets.append({"x": Consts.RX + 20.0, "y": 60.0, "vx": -600.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "red", "status": null, "src": "Prova", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false, "ghost": true})
	for i in 5:
		Bullets.update_enemy(Consts.DT)
	eq(Run.ebullets.size(), 0)
```

`godot/tests/test_effects.gd`:
```gdscript
extends TestCase
# Effetti: bombe, esplosioni sulle rocce incrinate, passaggi segreti, onde d'urto, fuoco, evocazioni.

func after() -> void:
	Run.reset()

func _run_fx(seconds: float) -> void:
	for i in int(seconds / Consts.DT) + 1:
		Effects.update(Consts.DT)

func test_bomba_sfonda_le_rocce_incrinate() -> void:
	TH.new_run(11)
	var room := TH.arena()
	var c := RoomU.tile_center(10, 5)
	room.grid[5][10] = Consts.T.CRACK
	Effects.place_bomb(c.x, c.y, "player")
	_run_fx(1.6)
	eq(room.grid[5][10], Consts.T.FLOOR)
	check(room.bgDirty)

func test_bomba_rivela_il_passaggio_segreto() -> void:
	for seed in range(1, 40):
		TH.new_run(seed)
		var secret := TH.room_of("secret")
		if secret.is_empty():
			continue
		var host: Dictionary = {}
		var dir := ""
		for d in RoomU.DIRS:
			var n = RoomU.room_at(Run.floor, secret.gx - RoomU.DIRS[d].dx, secret.gy - RoomU.DIRS[d].dy)
			if n != null and n.type != "secret":
				host = n
				dir = d
				break
		Flow.enter_room(host, null)
		var dc := RoomU.door_center(dir)
		Effects.place_bomb(dc.x, dc.y, "player")
		_run_fx(1.6)
		check(secret.found, "segreto trovato")
		eq(Run.room.grid[RoomU.DIRS[dir].tiles[1][1]][RoomU.DIRS[dir].tiles[1][0]], Consts.T.DOOR)
		return
	fail("nessun piano con stanza segreta nei semi 1-39")

func test_onda_nemica_colpisce_una_volta() -> void:
	TH.new_run(12)
	TH.arena()
	var p := Run.player
	p.inv = 0.0
	var hp := p.hp
	Effects.add({"type": "shockwave", "x": p.x - 40, "y": p.y, "r": 4.0, "maxR": 90.0, "spd": 150.0, "owner": "enemy", "dmg": 5.0, "src": "Onda"})
	_run_fx(0.6)
	check(p.hp < hp)
	var hp2 := p.hp
	p.inv = 0.0
	_run_fx(0.2)
	eq(p.hp, hp2, "una sola volta")

func test_evocazione() -> void:
	TH.new_run(13)
	TH.arena()
	Effects.add({"type": "spawn", "x": 200.0, "y": 120.0, "life": 0.5, "spec": {"type": "rat", "summoned": true}})
	_run_fx(0.55)
	eq(Run.enemies.size(), 1)
	check(Run.enemies[0].summoned)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=status`
Expected: errore, `Status` non dichiarato.

- [ ] **Step 3: `Enemy` (campi e creazione)**

`godot/actors/enemy.gd`:
```gdscript
class_name Enemy
extends Node2D
# Nemico (makeEnemy, updateEnemies, drawEnemy in js/entities.js e js/render.js).
# x, y sono le coordinate logiche del JS; position si allinea a fine tick.

var type := ""
var def: EnemyDef
var display_name := ""
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var r := 5.0
var hp := 1.0
var max_hp := 1.0
var spd := 0.0
var dmg := 0.0
var ai := ""
var fly := false
var st := 0.0
var state := "idle"
var shot_cd := 0.0
var flash := 0.0
var statuses: Dictionary = {}
var frozen := 0.0
var freeze_cd := 0.0
var stun := 0.35
var facing := 0.0
var anim := 0.0
var mod: Variant = null
var kbx := 0.0
var kby := 0.0
var xp := 0.0
var z := 0.0
var alpha := 1.0
var intangible := false
var wind := 0.0
var orb_cd := 0.0
var t := 0.0
var elite := false
var no_split := false
var summoned := false
var summoner: Variant = null
var spawning := false
var dead := false
var boss := false
var hit_wall := false
var shield_down := false
var wander: Variant = null
var wander_t: Variant = null
# campi che le AI del JS creano al volo
var jit: Variant = null
var jit_t := 0.0
var charge_a := 0.0
var trail_t := 0.0
var orbit_dir := 0
var burst_left := 0
var burst_t := 0.0
var charge_line: Variant = null
var slam_target: Variant = null
var dying: Variant = null
var invuln := 0.0

static func make(type_: String, x_: float, y_: float, mod_: Variant = null, o: Dictionary = {}) -> Enemy:
	var D := DB.enemy(type_)
	var d := Run.depth
	var e := Enemy.new()
	var hp_ := D.hp * Stats.depth_hp(d) * Stats.ard_hp()
	e.type = type_
	e.def = D
	e.display_name = D.name
	e.x = x_
	e.y = y_
	e.r = D.r
	e.hp = hp_
	e.max_hp = hp_
	e.spd = D.spd * (1 + 0.03 * (d - 1)) * Run.player.stats.enemySpeed
	e.dmg = D.dmg * Stats.depth_dmg(d) * Stats.ard_dmg()
	e.ai = D.ai
	e.fly = D.fly
	e.shot_cd = U.rnd(0.9, 1.8) + (D.shot.get("cd", 2.0) * 0.4 if not D.shot.is_empty() else 0.0)
	e.anim = U.rnd(0, 3)
	e.mod = mod_
	e.xp = D.xp * 2 * (1 + 0.15 * (d - 1))
	e.t = U.rnd(0, 5)
	if mod_ != null:
		e.elite = true
		e.hp *= 1.6
		e.xp *= 2.2
		if mod_ == "armored":
			e.hp *= 1.5
		if mod_ == "swift":
			e.spd *= 1.4
		e.max_hp = e.hp
	if o.get("small", false):
		e.hp *= 0.5
		e.max_hp = e.hp
		e.no_split = true
	if not Run.room.is_empty() and Run.player.stats.bellStun and not o.get("summoned", false):
		e.stun = maxf(e.stun, Run.player.stats.bellStun)
	e.position = Vector2(x_, y_)
	return e
```

- [ ] **Step 4: `Status`, `Combat`, `Effects`, `Bullets`, `Pickups`**

Portare in classi statiche, con le regole di traduzione (riferimenti in `js/entities.js`):

| File | Funzioni GDScript | Righe JS |
|---|---|---|
| `combat/status.gd` (`class_name Status`) | `add`, `update`, `cleanse` | 127-129, 148-187 |
| `combat/combat.gd` (`class_name Combat`) | `hurt_player`, `player_death`, `revive_burst` | 481-549 |
| | `hit_enemy`, `kill_enemy`, `enemy_colors` | 1087-1181 |
| | `chain_lightning` | 634-651 |
| | `damage_tile`, `explode_barrel`, `break_urn` | 656-682 |
| | `freeze_all` | 1685-1689 |
| `combat/effects.gd` (`class_name Effects`) | `add`, `place_bomb`, `update`, `explosion_hit` | 1525-1626, 1635-1683 |
| `combat/bullets.gd` (`class_name Bullets`) | `e_shoot`, `shot_opts` | 722-735 |
| | `update_player`, `spawn_shards`, `bullet_hit` | 554-633 |
| | `update_enemy`, `color_of` | 1485-1520 |
| `combat/pickups.gd` | `update`, `collect` | 1703-1751 |

Punti non meccanici:
- `isP = run && a === run.player` → `a == Run.player` (identità di oggetti, corretta per i nodi). Per i nemici `a.boss`, `a.frozen`, `a.freeze_cd`.
- In `Status.update` iterare su `a.statuses.keys()` (si cancellano chiavi durante il ciclo). Il danno nel tempo al giocatore chiama `Combat.hurt_player(v, "Le fiamme" | "Il veleno", {"dot": true})`, ai nemici `Combat.hit_enemy(a, v, {"dot": k})`.
- `hurt_player` usa `p.damage_taken(amount)` per la formula; `Run.victory_t != 0` sostituisce `run.victoryT`; `Run.dmg_taken += dmg`; i colori dei numeri da `Txt.COLORS`.
- `kill_enemy`: il ramo `if (e.boss) { startBossDeath(e); return; }` arriva nel Task 22; `run.room.pickups.push(...)` → `Run.room.pickups.append(Pickups.make(...))`; i nuovi nemici (scissione, `e.D.split`) con `Run.add_enemy(ne)`; `e.D.deathCloud` → `e.def.death_cloud`.
- In `hit_enemy`, `e.D && e.D.shield` → `e.def != null and e.def.shield`; `Save.data.settings.numbers` per i numeri.
- Insiemi `hit` dei proiettili e delle onde: `Dictionary` con il nodo nemico come chiave (`b.hit[e] = true`, `b.hit.has(e)`); `new Set(b.hit)` → `b.hit.duplicate()`.
- `run.bullets = run.bullets.filter(b => !b.dead)` → riassegnare `Run.bullets` con `filter`; `run.enemies.filter` → `Run.prune_enemies()` solo dove il JS filtra i nemici (nel Task 19).
- In `Effects.update`, `if (f.delay) {...}` → `if f.get("delay", 0.0) > 0: f.delay -= dt; if f.delay > 0: continue; f.delay = 0.0`; `f.tick = (f.tick || 0) - dt` → `f.tick = f.get("tick", 0.0) - dt`; il caso `spawn` per ora crea solo nemici (`Enemy.make(sp.type, f.x, f.y, sp.get("mod"), {"summoned": sp.get("summoned", false)})`, `e.summoner = sp.get("summoner")`, `e.summoned = sp.get("summoned", false)`, `Run.add_enemy(e)`); il caso `beam` non c'è (raggi del Divoratore e dell'Abisso, fuori da questa slice). Alla fine `Run.room.spikeT += dt`.
- `explosion_hit`: `run.flashLight = {x, y, t: 0.3, r: f.r * 3}`; rocce distrutte solo se `f.owner == "neutral"`; passaggi segreti con `RoomU.DIRS[d].tiles`, `room.bgDirty = true`, `Run.toast("Un passaggio segreto!", "#f6cf57")`.
- `bullet_hit` e `chain_lightning` usano `Run.player.damage()` al posto di `pDamage(p)`.
- `Pickups.update`: la condizione `auto` del JS usa la precedenza `k.type === 'xp' || ((k.type === 'coin' || k.type === 'coin5') && !room.combat)`: rispettarla con le parentesi.
- `collect`: `addCoins` → `p.add_coins`, testi `"+olio"`, `"+1 chiave"`; il toast del consumabile usa `Cons.ALL[k.id].name` e `.desc`.

- [ ] **Step 5: Eseguire i test**

Run: `tools/test.sh --only=enemy_make && tools/test.sh --only=status && tools/test.sh --only=combat && tools/test.sh --only=bullets && tools/test.sh --only=effects`
Expected: tutti superati.

- [ ] **Step 6: Commit**

```bash
git add godot/actors/enemy.gd godot/actors/player.gd godot/combat godot/tests
git commit -m "Nucleo del combattimento: stati, danni, effetti, proiettili, raccoglibili

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 18: Il giocatore combatte; disegno di proiettili, effetti e raccoglibili

**Files:**
- Modify: `godot/actors/player.gd` (resto di `tick`, sparo, Vampata, riflesso, lucciole, disegno di scudo e lucciole)
- Create: `godot/world/draw_air.gd`, `godot/world/draw_overlay.gd`
- Modify: `godot/world/draw_ground.gd` (effetti a terra, raccoglibili)
- Modify: `godot/world/flow.gd` (`update_game`: proiettili, effetti, raccoglibili, braci d'olio)
- Modify: `godot/scenes/play.tscn`, `godot/scenes/play.gd` (nodi `Air`, `OverlayLayer/Overlay`)
- Test: `godot/tests/test_player_combat.gd`

**Interfaces:**
- Produces:
  - `Player`: `fire()`, `fire_volley(aim_: float, is_echo := false)`, `try_flare()`, `reflect_bullets(px, py, R)`, `orbital_positions() -> Array` (di `Vector2`, valori di disegno e collisione), `update_orbitals(dt)`.
  - Nodi di disegno: `World/Air` (`draw_air.gd`: proiettili del giocatore, particelle basse, effetti in aria), `OverlayLayer` (`CanvasLayer`, `layer = 2`) con `Overlay` (`draw_overlay.gd`: proiettili nemici, particelle alte, numeri; telegrafi e occhi nel Task 19, prompt nel Task 21).
  - `Flow.update_game(dt)` ora esegue, nell'ordine del JS: giocatore, campo di flusso, (nemici: Task 19), `Bullets.update_player`, `Bullets.update_enemy`, `Effects.update`, `Pickups.update`, (flusso della stanza: Task 20), (oggetto vicino e interazione: Task 21), porte, braci d'olio.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_player_combat.gd`:
```gdscript
extends TestCase
# Sparo, Vampata, riflesso, lucciole, sole, tempesta, spuntoni, olio, scudo.

var p: Player

func before() -> void:
	TH.new_run(21)
	var room := TH.arena()
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			room.grid[ty][tx] = Consts.T.FLOOR
	p = Run.player
	p.inv = 0.0
	p.stats.crit = 0.0

func after() -> void:
	Controls.sim.clear()
	Run.reset()

func test_raffica_e_ventaglio() -> void:
	p.stats.proj = 3
	p.fire_volley(0.0)
	eq(Run.bullets.size(), 3)
	var a0 := atan2(Run.bullets[0].vy, Run.bullets[0].vx)
	var a2 := atan2(Run.bullets[2].vy, Run.bullets[2].vx)
	near(a2 - a0, 0.26, 0.08, "apertura 0,13 per proiettile in più (più il tremolio)")
	near(Run.bullets[1].dmg, p.damage())

func test_critico() -> void:
	p.stats.crit = 1.0
	p.fire_volley(0.0)
	near(Run.bullets[0].dmg, p.damage() * p.stats.critMult)
	check(Run.bullets[0].crit)

func test_cometa_ogni_sei_colpi() -> void:
	p.stats.comet = 1
	for i in 6:
		p.fire_volley(0.0)
	eq(Run.bullets.filter(func(b): return b.kind == "comet").size(), 1)

func test_sparo_tenendo_premuto() -> void:
	Controls.sim = {"fire": true, "device": "mouse", "mouse": Vector2(p.x + 50, p.y - 4)}
	p.fire_cd = 0.0
	p.tick(Consts.DT)
	eq(Run.bullets.size(), 1)
	near(p.fire_cd, 1.0 / p.fire_rate())

func test_vampata() -> void:
	var e := TH.spawn("ghoul", p.x + 40, p.y)
	Run.ebullets.append({"x": p.x + 20, "y": p.y, "vx": 0.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "red", "status": null, "src": "x", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false})
	p.oil = 100.0
	p.try_flare()
	near(p.oil, 100.0 - p.stats.flareCost)
	check(e.hp < e.max_hp)
	check(e.statuses.has("burn"))
	check(Run.ebullets[0].get("dead", false))
	near(p.flare_cd, 0.9)

func test_vampata_senza_olio() -> void:
	p.oil = 5.0
	p.try_flare()
	eq(p.oil, 5.0)
	near(p.flare_cd, 0.4)

func test_lucciole() -> void:
	p.stats.orbit = 2
	var pos := p.orbital_positions()
	eq(pos.size(), 2)
	near(pos[0].distance_to(Vector2(p.x, p.y - 2)), 22.0, 1e-4)
	var e := TH.spawn("ghoul", pos[0].x, pos[0].y)
	p.update_orbitals(Consts.DT)
	check(e.hp < e.max_hp)
	near(e.orb_cd, 0.35)

func test_tempesta() -> void:
	p.stats.storm = 1
	var e := TH.spawn("ghoul", p.x + 100, p.y)
	for i in 181:
		p.tick(Consts.DT)
	check(e.hp < e.max_hp, "un fulmine ogni 3 secondi")
	eq(Run.fx.filter(func(f): return f.type == "bolt").size(), 1)

func test_olio_si_consuma_in_combattimento() -> void:
	p.oil = 50.0
	for i in 60:
		p.tick(Consts.DT)
	near(p.oil, 50.0 - 1.05, 1e-6)

func test_spuntoni() -> void:
	var t := RoomU.world_to_tile(p.x, p.y + 2)
	Run.room.grid[t.y][t.x] = Consts.T.SPIKE
	Run.room.spikeT = 2.5
	var hp := p.hp
	p.tick(Consts.DT)
	eq(p.hp, hp - p.damage_taken(8 * Stats.depth_dmg(1)))

func test_scudo_del_lume_si_ricarica() -> void:
	p.stats.guardian = 1
	p.guard_t = 0.1
	for i in 7:
		p.tick(Consts.DT)
	check(p.guard_up)

func test_scatto_riflettente() -> void:
	p.stats.dashReflect = 1
	Run.ebullets.append({"x": p.x + 10, "y": p.y, "vx": -50.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "red", "status": null, "src": "x", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false})
	Controls.sim = {"pressed": ["dash"], "move": Vector2(1, 0)}
	p.tick(Consts.DT)
	check(Run.ebullets[0].get("dead", false))
	eq(Run.bullets.size(), 1)
	check(Run.bullets[0].vx > 0, "rimandato indietro")
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=player_combat`
Expected: errore, `fire_volley` non trovato.

- [ ] **Step 3: Completare `Player.tick` e le azioni di combattimento**

In `godot/actors/player.gd`:
- Nel blocco dello scatto aggiungere, come nel JS: alla partenza `if s.dashReflect: reflect_bullets(x, y, 34)`; durante lo scatto la scia di fuoco (`s.dashfire`, una fiamma ogni 0,035 s con `Effects.add({"type": "fire", "x": x, "y": y + 3, "r": 8, "life": 2.2, "owner": "player"})`) e `reflect_bullets(x, y, 26)`.
- Dopo il movimento portare `js/entities.js:322-370`: sparo (`Controls.firing()`, `fire_cd`, `Run.lock_fire`), Vampata (`Controls.flare()`), eco (`echo_t`), consumo dell'olio in combattimento (`Run.room.combat and not s.noOilDrain`), Lume Custode, lucciole temporanee, `orbit_a += dt * 3.2`, `update_orbitals(dt)`, Piccolo Sole, Bottiglia di Tempesta (bersaglio con `U.pick` tra i nemici vivi, tangibili e non in comparsa; fulmine `{"type": "bolt", "pts": [[e.x + U.rnd(-10, 10), Consts.RY], [e.x, e.y]], "life": 0.25}`), spuntoni (`RoomU.spikes_up(Run.room)`). La riga dei consumabili (`Act.slot()`) arriva nel Task 21.
- Metodi `fire()`, `fire_volley(aim_, is_echo := false)`, `try_flare()`, `reflect_bullets(px, py, R)`, `orbital_positions() -> Array`, `update_orbitals(dt)` ← `playerFire`, `fireVolley`, `tryFlare`, `reflectBullets`, `orbitalPositions`, `updateOrbitals` (`js/entities.js:384-479`). I proiettili sono i dizionari dell'interfaccia del Task 17; `run.flashLight = {x, y, t: 0.5}` → `Run.flash_light = {"x": x, "y": y, "t": 0.5}`.
- In `_draw()` aggiungere scudo del Lume e lucciole (`js/render.js:431-434`).

- [ ] **Step 4: Disegno di proiettili, effetti e raccoglibili**

`godot/world/draw_air.gd`:
```gdscript
extends Node2D
# Sopra gli attori e sotto la luce (drawWorld in js/render.js): proiettili del giocatore,
# particelle basse, effetti in aria.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	_player_bullets()
	Particles.draw(self, false)
	_air_fx()
```
con `_player_bullets` ← `drawPlayerBullets` e `_air_fx` ← `drawAirFx` (`js/render.js:203-249`, `486-501`). Per il fulmine (`bolt`) usare `draw_polyline` due volte (2 px `#c8f2f5`, poi 1 px bianco) con i punti spezzati da `Fx.vrnd(-4, 4)`.

`godot/world/draw_overlay.gd`:
```gdscript
extends Node2D
# Sovrimpressione visibile anche al buio (drawWorld in js/render.js): telegrafi, occhi,
# proiettili nemici, particelle alte, numeri fluttuanti, prompt d'interazione.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	_enemy_bullets()
	Particles.draw(self, true)
	Floaters.draw(self)
```
con `_enemy_bullets` ← `drawEnemyBullets` (`js/render.js:502-519`); l'osso (`bone`) con due `draw_line` (4 px `#0b0810`, poi 2 px `#e8e4dc`), estremità arrotondate non necessarie.

In `godot/world/draw_ground.gd`, dopo `_dynamic_tiles(room)`, aggiungere `_ground_fx()` ← `drawGroundFx` e `_pickups(room)` ← `drawPickups` (`js/render.js:168-202`, `385-404`); la chiamata a `_objects(room)` arriverà nel Task 21 tra le due, come nel JS.

In `godot/scenes/play.tscn` aggiungere (aggiornando `load_steps` e gli id):
```
[ext_resource type="Script" path="res://world/draw_air.gd" id="5"]
[ext_resource type="Script" path="res://world/draw_overlay.gd" id="6"]

[node name="Air" type="Node2D" parent="World"]
script = ExtResource("5")

[node name="OverlayLayer" type="CanvasLayer" parent="."]
layer = 2

[node name="Overlay" type="Node2D" parent="OverlayLayer"]
script = ExtResource("6")
```
In `play.gd`, `_process`: dopo `world.position = off` aggiungere `$OverlayLayer.offset = off`.

- [ ] **Step 5: `Flow.update_game` completo per questa fase**

In `godot/world/flow.gd`, `update_game(dt)` diventa (le righe segnate arrivano nei task indicati):
```gdscript
static func update_game(dt: float) -> void:
	Run.time += dt
	Run.player.tick(dt)
	Run.flow_t -= dt
	if Run.flow_t <= 0:
		FlowField.update()
		Run.flow_t = 0.18
	Bullets.update_player(dt)
	Bullets.update_enemy(dt)
	Effects.update(dt)
	Pickups.update(dt)
	if not Run.player.dead:
		check_doors(dt)
	for o in Run.oil_fx:
		o.t += dt
	Run.oil_fx = Run.oil_fx.filter(func(o): return o.t < 0.45)
```

- [ ] **Step 6: Eseguire i test**

Run: `tools/test.sh`
Expected: tutti superati (compresi quelli dei task precedenti).

- [ ] **Step 7: Verifica visiva**

Run: `godot --path godot -- --seed=7 --perks=multishot,multishot,comet,orbit --relics=r_anvil` e provare: sparo col mouse, Vampata (F o tasto destro), bombe (2), scatto. I proiettili devono essere identici al JS (cerchio arancio con centro chiaro, critici bianchi, comete azzurre), le lucciole ruotare attorno al giocatore.

- [ ] **Step 8: Commit**

```bash
git add godot/actors/player.gd godot/world godot/scenes godot/tests/test_player_combat.gd
git commit -m "Il giocatore combatte: sparo, Vampata, lucciole; disegno di proiettili ed effetti

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 19: Nemici delle Cripte

**Files:**
- Create: `godot/actors/ai.gd`
- Modify: `godot/actors/enemy.gd` (`tick`, `think`, `dying_update`, `target`, `update_all`, `sync`, `_draw`)
- Modify: `godot/world/draw_overlay.gd` (telegrafi, occhi)
- Modify: `godot/world/flow.gd` (`Enemy.update_all(dt)` dopo il campo di flusso)
- Modify: `godot/autoload/game.gd` (`--spawn=tipo,tipo`)
- Test: `godot/tests/test_enemies.gd`

**Interfaces:**
- Produces:
  - `AI` (statiche): `run(e, dt, tg, m)`, `chaser`, `erratic`, `shooter`, `caster`, `charger`, `shooter_fire(e, dt, tg)`. Le altre AI del JS (`turret`, `hopper`, `shielder`, `kamikaze`, `phaser`, `dasher`, `teleporter`, `summoner`, `spinner`) servono alle profondità 2–5 e non fanno parte di questa slice.
  - `Enemy.tick(dt)` (corpo del ciclo di `updateEnemies`), `Enemy.think(dt, tg, m)` (chiama `AI.run`; il `Boss` la sovrascrive), `Enemy.dying_update(dt)` (vuota: solo i boss muoiono lentamente; il `Boss` la sovrascrive), `Enemy.target()` (`enemyTarget`), `static Enemy.update_all(dt)` (ciclo, separazione, rimozione dei morti con `Run.prune_enemies()`), `sync()`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_enemies.gd`:
```gdscript
extends TestCase
# IA delle Cripte, separazione, contatto, rimozione dei morti.

func before() -> void:
	TH.new_run(31)
	var room := TH.arena()
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			room.grid[ty][tx] = Consts.T.FLOOR
	FlowField.update()

func after() -> void:
	Run.reset()

func _run(seconds: float) -> void:
	for i in int(seconds / Consts.DT):
		Enemy.update_all(Consts.DT)

func test_il_ratto_insegue() -> void:
	var p := Run.player
	var e := TH.spawn("rat", p.x + 150, p.y)
	var d0 := U.dist(e.x, e.y, p.x, p.y)
	p.inv = 99.0
	_run(1.0)
	check(U.dist(e.x, e.y, p.x, p.y) < d0 - 40)

func test_il_ghoul_carica() -> void:
	var p := Run.player
	p.inv = 99.0
	var e := TH.spawn("ghoul", p.x + 100, p.y)
	var seen := {}
	for i in 240:
		Enemy.update_all(Consts.DT)
		seen[e.state] = true
	for s in ["approach", "wind", "charge", "recover"]:
		check(seen.has(s), "stato " + s)

func test_lo_scheletro_tira_ossa() -> void:
	var p := Run.player
	p.inv = 99.0
	var e := TH.spawn("skeleton", p.x + 120, p.y)
	e.shot_cd = 0.0
	_run(0.5)
	var bones := Run.ebullets.filter(func(b): return b.kind == "bone")
	eq(bones.size(), 1)

func test_il_teschio_spara_ad_anello() -> void:
	var p := Run.player
	p.inv = 99.0
	var e := TH.spawn("skull", p.x + 100, p.y)
	e.shot_cd = 0.0
	_run(0.6)
	eq(Run.ebullets.size(), 6)

func test_separazione() -> void:
	var a := TH.spawn("rat", 200, 100)
	var b := TH.spawn("rat", 200.5, 100)
	a.stun = 1.0
	b.stun = 1.0
	Enemy.update_all(Consts.DT)
	check(U.dist(a.x, a.y, b.x, b.y) > 1.0)

func test_contatto_e_morti_rimossi() -> void:
	var p := Run.player
	p.inv = 0.0
	var e := TH.spawn("rat", p.x + 3, p.y)
	var hp := p.hp
	Enemy.update_all(Consts.DT)
	check(p.hp < hp)
	e.dead = true
	Enemy.update_all(Consts.DT)
	eq(Run.enemies.size(), 0)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=enemies`
Expected: errore, `update_all` non trovato.

- [ ] **Step 3: Implementare**

`godot/actors/ai.gd` — porta le AI usate dalle Cripte e `shooterFire` (`js/entities.js:737-806`, `989-1023`):
```gdscript
class_name AI
extends RefCounted
# Comportamenti dei nemici (AI in js/entities.js). Firma comune: (e, dt, tg, m),
# con tg il bersaglio ({x, y} o il giocatore) e m il moltiplicatore di velocità.

static func run(e: Enemy, dt: float, tg, m: float) -> void:
	match e.ai:
		"chaser": chaser(e, dt, tg, m)
		"erratic": erratic(e, dt, tg, m)
		"shooter": shooter(e, dt, tg, m)
		"caster": caster(e, dt, tg, m)
		"charger": charger(e, dt, tg, m)
```
seguita da `chaser`, `erratic`, `shooter`, `caster`, `charger`, `shooter_fire`, portati riga per riga. `e.D.burst` → `e.def.burst`; `e.D.shot` → `e.def.shot` (dizionario vuoto se assente: `S.is_empty()` sostituisce `!S`); `e.jit` nullo all'inizio come `undefined` nel JS; `e.orbitDir || (e.orbitDir = ...)` → `if e.orbit_dir == 0: e.orbit_dir = 1 if U.chance(0.5) else -1`; il ramo `trail` della `chaser` crea il fuoco con `Effects.add`.

In `godot/actors/enemy.gd` portare il corpo del ciclo di `updateEnemies` (`js/entities.js:1027-1065`) in `tick(dt)`, la separazione e il filtro finale (`1066-1084`) in `static func update_all(dt)`, `enemyTarget` (`709-720`) in `target()`, e `drawEnemy` (`js/render.js:437-484`) in `_draw()`:
```gdscript
func think(dt: float, tg, m: float) -> void:
	AI.run(self, dt, tg, m)

# solo i boss muoiono lentamente (bossDying); il Boss la sovrascrive
func dying_update(_dt: float) -> void:
	pass

static func update_all(dt: float) -> void:
	var i := 0
	while i < Run.enemies.size():
		var e: Enemy = Run.enemies[i]
		if not e.dead:
			e.tick(dt)
		i += 1
	# ... separazione come nel JS (solo tra nemici vivi, non boss, con lo stesso fly)
	Run.prune_enemies()

func sync() -> void:
	position = Vector2(x, y)
	queue_redraw()

func _process(_delta: float) -> void:
	sync()
```
Note di porting:
- In `tick`, `if (e.dying !== undefined) { bossDying(e, dt); continue; }` → `if dying != null: dying_update(dt); return`; `if (e.boss) bossUpdate(...) else AI[e.ai](...)` → `think(dt, target(), m)`.
- Contatto: `e.D && e.D.touch` → `def != null and def.touch != ""`.
- `_draw()` inizia con `UiDraw.set_origin(self, -position)`; lo sprite è `def.spr` (per i boss `B.spr`, Task 22); `SIDE_SPRITES` del JS corrisponde a `def.side`; il contorno d'élite usa `Spr.draw_sil` con offset `±1` nelle quattro direzioni e alfa `0.45 + 0.25 * sin(Fx.time * 6)`; tinte di gelo, bruciatura, veleno e preavviso come nel JS (`o.tint`, `o.tintA`); scudo frontale con `draw_arc` (non serve alle Cripte, ma va portato perché fa parte di `drawEnemy`); barra della vita con `UiDraw.bar`.

In `godot/world/draw_overlay.gd`, prima di `_enemy_bullets()`, aggiungere `_telegraphs()` ← `drawTelegraphs` (`js/render.js:252-312`, **senza** il ramo `beam`) e `_eyes()` ← `drawEyes` (`522-537`). Le linee tratteggiate con `draw_dashed_line(from, to, colore, spessore, lunghezza_trattino)`.

In `godot/world/flow.gd`, `update_game`: subito dopo l'aggiornamento del campo di flusso aggiungere `Enemy.update_all(dt)`.

In `godot/autoload/game.gd`, in `dev_start()` prima di `set_scene("play")`:
```gdscript
	# --spawn=rat,bat: nemici nella stanza corrente, per provare le IA
	if dev.has("spawn"):
		Run.room.combat = true
		Run.room.waves = []
		var tiles: Array = []
		for t in RoomU.reach_tiles(Run.room):
			var tc := RoomU.tile_center(t.x, t.y)
			if U.dist(tc.x, tc.y, Run.player.x, Run.player.y) > 60:
				tiles.append(t)
		for type in str(dev.spawn).split(","):
			var t: Vector2i = U.pick(tiles)
			var c := RoomU.tile_center(t.x, t.y)
			var e := Enemy.make(type, c.x, c.y)
			e.stun = 0.5
			Run.add_enemy(e)
```

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh`
Expected: tutti superati.

- [ ] **Step 5: Verifica visiva**

Run: `godot --path godot -- --seed=7 --spawn=rat,bat,skeleton,skull,ghoul,ghoul` e confrontare con le Cripte del JS: movimenti (ratto a scatti, pipistrello erratico, scheletro che arretra, teschio che orbita, ghoul che carica con la linea rossa tratteggiata), occhi rossi nel buio, scintilla gialla di preavviso, barre della vita, lampo bianco ai colpi.

- [ ] **Step 6: Commit**

```bash
git add godot/actors godot/world godot/autoload/game.gd godot/tests/test_enemies.gd
git commit -m "Nemici delle Cripte: IA, contatto, separazione e disegno

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 20: Flusso della stanza: ondate e ricompense

**Files:**
- Modify: `godot/world/flow.gd` (`update_room_flow`, `spawn_wave`, `room_cleared`; chiamata in `update_game`)
- Test: `godot/tests/test_room_flow.gd`, `godot/tests/test_smoke.gd`

**Interfaces:**
- Produces: `Flow.update_room_flow(dt)`, `Flow.spawn_wave(room, wave)`, `Flow.room_cleared(room)`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_room_flow.gd`:
```gdscript
extends TestCase
# Ondate, stanza ripulita, porte che si aprono, ricompense.

func after() -> void:
	Run.reset()

func test_ondata_compare_e_la_stanza_si_ripulisce() -> void:
	TH.new_run(41)
	var room := TH.enter("normal")
	check(room.combat)
	for i in 70:
		Run.player.inv = 99.0
		Flow.update_game(Consts.DT)
	check(not Run.enemies.is_empty(), "prima ondata comparsa")
	room.waveIdx = room.waves.size()   # niente altre ondate
	for i in 180:
		Run.player.inv = 99.0
		for e in Run.enemies.duplicate():
			Combat.kill_enemy(e)
		Run.prune_enemies()
		Flow.update_game(Consts.DT)
	check(room.cleared and not room.combat)
	eq(Run.rooms_cleared, 1)
	var d: String = room.doors.keys()[0]
	check(RoomU.door_open(room, d) or RoomU.door_locked(room, d))
```

`godot/tests/test_smoke.gd`:
```gdscript
extends TestCase
# Prove di gioco simulate: si spara al nemico più vicino finché la stanza è ripulita.

func after() -> void:
	Controls.sim.clear()
	Run.reset()

static func nearest() -> Variant:
	var best: Variant = null
	var bd := INF
	for e in Run.enemies:
		if e.dead or e.spawning:
			continue
		var d := U.dist(e.x, e.y, Run.player.x, Run.player.y)
		if d < bd:
			bd = d
			best = e
	return best

static func fight(max_ticks: int, done: Callable) -> bool:
	for i in max_ticks:
		Run.player.inv = 99.0
		var e: Variant = nearest()
		Controls.sim = {"device": "mouse", "fire": e != null}
		if e != null:
			Controls.sim.mouse = Vector2(e.x, e.y)
		Flow.update_common(Consts.DT)
		if Run.trans != null:
			Flow.update_trans(Consts.DT)
		else:
			Flow.update_game(Consts.DT)
		Controls.end_tick()
		if done.call():
			return true
	return false

func test_stanza_di_combattimento_ripulita() -> void:
	TH.new_run(17)
	var room := TH.room_of("normal")
	RoomBuilder.build_room(room, Run.floor)
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			if room.grid[ty][tx] != Consts.T.FLOOR:
				room.grid[ty][tx] = Consts.T.FLOOR
	Flow.enter_room(room, null)
	check(fight(5400, func(): return room.cleared), "stanza ripulita entro 90 s simulati")
	check(Run.kills > 0)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=room_flow`
Expected: FAIL, nessun nemico compare (il flusso della stanza non c'è ancora).

- [ ] **Step 3: Implementare**

In `godot/world/flow.gd` portare `updateRoomFlow`, `spawnWave`, `roomCleared` (`js/game.js:97-159`): `run.fx.some(f => f.type === 'spawn')` → `Run.fx.any(func(f): return f.type == "spawn")`; le caselle per l'ondata con `RoomU.reach_tiles(room)` filtrate per `FLOOR` e distanza, `U.shuffle(tiles)`; ogni nemico con `Effects.add({"type": "spawn", ... "spec": {"type": spec.type, "mod": spec.mod}})`; il ramo `BOSS` di `spawnWave` (`js/game.js:115-120`) va portato ora: crea l'effetto `spawn` con `spec = {"type": "BOSS", "boss": ...}`, che l'effetto gestirà dal Task 22; le ricompense con `U.weighted_pick([["coins", 30], ["heart", 18], ["oil", 18], ["cons", 14], ["key", 9], ["chest", 11]], func(k): return k[1])[0]`; il ramo `elite` va portato anche se la stanza élite compare solo dalla Profondità 2.

In `update_game` aggiungere `update_room_flow(dt)` subito dopo `Pickups.update(dt)`.

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh --only=room_flow && tools/test.sh --only=smoke`
Expected: superati.

- [ ] **Step 5: Verifica visiva**

Run: `godot --path godot -- --seed=7 --test=fight --sim=240 --fire --screenshot=/tmp/ul_t20.png --shot-after=10`, poi una partita a mano con `--test=fight`: cerchi viola di comparsa, porte che si chiudono (suono `lock`) e si riaprono a stanza ripulita (suono `door`), ricompensa al centro, musica che passa da intensità 1 a 0.

- [ ] **Step 6: Commit**

```bash
git add godot/world/flow.gd godot/tests/test_room_flow.gd godot/tests/test_smoke.gd
git commit -m "Flusso della stanza: ondate, stanza ripulita, ricompense; prova simulata

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 21: Oggetti della stanza, interazioni e consumabili

**Files:**
- Create: `godot/world/interact.gd`
- Modify: `godot/data/consumables.gd` (aggiunge `use(id, p) -> bool`)
- Modify: `godot/actors/player.gd` (`use_cons(i)` e la riga dei consumabili in `tick`)
- Modify: `godot/world/flow.gd` (`reveal_map`, `roll_dice`; oggetto vicino e interazione in `update_game`)
- Modify: `godot/world/draw_ground.gd` (`_objects`), `godot/world/draw_overlay.gd` (`_prompt`)
- Test: `godot/tests/test_interact.gd`

**Interfaces:**
- Produces:
  - `Interact` (statiche): `nearest_object() -> Variant`, `interact(o)`, `take_relic(o)`, `open_chest(o)`, `price_of(o) -> int`, `buy_item(o)`, `use_shrine(o)`.
  - `Cons.use(id, p) -> bool` (vero se il consumabile è stato usato), `Player.use_cons(i)`, `Flow.reveal_map()`, `Flow.roll_dice()`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_interact.gd`:
```gdscript
extends TestCase
# Reliquie, forzieri, mercante, santuari e consumabili.

var p: Player

func before() -> void:
	TH.new_run(51)
	p = Run.player

func after() -> void:
	Run.reset()

func test_reliquia_del_tesoro_esclude_l_altra() -> void:
	var room := TH.enter("treasure")
	var relics: Array = room.objects.filter(func(o): return o.type == "relic")
	if relics.size() < 2:
		return
	Interact.take_relic(relics[0])
	check(relics[0].gone and relics[1].gone)
	check(p.relics.has(relics[0].id))
	eq(Run.banners.size(), 1)

func test_mercante() -> void:
	var room := TH.enter("shop")
	var item: Dictionary = room.objects.filter(func(o): return o.type == "shopitem" and o.item.kind == "cons")[0]
	p.coins = 0
	Interact.buy_item(item)
	check(not item.get("gone", false), "senza monete non si compra")
	p.coins = 999
	Interact.buy_item(item)
	check(item.gone)
	eq(p.coins, 999 - Interact.price_of(item))

func test_forziere_dorato_vuole_una_chiave() -> void:
	var chest := {"type": "chest", "gold": true, "x": 200.0, "y": 100.0}
	TH.arena().objects.append(chest)
	p.keys = 0
	Interact.open_chest(chest)
	check(not chest.get("open", false))
	p.keys = 1
	Interact.open_chest(chest)
	check(chest.open)
	eq(p.keys, 0)

func test_santuari() -> void:
	var room := TH.arena()
	var blood := {"type": "shrine", "kind": "blood", "x": 200.0, "y": 100.0, "uses": 1}
	Interact.use_shrine(blood)
	eq(p.stats.maxHp, 45.0)
	eq(Run.pending_levels, 1)
	check(Run.forced_choices.size() > 0)
	var fountain := {"type": "shrine", "kind": "fountain", "x": 200.0, "y": 100.0, "uses": 1}
	p.hp = 10.0
	Interact.use_shrine(fountain)
	eq(p.hp, p.stats.maxHp, "senza maledizioni ristora")
	var pact := {"type": "shrine", "kind": "pact", "x": 200.0, "y": 100.0, "uses": 1}
	Interact.use_shrine(pact)
	eq(p.curses.size(), 1)
	check(p.relics.size() >= 1)

func test_consumabili() -> void:
	TH.arena()
	p.cons = [{"id": "potion", "n": 2}, {"id": "map", "n": 1}, {"id": "feather", "n": 1}, {"id": "frost", "n": 1}]
	p.hp = p.stats.maxHp
	p.use_cons(0)
	eq(p.cons[0].n, 2, "a vita piena la pozione non si usa")
	p.hp = 10.0
	p.use_cons(0)
	eq(p.hp, 40.0)
	eq(p.cons[0].n, 1)
	p.use_cons(1)
	eq(p.cons[1], null)
	check(Run.floor.rooms.all(func(r): return r.seen))
	p.use_cons(2)
	eq(p.cons[2].n, 1, "la piuma è passiva")
	var e := TH.spawn("ghoul", 200, 100)
	p.use_cons(3)
	eq(e.frozen, 3.0)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=interact`
Expected: errore, `Interact` non dichiarato.

- [ ] **Step 3: Implementare**

- `godot/world/interact.gd` (`class_name Interact`) ← `nearestObject`, `interact`, `takeRelic`, `openChest`, `priceOf`, `buyItem`, `useShrine` (`js/entities.js:1756-1902`). `interact` per `trapdoor` chiama `Flow.descend()`; i `setTimeout` con `U.later`; `x !== o` con `not is_same(x, o)`; `randomRelics(1, { shuffle: a => shuffle(a) })` con `RoomBuilder.random_relics(1)`; `rollPerkChoices` con `Perks.roll_choices`.
- In `godot/data/consumables.gd` aggiungere `static func use(id: String, p) -> bool` con un `match` che porta le funzioni `use` di `CONS` (`js/data.js:142-154`): `healPlayer` → `p.heal`, `addOil` → `p.add_oil`, `placeBomb` → `Effects.place_bomb`, `cleanse`/`addStatus` → `Status.cleanse`/`Status.add`, `freezeAll` → `Combat.freeze_all`, `revealMap` → `Flow.reveal_map`, `rollDice` → `Flow.roll_dice`, `p.tempOrbitT`/`p.tempOrbit` → `p.temp_orbit_t`/`p.temp_orbit`, `recalcStats` → `p.recalc_stats()`; `feather` restituisce `false`.
- In `godot/actors/player.gd`: `use_cons(i)` ← `useCons` (`js/entities.js:118-126`) e, in `tick`, dopo la Vampata: `var sl := Controls.slot()` / `if sl >= 0: use_cons(sl)`.
- In `godot/world/flow.gd`: `reveal_map()` e `roll_dice()` ← `revealMap`, `rollDice` (`js/entities.js:1904-1924`); in `update_game`, dopo `update_room_flow(dt)`:
```gdscript
	Run.focus = null if Run.player.dead else Interact.nearest_object()
	if Run.focus != null and Controls.interact():
		Interact.interact(Run.focus)
```
- In `godot/world/draw_ground.gd`, tra `_ground_fx()` e `_pickups(room)`: `_objects(room)` ← `drawObjects` (`js/render.js:317-383`), con `Interact.price_of`.
- In `godot/world/draw_overlay.gd`, dopo `Floaters.draw(self)`: `_prompt()` ← `drawPrompt` (`js/render.js:616-656`); il tasto mostrato è `X` se `Controls.device() == "pad"`, altrimenti `E`.

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh`
Expected: tutti superati.

- [ ] **Step 5: Verifica visiva**

Run, una alla volta: `godot --path godot -- --seed=7 --test=shop --coins=200`, `--test=treasure`, `--test=shrine`, `--test=secret`. Controllare piedistalli, prezzi in giallo o rosso, battuta del mercante sopra la testa, pannello del prompt con tasto E, forziere dorato con alone, fontana animata, altare con fiamma.

- [ ] **Step 6: Commit**

```bash
git add godot/world godot/data/consumables.gd godot/actors/player.gd godot/tests/test_interact.gd
git commit -m "Oggetti della stanza, interazioni e consumabili

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 22: Il Custode delle Ossa

**Files:**
- Create: `godot/actors/boss.gd`, `godot/actors/boss_patterns.gd`
- Modify: `godot/combat/effects.gd` (ramo `BOSS` dell'evocazione), `godot/combat/combat.gd` (`kill_enemy` per i boss)
- Modify: `godot/world/flow.gd` (`on_boss_defeated`)
- Modify: `godot/tests/test_smoke.gd` (prova del boss)
- Test: `godot/tests/test_boss.gd`

**Interfaces:**
- Consumes: `enemies.json` (`bosses`).
- Produces:
  - `Boss extends Enemy`: `bid`, `B: BossDef`, `phase`, `pat: Variant`, `gap_t`, `last_pat`, `hit_wall_boss`; `static make(id, x, y) -> Boss`, `think` (→ `bossUpdate`), `dying_update` (→ `bossDying`), `start_death()`.
  - `BossPatterns` (statiche): `run(e, P, dt, s) -> bool`, `ring`, `aimed`, `spiral`, `summon`, `charge`, `boss_shoot(e, a, s, extra := {})`. Gli altri pattern del JS (`slam`, `rain`, `wall`, `teleport`, `beam`, `darkpulse`, `drain`) servono ai boss delle profondità 2–5.
  - `Flow.on_boss_defeated(e)`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_boss.gd`:
```gdscript
extends TestCase
# Il Custode delle Ossa: statistiche, fasi, pattern, morte e botola.

var b: Boss

func before() -> void:
	TH.new_run(61)
	TH.arena()
	Run.player.inv = 99.0
	b = Boss.make("bones", 240, 100)
	Run.add_enemy(b)

func after() -> void:
	Run.reset()

func test_statistiche_come_il_js() -> void:
	for c in TestCase.golden("enemies").bosses:
		Run.depth = int(c.depth)
		var x := Boss.make("bones", 0, 0)
		eq({"hp": x.hp, "maxHp": x.max_hp, "spd": x.spd, "dmg": x.dmg, "xp": x.xp, "r": x.r}, c.fields)
		x.free()

func test_cambio_di_fase() -> void:
	b.hp = b.max_hp * 0.49
	Enemy.update_all(Consts.DT)
	eq(b.phase, 1)
	near(b.invuln, 1.4 - Consts.DT, 1e-9)
	eq(Run.ebullets.size(), 20)
	var hp := b.hp
	Combat.hit_enemy(b, 50)
	eq(b.hp, hp, "invulnerabile durante il cambio")

func test_anello() -> void:
	b.pat = {"s": {"p": "ring", "n": 12, "count": 2, "gap": 0.7, "spd": 75.0, "kind": "bone"}, "t": 0.0}
	Enemy.update_all(Consts.DT)
	for i in int(0.45 / Consts.DT):
		Enemy.update_all(Consts.DT)
	eq(Run.ebullets.size(), 12, "prima raffica dopo 0,4 s")
	for i in int(1.0 / Consts.DT):
		Enemy.update_all(Consts.DT)
	eq(b.pat.k, 2, "seconda raffica dopo altri 0,7 s")

func test_evocazione_rispetta_il_limite() -> void:
	b.pat = {"s": {"p": "summon", "type": "skeleton", "count": 2, "cap": 4}, "t": 0.0}
	Enemy.update_all(Consts.DT)
	eq(Run.fx.filter(func(f): return f.type == "spawn").size(), 2)

func test_morte_e_botola() -> void:
	var kills: int = Save.data.stats.bossKills
	Combat.hit_enemy(b, 99999)
	check(b.dying != null)
	for i in int(2.1 / Consts.DT):
		Enemy.update_all(Consts.DT)
	check(Run.enemies.is_empty(), "il boss è morto ed è stato rimosso")
	eq(Save.data.stats.bossKills, kills + 1)
	check(Run.room.objects.any(func(o): return o.type == "trapdoor"))
	check(Run.room.cleared)
```

In `godot/tests/test_smoke.gd` aggiungere:
```gdscript
func test_guardiano_sconfitto() -> void:
	TH.new_run(23)
	var p := Run.player
	p.perks = {"multishot": 3, "dmg": 5, "rate": 5}
	p.relics = ["r_anvil"]
	p.recalc_stats()
	TH.enter("boss")
	check(fight(20000, func(): return Run.room.objects.any(func(o): return o.type == "trapdoor")), "guardiano sconfitto")
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=boss`
Expected: errore, `Boss` non dichiarato.

- [ ] **Step 3: Implementare**

`godot/actors/boss.gd`:
```gdscript
class_name Boss
extends Enemy
# Guardiano di fine profondità (makeBoss, bossUpdate, startBossDeath, bossDying in js/entities.js).

var bid := ""
var B: BossDef
var phase := 0
var pat: Variant = null
var gap_t := 1.6
var last_pat := -1
var hit_wall_boss := false

static func make(id: String, x_: float, y_: float) -> Boss:
	var b_ := DB.boss(id)
	var d := Run.depth
	var cyc := ((d - 1) % 5) + 1
	var extra := Stats.depth_hp(d) / Stats.depth_hp(cyc) if d > 5 else 1.0
	var e := Boss.new()
	e.boss = true
	e.bid = id
	e.B = b_
	e.display_name = b_.name
	e.x = x_
	e.y = y_
	e.r = b_.r
	e.hp = b_.hp * extra * Stats.ard_hp()
	e.max_hp = e.hp
	e.spd = b_.spd
	e.dmg = 13 * Stats.depth_dmg(d) * Stats.ard_dmg()
	e.ai = "boss"
	e.fly = true
	e.stun = 0.0
	e.xp = 60 + 30 * d
	e.position = Vector2(x_, y_)
	return e

func think(dt: float, tg, m: float) -> void:
	_boss_update(dt, tg, m)

func dying_update(dt: float) -> void:
	_boss_dying(dt)
```
Poi portare `bossUpdate` in `_boss_update`, `startBossDeath` in `start_death`, `bossDying` in `_boss_dying` (`js/entities.js:1410-1480`): `e.B.phases` → `B.phases`; `PATTERNS[e.pat.s.p](...)` → `BossPatterns.run(self, pat, dt * rate, pat.s)`; `do { i = rndi(...) } while (...)` → ciclo `while true` con `break`; `toast(e.name + ' si infuria!')` → `Run.toast(display_name + " si infuria!", "#e0574a")`; `Save.data.stats.bossKills += 1`, `Save.write()`, `Flow.on_boss_defeated(self)`; in `start_death` gli effetti `beam` e `warn` si marcano `dead` e gli altri nemici si uccidono con `Combat.kill_enemy(x, {"silent": true})`.

`godot/actors/boss_patterns.gd` (`class_name BossPatterns`) ← `bossShoot` e i pattern `ring`, `aimed`, `spiral`, `summon`, `charge` (`js/entities.js:1200-1273`), con:
```gdscript
static func run(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	match s.p:
		"ring": return ring(e, P, dt, s)
		"aimed": return aimed(e, P, dt, s)
		"spiral": return spiral(e, P, dt, s)
		"summon": return summon(e, P, dt, s)
		"charge": return charge(e, P, dt, s)
	return true
```
`P.init` assente all'inizio: usare `P.get("init", false)`. `bossShoot` unisce le opzioni con `merge`.

In `godot/combat/effects.gd`, nel caso `spawn`, prima del ramo dei nemici:
```gdscript
			if sp.type == "BOSS":
				var b := Boss.make(sp.boss, f.x, f.y)
				Run.add_enemy(b)
				Run.boss_ref = b
```
(e il ramo dei nemici diventa l'`else`). In `godot/combat/combat.gd`, all'inizio di `kill_enemy` dopo il controllo `dead`: `if e.boss: e.start_death(); return`.

In `godot/world/flow.gd` aggiungere `on_boss_defeated(e)` ← `onBossDefeated` (`js/game.js:161-180`); la botola è `{"type": "trapdoor", "x": c.x, "y": c.y + 34}`; il ramo `devourer` del JS non serve alle Cripte ma va portato com'è.

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh`
Expected: tutti superati, compreso `test_guardiano_sconfitto`.

- [ ] **Step 5: Verifica visiva**

Run: `godot --path godot -- --seed=7 --test=boss --perks=multishot,dmg,dmg` e giocare il boss: ingresso con ruggito, comparsa, raffiche mirate di ossa, anelli, evocazione di scheletri e ratti, carica con linea rossa tratteggiata, a metà vita il ruggito con l'anello di 20 colpi e il toast «Il Custode delle Ossa si infuria!», spirale nella seconda fase, morte con esplosioni per 2 secondi, botola viola e reliquia. La barra del boss arriva con l'HUD nel Task 23.

- [ ] **Step 6: Commit**

```bash
git add godot/actors godot/combat godot/world/flow.gd godot/tests/test_boss.gd godot/tests/test_smoke.gd
git commit -m "Il Custode delle Ossa: fasi, pattern, morte e botola

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
## Fase E — Interfaccia e schermate

### Task 23: HUD, minimappa, notifiche, mirino

**Files:**
- Create: `godot/ui/hud.gd`, `godot/ui/map_draw.gd`, `godot/ui/notices.gd`
- Modify: `godot/scenes/play.tscn` (livello `HudLayer` con `Hud`), `godot/scenes/play.gd` (cursore)
- Test: `godot/tests/test_hud.gd`

**Interfaces:**
- Produces:
  - `MapDraw` (statiche): `ROOM_MARK`, `room_known(r) -> bool`, `minimap(ci, x0, y0, full)`, `full_map(ci)`.
  - `Notices.draw(ci)` (toast e banner).
  - `Hud` (`Node2D` in `HudLayer`, `layer = 3`): disegna nell'ordine di `Scenes.play.draw` del JS tutto ciò che segue `drawWorld`, tranne i pannelli: braci d'olio, flash, bordo rosso con poca vita, HUD, notifiche, introduzioni, mirino, dissolvenza della transizione, schermo di morte.
  - `static Play.cursor_hidden(mode: String) -> bool` in `play.gd`.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_hud.gd`:
```gdscript
extends TestCase
# Cursore, stanze note sulla mappa, HUD senza errori.

const PlayScript := preload("res://scenes/play.gd")

func after() -> void:
	Run.reset()

func test_cursor_hidden_only_in_play() -> void:
	check(PlayScript.cursor_hidden("play"))
	for m in ["levelup", "pause", "build", "map", "options"]:
		check(not PlayScript.cursor_hidden(m), m)

func test_stanze_note() -> void:
	TH.new_run(71)
	var secret := TH.room_of("secret")
	if not secret.is_empty():
		check(not MapDraw.room_known(secret))
		secret.mapped = true
		check(MapDraw.room_known(secret))
	var any: Dictionary = Run.floor.rooms[0]
	any.seen = false
	Run.player.stats.mapReveal = 1
	check(MapDraw.room_known(any))

func test_hud_si_disegna() -> void:
	TH.new_run(72)
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	Run.player.hp = 5.0
	Run.toast("Prova", "#ffffff", "sotto")
	Run.banner("Titolo", "Descrizione lunga del banner", "#f6cf57", "i_blade")
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=hud`
Expected: errore, `MapDraw` non dichiarato.

- [ ] **Step 3: Implementare**

- `godot/ui/map_draw.gd` (`class_name MapDraw`) ← `ROOM_MARK`, `roomKnown`, `drawMinimap`, `drawFullMap` (`js/ui.js:150-206`); confronto della stanza corrente con `is_same(r, Run.room)`; le porte verso destra e verso il basso con `RoomU.door_visible`.
- `godot/ui/notices.gd` (`class_name Notices`) ← `drawNotices` (`js/ui.js:24-51`).
- `godot/ui/hud.gd`:
```gdscript
extends Node2D
# Tutto ciò che il JS disegna dopo drawWorld, tranne i pannelli (Scenes.play.draw e drawHUD).

@onready var play: Node = get_parent().get_parent()   # Play/HudLayer/Hud

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	_oil_embers()
	_flash_and_low_hp()
	_hud()
	Notices.draw(self)
	_intro()
	_crosshair()
	_fade_and_death()
```
con, portando `js/game.js:385-420` e `463-481` e `js/ui.js:56-148`:
  - `_oil_embers()`: le braci d'olio che tornano alla lanterna.
  - `_flash_and_low_hp()`: `Fx.flash` con `Fx.flash_col`; il bordo rosso sotto il 30% di vita con una `GradientTexture2D` radiale creata una volta (trasparente fino a 0,375 del raggio, `#a01818` al bordo), disegnata su un quadrato di lato `2 * H * 0.8` centrato sullo schermo con alfa `0.18 + 0.1 * sin(Fx.time * 5)`.
  - `_hud()`: fascia superiore, vita, olio con la tacca della Vampata e la scritta `BUIO`, esperienza, 4 consumabili, monete e chiavi, profondità e bioma, livello, minimappa (`MapDraw.minimap(self, 394, 2, false)`), stati e maledizioni sotto la fascia, cariche di scatto sotto i piedi, barra del boss con le tacche delle fasi (`boss.B.phases`).
  - `_intro()`: `drawIntro` (profondità con il testo del bioma, introduzione del boss con le bande nere).
  - `_crosshair()`: solo se `play.mode == "play"`, `Controls.device() == "mouse"` e giocatore vivo.
  - `_fade_and_death()`: nero con alfa `Flow.trans_alpha()`; con il giocatore morto, velo e scritta «La tua luce si spegne...» in scala 2.
- In `godot/scenes/play.tscn` aggiungere:
```
[ext_resource type="Script" path="res://ui/hud.gd" id="7"]

[node name="HudLayer" type="CanvasLayer" parent="."]
layer = 3

[node name="Hud" type="Node2D" parent="HudLayer"]
script = ExtResource("7")
```
- In `godot/scenes/play.gd`:
```gdscript
static func cursor_hidden(m: String) -> bool:
	return m == "play"
```
e in `_process`, dopo la luce: `Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if cursor_hidden(mode) else Input.MOUSE_MODE_VISIBLE`. In `_exit_tree` riportare `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`.

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh --only=hud`
Expected: 3 test superati, nessun errore di script durante il disegno.

- [ ] **Step 5: Verifica visiva**

Run: `godot --path godot -- --seed=7 --test=boss --sim=200 --screenshot=/tmp/ul_t23.png --shot-after=10` e confrontare con il JS (`index.html?test=boss&sim=200` nel browser, che usa gli stessi parametri): fascia superiore, barre, slot, minimappa, barra del boss con la tacca a metà, introduzione del boss.

- [ ] **Step 6: Commit**

```bash
git add godot/ui godot/scenes godot/tests/test_hud.gd
git commit -m "HUD, minimappa, notifiche e mirino

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 24: Pannelli: doni, pausa, equipaggiamento, mappa, opzioni

**Files:**
- Create: `godot/ui/menu.gd`, `godot/ui/panels_draw.gd`, `godot/ui/panels.gd`
- Modify: `godot/scenes/play.gd` (modalità, apertura dei doni, pausa, mappa, opzioni), `godot/scenes/play.tscn` (livello `PanelLayer` con `Panels`)
- Test: `godot/tests/test_panels.gd`

**Interfaces:**
- Produces:
  - `Menu extends RefCounted`: `Menu.new(items: Array, o := {})`, voci `{label: String | Callable, value: Callable, adjust: Callable, action: Callable, disabled: bool, L: LanternDef}`, `current()`, `update()`, `draw(ci, x, y, o := {})`, `sel`.
  - `PanelsDraw` (statiche): `perk_cards(ci, choices, sel, title, sub) -> Array` (rettangoli), `build_entries() -> Array`, `build_panel(ci, x, y, w, h, hover) -> Array`, `stats_panel(ci, x, y, w, h)`.
  - `Panels` (`Node2D` in `PanelLayer`, `layer = 4`): `static make_options_menu(on_back: Callable) -> Menu`.
  - `play.gd`: `choices`, `sel`, `lock`, `card_rects`, `reroll_rect`, `pause_menu`, `confirm_quit`, `build_sel`, `build_rects`, `map_from`, `opt_menu`; `open_level_up()`, `choose_perk(id)`, `open_pause()`, `update_level_up(dt)`; `tick` gestisce tutte le modalità.

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_panels.gd`:
```gdscript
extends TestCase
# Scelta dei doni, rilancio, pausa, menu e opzioni.

var play: Node

func before() -> void:
	TH.new_run(81)
	play = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)

func after() -> void:
	Controls.sim.clear()
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	Run.reset()

func test_il_dono_si_sceglie_a_stanza_sicura() -> void:
	Run.pending_levels = 1
	for i in 30:
		play.tick(Consts.DT)
	eq(play.mode, "levelup")
	eq(play.choices.size(), 3)
	var id: String = play.choices[0]
	play.lock = 0.0
	Controls.sim = {"pressed": ["confirm"]}
	play.tick(Consts.DT)
	eq(play.mode, "play")
	eq(Run.player.perks.get(id, 0), 1)
	eq(Run.pending_levels, 0)

func test_rilancio() -> void:
	Run.pending_levels = 1
	Run.player.coins = 10
	play.open_level_up()
	play.lock = 0.0
	Controls.sim = {"pressed": ["reroll"]}
	play.tick(Consts.DT)
	eq(Run.player.coins, 5)
	eq(Run.reroll_cost, 8)

func test_pausa_e_abbandono() -> void:
	Controls.sim = {"pressed": ["pause"]}
	play.tick(Consts.DT)
	eq(play.mode, "pause")
	eq(play.pause_menu.items.size(), 5)
	play.pause_menu.sel = 4
	Controls.sim = {"pressed": ["confirm"]}
	play.tick(Consts.DT)
	check(play.confirm_quit, "prima conferma")
	Controls.sim = {"pressed": ["back"]}
	play.tick(Consts.DT)
	eq(play.mode, "play")

func test_menu_salta_le_voci_disabilitate() -> void:
	var m := Menu.new([{"label": "a"}, {"label": "b", "disabled": true}, {"label": "c"}])
	Controls.sim = {"pressed": ["nav_down"]}
	m.update()
	eq(m.sel, 2)

func test_opzioni_volume() -> void:
	var m := Panels.make_options_menu(func(): pass)
	Save.data.settings.music = 0.5
	Controls.sim = {"pressed": ["nav_right"]}
	m.update()
	eq(Save.data.settings.music, 0.6)
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=panels`
Expected: errore, `Menu` non dichiarato.

- [ ] **Step 3: Implementare**

- `godot/ui/menu.gd` (`class_name Menu`) ← `class Menu` (`js/ui.js:211-270`): il mouse con `Controls.mouse_pos()` e `Controls.mouse_left_pressed()`, il movimento confrontando con l'ultima posizione; la fiammella accanto alla voce selezionata con `Fx.time`.
- `godot/ui/panels_draw.gd` (`class_name PanelsDraw`) ← `drawPerkCards`, `buildEntries`, `drawBuildPanel`, `drawStatsPanel` (`js/ui.js:275-362`); i valori numerici delle statistiche con `"%.1f" % v` e `"%.2f/s" % v` come `toFixed`.
- `godot/ui/panels.gd`:
```gdscript
class_name Panels
extends Node2D
# Pannelli sopra il gioco (Scenes.play.draw in js/game.js): doni, pausa,
# equipaggiamento, mappa, opzioni.

@onready var play: Node = get_parent().get_parent()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active:
		return
	match play.mode:
		"levelup": _level_up()
		"pause": _pause(false)
		"build": _pause(true)
		"map": MapDraw.full_map(self)
		"options": _options()
```
con `_level_up`, `_pause` (`drawPause`), `_options` portati da `js/game.js:421-462`; `play.card_rects`, `play.reroll_rect`, `play.build_rects` si aggiornano qui come nel JS. In fondo al file:
```gdscript
# opzioni condivise da pausa e titolo (makeOptionsMenu in js/game.js)
static func make_options_menu(on_back: Callable) -> Menu:
```
che porta `makeOptionsMenu` (`js/game.js:487-503`); «Schermo intero» alterna `DisplayServer.window_set_mode` tra `WINDOW_MODE_FULLSCREEN` e `WINDOW_MODE_WINDOWED`; dopo ogni cambio di volume `Sfx.apply_volumes()` e `Save.write()`.
- In `godot/scenes/play.gd` portare `openLevelUp`, `choosePerk`, `openPause`, `update` (tutte le modalità), `updatePlay` (righe della pausa, della mappa, della vittoria e dei livelli in sospeso) e `updateLevelUp` (`js/game.js:268-384`); `Input.hit('Digit' + (i + 1))` → `Controls.digit(i + 1)`; `performance.now() - Input.mouseMovedAt < 100` → `Time.get_ticks_msec() - Controls.mouse_moved_at < 100`; l'abbandono imposta `Run.player.last_hit = "La resa"`, `Run.abandoned = true` e va a `gameover` (la scena arriva nel Task 25). In `_dev_sim`, dopo la simulazione: `if Game.dev.has("pause"): open_pause()` e `if Game.dev.has("map"): mode = "map"; map_from = "play"`.
- In `godot/scenes/play.tscn`:
```
[ext_resource type="Script" path="res://ui/panels.gd" id="8"]

[node name="PanelLayer" type="CanvasLayer" parent="."]
layer = 4

[node name="Panels" type="Node2D" parent="PanelLayer"]
script = ExtResource("8")
```

- [ ] **Step 4: Eseguire i test**

Run: `tools/test.sh`
Expected: tutti superati.

- [ ] **Step 5: Verifica visiva**

Run: `godot --path godot -- --seed=7 --lv=2 --coins=40` (la scelta dei doni si apre subito nella stanza iniziale), poi `-- --seed=7 --pause` e `-- --seed=7 --map`. Confrontare carte (bordo del colore della rarità, pallini dei livelli), rilancio con il tasto R, pausa con equipaggiamento e statistiche, mappa completa con legenda, opzioni.

- [ ] **Step 6: Commit**

```bash
git add godot/ui godot/scenes godot/tests/test_panels.gd
git commit -m "Pannelli: doni con rilancio, pausa, equipaggiamento, mappa, opzioni

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 25: Schermate, sblocchi, fine della demo, pausa automatica, barra degli errori

**Files:**
- Create: `godot/ui/well_bg.gd`
- Create: `godot/ui/screens/{title,options,select,records,help,gameover,demo_end}.tscn` e `.gd`
- Modify: `godot/autoload/game.gd` (`SCENES` completo, `boot` verso il titolo, `--scene`, pausa automatica, schermo intero con F11 e Alt+Invio, barra degli errori)
- Modify: `godot/ui/panels_draw.gd` (aggiunge `summary_rows`, `summary`, `icons_row`)
- Modify: `godot/world/flow.gd` (la discesa porta alla fine della demo)
- Test: `godot/tests/test_screens.gd`

**Interfaces:**
- Produces:
  - `WellBg` (statiche): `draw(ci, t, embers)`, `update_embers(arr, dt)`, `big_lantern(ci, x, y, glass, swing, s := 3.0)`, `static var embers: Array` (condivise tra le schermate come `Scenes.title.embers`).
  - Schermate (`Node2D` con script; `_physics_process` aggiorna, `_draw` disegna): `title`, `options`, `select`, `records`, `help`, `gameover`, `demo_end`; ognuna espone `menu` (dove c'è) e `t`.
  - `Game.SCENES` con `title`, `options`, `select`, `records`, `help`, `play`, `gameover`, `demo_end`; `static Game.should_autopause(scene_name, mode, dead, victory_t) -> bool`.
  - `Flow.update_trans`: per `kind == "descend"` va a `Game.set_scene("demo_end")` (la slice finisce dopo il primo guardiano).

- [ ] **Step 1: Scrivere i test**

`godot/tests/test_screens.gd`:
```gdscript
extends TestCase
# Schermate, sblocchi, fine della demo, pausa automatica.

func after() -> void:
	Run.reset()

func test_autopause_only_in_active_play() -> void:
	check(Game.should_autopause("play", "play", false, 0.0))
	check(not Game.should_autopause("play", "pause", false, 0.0))
	check(not Game.should_autopause("play", "levelup", false, 0.0))
	check(not Game.should_autopause("play", "play", true, 0.0), "morto")
	check(not Game.should_autopause("play", "play", false, 1.0), "vittoria in corso")
	check(not Game.should_autopause("title", "play", false, 0.0))

func test_tutte_le_scene_esistono() -> void:
	for k in Game.SCENES:
		check(ResourceLoader.exists(Game.SCENES[k]), k)

func test_argomenti_di_sviluppo() -> void:
	eq(Game.parse_args(PackedStringArray(["--test=boss", "--fire", "x", "--seed=4"])), {"test": "boss", "fire": true, "seed": "4"})

func test_scelta_della_lanterna_rispetta_gli_sblocchi() -> void:
	Save.data.unlocks.lanterns = ["custode"]
	var sc: Node = load(Game.SCENES.select).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sc)
	eq(sc.menu.items.size(), 6, "5 lanterne + Indietro (Ardore non ancora sbloccato)")
	check(not sc.menu.items[0].get("disabled", false))
	check(sc.menu.items[1].disabled)
	eq(sc.menu.items[1].label, "Lanterna sigillata")
	sc.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame

func test_il_guardiano_sblocca_il_pellegrino() -> void:
	Save.data.unlocks.lanterns = ["custode"]
	Save.data.stats.bossKills = 1
	TH.new_run(91)
	Flow.check_unlocks()
	check(Save.data.unlocks.lanterns.has("pellegrino"))
	check(Run.new_unlocks.has("Lanterna del Pellegrino"))

func test_fine_della_demo_registra_le_uccisioni() -> void:
	TH.new_run(92)
	Run.kills = 7
	var k0: int = Save.data.stats.kills
	var sc: Node = load(Game.SCENES.demo_end).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sc)
	eq(Save.data.stats.kills, k0 + 7)
	sc.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
```

- [ ] **Step 2: Eseguire e verificare che fallisca**

Run: `tools/test.sh --only=screens`
Expected: errore, `should_autopause` non trovato.

- [ ] **Step 3: Sfondo del pozzo e schermate**

- `godot/ui/well_bg.gd` (`class_name WellBg`) ← `drawWellBackground`, `updateEmbers` (`js/game.js:508-534`) e `drawBigLantern` (`js/ui.js:365-381`). Il gradiente verticale di sfondo con tre `draw_rect` sfumati non serve: usare una `GradientTexture2D` lineare (`#0a0710` → `#120c18` a 0,6 → `#1e1018`) disegnata a tutto schermo; il bagliore in basso con `UiDraw.glow`; la lanterna ruotata con `draw_set_transform(Vector2(x, y), swing)`.
- Una scena per schermata, con radice `Node2D` e lo script omonimo; struttura comune:
```gdscript
extends Node2D
# Titolo (Scenes.title in js/game.js).

var t := 0.0
var menu: Menu

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# ... enter() del JS

func _physics_process(dt: float) -> void:
	t += dt
	WellBg.update_embers(WellBg.embers, dt)
	menu.update()
	Controls.end_tick()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	WellBg.draw(self, t, WellBg.embers)
	# ... draw() del JS
```
  Portare da `js/game.js`: `title.gd` ← `Scenes.title` (536-563; `Music.play("title")`, `Run.reset()` al posto di `run = null`, la riga «Premi un tasto per attivare l'audio» non serve in Godot); `options.gd` ← `Scenes.options` (565-574); `select.gd` ← `Scenes.select` (579-618; `startRun` → `Flow.start_run(L.id, ard)` seguito da `Game.set_scene("play")`; testi di Ardore da `Lore.ARDORE`); `records.gd` ← `Scenes.records` (623-649); `help.gd` ← `Scenes.help` (651-703, icone degli stati da `Statuses.ALL`); `gameover.gd` ← `Scenes.gameover` (731-762). `runSummaryRows`, `drawSummary`, `drawIconsRow` (708-729) vanno in `PanelsDraw` come `summary_rows()`, `summary(ci, x, y)`, `icons_row(ci, x, y, max_w)`, perché li usano sia il game over sia la fine della demo.
  `demo_end.gd` è nuova e segue la struttura di `Scenes.victory` (764-808) senza il ramo dell'Abisso Infinito:
  - all'ingresso: `Save.data.stats.kills += Run.kills`, `Save.write()`, `Flow.check_unlocks()`, `Music.play("title")`; menu `Nuova discesa` → `select`, `Menu principale` → `title`;
  - disegno: sfondo del pozzo, bagliore caldo e lanterna grande come la vittoria; titolo «Fine della demo» (scala 2, `#f6cf57`), sottotitolo «Il Custode delle Ossa è caduto. Le altre profondità arriveranno presto.» (`#c8c0d0`); i due pannelli con riepilogo e icone; «Sbloccato: ...» se `Run.new_unlocks` non è vuoto; menu a `y = 210`.
- Le scene `.tscn` hanno tutte questa forma (cambiano nome e script):
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/screens/title.gd" id="1"]

[node name="Title" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 4: `Game` e `Flow`**

In `godot/autoload/game.gd`:
```gdscript
var SCENES := {
	"title": "res://ui/screens/title.tscn",
	"options": "res://ui/screens/options.tscn",
	"select": "res://ui/screens/select.tscn",
	"records": "res://ui/screens/records.tscn",
	"help": "res://ui/screens/help.tscn",
	"play": "res://scenes/play.tscn",
	"gameover": "res://ui/screens/gameover.tscn",
	"demo_end": "res://ui/screens/demo_end.tscn",
}

static func should_autopause(scene: String, mode: String, dead: bool, victory_t: float) -> bool:
	return scene == "play" and mode == "play" and not dead and victory_t == 0.0

func boot() -> void:
	if dev.has("test") or dev.has("spawn") or dev.has("seed"):
		dev_start()
	elif dev.has("scene"):
		set_scene(str(dev.scene))
	else:
		set_scene("title")
```
Inoltre:
- in `_ready`: `get_window().focus_exited.connect(_on_focus_lost)` con
```gdscript
func _on_focus_lost() -> void:
	var sc := get_tree().current_scene
	if sc != null and Run.active and should_autopause(scene_name, sc.get("mode"), Run.player.dead, Run.victory_t):
		sc.open_pause()
```
- `_input(event)`: F11 o Alt+Invio alternano lo schermo intero (come `desktop/main.js`).
- una barra degli errori sempre visibile: un `CanvasLayer` (`layer = 100`) creato in `_ready` con un `Node2D` che, se `error != ""`, disegna come `frame()` del JS (`js/game.js:837-842`) un rettangolo `#300810` alto 32 px in basso, `"Errore: " + error` troncato a 70 caratteri in `#ff8080` e la riga «Fai uno screenshot e invialo insieme al modulo di feedback. » + `Consts.VERSION` + (`"  seme " + str(Run.seed)` se la run è attiva) in `#e8c0c0`.

In `godot/world/flow.gd`, `update_trans`: per `kind == "descend"`, al posto di `Run.depth += 1` / `new_floor()`, `Game.set_scene("demo_end")`.

- [ ] **Step 5: Eseguire i test**

Run: `tools/test.sh`
Expected: tutti superati.

- [ ] **Step 6: Verifica visiva e flusso completo**

Run: `godot --path godot` e percorrere: titolo → Come si gioca (3 pagine) → Archivio → Opzioni (volumi, scossa, numeri, schermo intero) → Nuova discesa → scelta della lanterna (sigillate con testo di sblocco) → partita. Screenshot di confronto: `godot --path godot -- --scene=title --screenshot=/tmp/ul_title.png --shot-after=60` contro il titolo del JS.

- [ ] **Step 7: Commit**

```bash
git add godot/ui godot/autoload/game.gd godot/world/flow.gd godot/tests/test_screens.gd
git commit -m "Schermate, sblocchi, fine della demo, pausa automatica e barra degli errori

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 26: Verifica finale

**Files:**
- Create: `docs/superpowers/playtest-godot-slice.md`
- Modify: `README.md` (sezione sulla versione Godot)
- Modify: `docs/superpowers/specs/2026-10-11-godot-port-vertical-slice-design.md` (stato)

- [ ] **Step 1: Tutti i test, da zero**

Run:
```bash
rm -rf godot/.godot
node tools/golden/gen.js && git diff --stat godot/tests/golden
tools/test.sh
```
Expected: i golden rigenerati non cambiano (`git diff` vuoto); tutti i test superati, codice di uscita 0.

- [ ] **Step 2: Screenshot affiancati**

Per ognuna delle situazioni seguenti, uno screenshot Godot (`--screenshot`) e lo stesso stato nel JS (browser, parametri `?test=` equivalenti), osservati fianco a fianco: stanza iniziale, combattimento (`--test=fight --sim=240 --fire`), mercante, tesoro, santuario, stanza segreta, boss in fase 1 e in fase 2, scelta dei doni, pausa, mappa, game over, titolo. Annotare ogni differenza visibile; correggere quelle che non sono tra le perdite accettate dalla specifica (§4.2 tile non identici pixel per pixel, §4.5 tempo della musica).

- [ ] **Step 3: Checklist di playtest**

Creare `docs/superpowers/playtest-godot-slice.md`:
```markdown
# Playtest della vertical slice Godot

Da eseguire affiancando la versione JS (`index.html`). Segnare ogni voce con ✅ o con la differenza trovata.

## Controlli
- [ ] WASD, mira col mouse, sparo tenendo premuto il tasto sinistro
- [ ] Frecce per mirare e sparare
- [ ] Spazio e Shift per lo scatto; cariche di scatto sotto i piedi
- [ ] Vampata con tasto destro e F; «Olio insufficiente»
- [ ] Consumabili 1–4; E per interagire; Tab/M mappa; Esc/P pausa
- [ ] Gamepad: stick, A, B, X, Y, LB, RB, RT, croce, Start, Back
- [ ] Passaggio mouse ↔ gamepad a metà partita (mira e icone dei tasti)

## Sensazione
- [ ] Velocità di movimento e scatto identiche
- [ ] Cadenza, velocità e gittata dei proiettili identiche
- [ ] Scivolamento sugli spigoli delle porte
- [ ] Hitstop, scossa, flash ai colpi subiti e ai critici

## Luce e olio
- [ ] Raggio della luce che si restringe con l'olio
- [ ] Buio più fitto senza olio in combattimento, scritta BUIO
- [ ] Stanze ripulite più chiare
- [ ] Bracieri, monete e proiettili che illuminano; occhi rossi nel buio

## Stanze e contenuti
- [ ] Stanza iniziale con tutorial a terra
- [ ] Stanze normali a una o due ondate, porte che si chiudono e riaprono
- [ ] Tesoro: due reliquie, se ne prende una sola
- [ ] Mercante: prezzi, battute, acquisti, «Borsa piena», «Sei già in forze»
- [ ] Santuari: sangue, fortuna, fonte, idolo
- [ ] Stanza segreta aperta con una bomba (crepe sul muro)
- [ ] Rocce incrinate, barili che esplodono, urne, spuntoni
- [ ] Ratto, pipistrello, scheletro, teschio, ghoul; campioni d'élite con contorno colorato

## Progressione
- [ ] Livelli: scelta dei doni a stanza sicura, rilancio con R
- [ ] Doni, reliquie e maledizioni applicati (pannello statistiche in pausa)
- [ ] Il Custode delle Ossa: due fasi, pattern, morte, botola
- [ ] Fine della demo con riepilogo
- [ ] Sblocco della Lanterna del Pellegrino dopo il guardiano
- [ ] Morte, game over con «Ucciso da», abbandono dalla pausa

## Salvataggio e opzioni
- [ ] Volumi di musica ed effetti, scossa, numeri del danno, schermo intero (anche F11 e Alt+Invio)
- [ ] Archivio aggiornato tra una sessione e l'altra (chiudere e riaprire)
- [ ] Pausa automatica quando la finestra perde il fuoco

## Audio
- [ ] Musica del titolo e delle Cripte, intensità che cresce in combattimento e al boss
- [ ] Tutti gli effetti sonori presenti e riconoscibili
```
Eseguire la checklist e committare il file compilato.

- [ ] **Step 4: README e stato della specifica**

In `README.md`, dopo «Come avviarlo», aggiungere:
```markdown
## Versione Godot (in sviluppo)

In `godot/` c'è il porting in Godot 4.7. Per ora contiene la prima profondità completa, fino al guardiano.

    godot --path godot

Test: `tools/test.sh`. Argomenti di sviluppo dopo `--`, ad esempio `godot --path godot -- --test=boss --seed=7`.
Gli asset in `godot/assets/` sono stati esportati una volta dal codice JS con `tools/export_assets/` e ora si modificano direttamente.
```
Nella specifica, `Stato: in revisione` diventa `Stato: implementata (vertical slice)`.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/superpowers
git commit -m "Verifica finale della vertical slice Godot

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
