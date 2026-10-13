# Porting conventions (JS → GDScript)

The JavaScript code in `js/` is the **source of truth** for gameplay behavior. When porting a piece of it to Godot, the GDScript must do exactly what the JS does, following the rules below. Anything new (Godot architecture, tests, tools) is free to be idiomatic.

## Translation rules

| JS | GDScript |
|---|---|
| `Math.random()` | `U.random()` |
| `rnd(a)`, `rnd(a, b)`, `rndi`, `pick`, `chance`, `shuffle`, `weightedPick` | `U.rnd`, `U.rndi`, `U.pick`, `U.chance`, `U.shuffle`, `U.weighted_pick` |
| `Math.round(v)` | `U.jround(v)` (Godot's `round()` takes -2.5 to -3, the JS takes it to -2) |
| `Math.floor/ceil(v)` used as an index | `int(floor(v))` / `int(ceil(v))` |
| `x \| 0` | `int(x)` (truncation toward zero) |
| `Math.hypot(a, b)` | `sqrt(a * a + b * b)` |
| `Math.min/max` | `minf/maxf` (float), `mini/maxi` (int) |
| `a % b` on floats | `fmod(a, b)` (same sign as the JS) |
| `o.k \|\| d` on optional fields | `o.get("k", d)`; never rely on the "truthiness" of `0`, `""`, `null`: write the comparison explicitly |
| `arr.filter(f)` / `some` / `every` | `arr.filter(f)` / `arr.any(f)` / `arr.all(f)` |
| `push`, `shift`, `splice(i, 1)` | `append`, `pop_front`, `remove_at(i)` |
| `new Set()` | `Dictionary` used as a set (`s[k] = true`, `s.has(k)`): keeps insertion order like the JS |
| `Object.keys(T)` of a data table | `T.keys()` (same insertion order: **never reorder the tables**) |
| `for (const k in o)` with `delete o[k]` inside | `for k in o.keys():` (copy of the keys) |
| `arr.sort((a, b) => ...)` | `sort_custom`, which is **not stable**: if the JS depends on the order of ties, add the original index as a tiebreaker |
| colors `'#rrggbb'` | `Color("#rrggbb")` |
| colors `'rgba(r,g,b,a)'` | `U.rgba(r, g, b, a)` |
| `ctx.save(); ctx.globalAlpha = a; ...; ctx.restore()` | `var ga := UiDraw.alpha; UiDraw.alpha = a; ...; UiDraw.alpha = ga` (if the JS uses `*=`, use `*=`) |
| `setTimeout(fn, ms)` | `U.later(ms / 1000.0, fn)` |
| `Render.time` | `Fx.time` |
| `rnd`, `Math.random` inside drawing functions (`draw*`) | `Fx.vrnd(a, b)` or `Fx.vis.next()`: drawing must not consume game randomness |
| `switch (x) { case 'a': ...; break; }` | `match x: "a": ...` (no fall-through) |
| out-of-bounds array access (gives `undefined` in JS) | check the bounds first: in GDScript it is an error |
| `for (const x of arr)` over an array the loop body appends to (`run.fx`, `run.bullets`, `run.enemies`) | loop by index with the size recomputed (`var i := 0` / `while i < arr.size()`): as in the JS, elements added during the loop are visited in the same tick |
| `a === b` between JS objects (rooms, fx, pickups) | `is_same(a, b)`: in GDScript `==` between `Dictionary` or `Array` compares the **contents**; the same goes for `Array.has`, `erase`, `find` |
| logical coordinates and values | separate `float`s (`x`, `y`): `Vector2` is 32-bit and loses precision; use it only for exact values (tile centers) or for drawing |

## Rendering

The game draws in a 480x270 coordinate space, but the window renders at its own resolution (`window/stretch/mode="canvas_items"`). Pixel art stays blocky because `UiDraw` and `Spr` draw on whole logical pixels with nearest filtering; shaders, smooth textures (`UiDraw.glow`) and arcs get the full screen resolution. Keep game drawing on whole logical pixels; use the extra resolution only for light and effects.

## Name map

| JS | GDScript |
|---|---|
| `new RNG(s)`, `rng.range`, `rng.int` | `RNG.new(s)`, `rng.frange`, `rng.rint` |
| `run` | autoload `Run` (`Run.active` replaces `run !== null`) |
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
