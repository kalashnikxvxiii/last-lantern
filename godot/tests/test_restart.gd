extends TestCase
# Godot-only restart: holding R for 2 seconds flares the lantern, which
# turns the enemies it reaches into ash piles (frozen, harmless), floods the
# screen and starts the descent over on a new seed with the same lantern
# and Ardor.

var sc: Node = null
var stats: Dictionary

func before() -> void:
	stats = Save.data.stats.duplicate(true)
	Controls.sim.clear()
	Fx.hitstop_t = 0.0

func after() -> void:
	Controls.sim.clear()
	Fx.hitstop_t = 0.0
	if sc != null and is_instance_valid(sc):
		sc.queue_free()
		sc = null
		await (Engine.get_main_loop() as SceneTree).process_frame
	RunSave.erase(0)
	Save.data.stats = stats
	Run.reset()

func _play() -> void:
	sc = load(Game.SCENES.play).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sc)

func _ticks(n: int) -> void:
	for i in n:
		sc.tick(Consts.DT)
		Controls.end_tick()

func test_the_hold_builds_up_and_starts_the_flare() -> void:
	TH.new_run(7)
	var old_seed := Run.seed
	_play()
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(119)
	check(Run.restart_t > 0.0, "holding R builds the timer")
	check(Run.restart_flare < 0.0, "still short of 2 s: no flare")
	eq(Run.seed, old_seed, "the run is still the old one")
	_ticks(2)   # the float sum of 120 ticks can land a hair below 2 s
	check(Run.restart_flare >= 0.0, "2 s of hold: the lantern flares up")
	var t0 := Run.time
	_ticks(10)
	check(Run.time > t0, "the world still runs under the light")

func test_releasing_cancels_the_hold() -> void:
	TH.new_run(7)
	_play()
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(60)
	check(Run.restart_t > 0.0)
	Controls.sim = {"device": "kb"}
	_ticks(1)
	near(Run.restart_t, 0.0, 1e-9, "released: back to zero")

func test_pause_cancels_the_hold() -> void:
	TH.new_run(7)
	_play()
	var e := TH.spawn("ghoul", 300, 120)
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(60)
	check(e.dusted, "the light turned the ghoul to dust")
	sc.open_pause()
	_ticks(5)
	near(Run.restart_t, 0.0, 1e-9, "the pause drops the hold")
	check(not e.dusted, "and the pause brings the ghoul back")
	near(e.dust_t, 0.0, 1e-9, "with no ash left over")

func test_hitstop_freezes_the_hold() -> void:
	TH.new_run(7)
	_play()
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(60)
	var t0: float = Run.restart_t
	Fx.hitstop_t = 0.2
	_ticks(10)
	near(Run.restart_t, t0, 1e-9, "the game is frozen: so is the hold")

func test_death_cancels_the_hold() -> void:
	TH.new_run(7)
	_play()
	var e := TH.spawn("ghoul", 300, 120)
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(60)
	check(e.dusted, "the light turned the ghoul to dust")
	Run.player.dead = true
	_ticks(1)
	near(Run.restart_t, 0.0, 1e-9, "no restart out of the grave")
	check(not e.dusted, "death brings the ghoul back")
	near(e.dust_t, 0.0, 1e-9, "with no ash left over")

func test_the_light_dusts_enemies_without_hurting_them() -> void:
	TH.new_run(7)
	_play()
	var e := TH.spawn("ghoul", 300, 120)
	var kills0 := Run.kills
	var n0 := Run.enemies.size()
	var hp0 := e.hp
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(75)   # the longer hold slows the light down the same way
	check(Run.restart_flare < 0.0, "still holding, no flare yet")
	check(e.dusted, "the light turned the ghoul to dust")
	near(e.dust_t, 1.0, 1e-9, "burned all the way down to ash")
	eq(Run.kills, kills0, "no kill counted")
	eq(Run.enemies.size(), n0, "nobody disappeared")
	near(e.hp, hp0, 1e-9, "nobody was hurt")
	Controls.sim = {"device": "kb"}
	_ticks(2)
	check(not e.dusted, "released: the ghoul comes back")
	check(e.dust_t > 0.4 and e.dust_t < 1.0, "and the body reassembles over time")

func test_the_ash_freezes_on_impact() -> void:
	TH.new_run(7)
	_play()
	var e := TH.spawn("ghoul", 270, 130)
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	var guard := 0
	while not e.dusted and guard < 60:
		_ticks(1)
		guard += 1
	check(e.dusted, "the light reached the ghoul")
	check(e.dust_t > 0.0 and e.dust_t < 1.0, "burning, but not ash yet")
	var x0 := e.x
	var y0 := e.y
	_ticks(10)
	near(e.x, x0, 1e-6, "the burning ghoul does not walk")
	near(e.y, y0, 1e-6, "the burning ghoul does not walk")

func test_the_ash_statue_stands_still() -> void:
	TH.new_run(7)
	_play()
	var e := TH.spawn("ghoul", 270, 130)   # near the center: dusted early
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(70)   # hold budget: never reach 120 ticks, the flare would restart the scene
	check(e.dusted and e.dust_t >= 1.0, "burned all the way down to a statue")
	_ticks(2)
	var x0 := e.x
	var y0 := e.y
	_ticks(10)
	near(e.x, x0, 1e-6, "the ash does not walk")
	near(e.y, y0, 1e-6, "the ash does not walk")
	Controls.sim = {"device": "kb"}
	_ticks(20)
	check(e.dust_t < 1.0, "the light left: the body reassembles")
	var x1 := e.x
	var y1 := e.y
	_ticks(30)
	check(e.x != x1 or e.y != y1, "and the ghoul walks again")

func test_death_during_the_flare_cancels_it() -> void:
	TH.new_run(7)
	_play()
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(121)
	check(Run.restart_flare >= 0.0, "the lantern flares up")
	Run.player.dead = true
	_ticks(1)
	near(Run.restart_flare, -1.0, 1e-9, "death under the light cancels the restart")
	near(Run.restart_t, 0.0, 1e-9)

func test_the_hold_roots_the_player() -> void:
	TH.new_run(7)
	_play()
	var p := Run.player
	Controls.sim = {"held": ["reroll"], "move": Vector2(1, 0), "device": "kb"}
	var x0 := p.x
	var y0 := p.y
	_ticks(30)
	near(p.x, x0, 1e-6, "holding R: the player does not walk")
	near(p.y, y0, 1e-6)
	check(Run.restart_t > 0.0, "the hold builds up all the same")
	Controls.sim = {"move": Vector2(1, 0), "device": "kb"}
	_ticks(5)
	check(p.x != x0, "released: the player walks again")
	near(Run.restart_t, 0.0, 1e-9)

func test_the_hold_roots_the_dash() -> void:
	TH.new_run(7)
	_play()
	var p := Run.player
	Controls.sim = {"move": Vector2(1, 0), "device": "kb"}
	Controls.sim.pressed = ["dash"]
	_ticks(1)
	check(p.dash_t > 0.0, "the dash is under way")
	var x0 := p.x
	Controls.sim = {"held": ["reroll"], "move": Vector2(1, 0), "device": "kb"}
	_ticks(3)
	near(p.dash_t, 0.0, 1e-9, "the hold cuts the dash short")
	near(p.x, x0, 1e-6, "and the player stays put")

func test_the_hold_blocks_fire_and_flare() -> void:
	TH.new_run(7)
	_play()
	var p := Run.player
	Controls.sim = {"held": ["reroll"], "fire": true, "device": "mouse", "mouse": Vector2(p.x + 40, p.y)}
	_ticks(30)
	eq(Run.bullets.size(), 0, "holding R: no shots")
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	Controls.sim.pressed = ["flare"]
	_ticks(1)
	eq(Run.player.flare_cd, 0.0, "holding R: no flare")
	eq(Run.bullets.size(), 0)

func test_the_hold_roots_against_a_pull() -> void:
	TH.new_run(7)
	_play()
	var p := Run.player
	Run.pull = Vector2(120, 0)
	var x0 := p.x
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(10)
	near(p.x, x0, 1e-6, "rooted: the suction does not drag the player")
	Run.pull = null

func test_the_light_ashes_the_enemy_bullets() -> void:
	TH.new_run(7)
	_play()
	var p := Run.player
	Run.ebullets.append({"x": p.x + 30, "y": p.y - 1, "vx": -300.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0,
		"kind": "orb", "col": "violet", "t": 0.0, "src": "rat", "accel": 0.0, "curve": 0.0})
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(20)
	eq(Run.ebullets.size(), 0, "the light ashes the bullet in its reach")
	check(not p.dead, "and the player takes no hit")

func test_the_light_ashes_bullets_only_within_its_reach() -> void:
	TH.new_run(7)
	_play()
	var p := Run.player
	Run.ebullets.append({"x": Consts.RX + 24.0, "y": Consts.RY + 24.0, "vx": 0.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0,
		"kind": "orb", "col": "violet", "t": 0.0, "src": "rat", "accel": 0.0, "curve": 0.0})
	Controls.sim = {"held": ["reroll"], "device": "kb"}
	_ticks(5)
	eq(Run.ebullets.size(), 1, "far from the light: the bullet survives")

func test_restart_run_starts_over_on_a_new_seed() -> void:
	TH.new_run(7)
	Run.ardor = 2
	Run.kills = 5
	var old_seed := Run.seed
	var k0: int = Save.data.stats.kills
	Flow.restart_run()
	check(Run.seed != old_seed, "a new seed")
	eq(Run.player.lantern, "warden", "the same lantern")
	eq(Run.ardor, 2, "the same Ardor")
	eq(Save.data.stats.kills, k0 + 5, "the kills of the abandoned descent count")
	eq(Run.kills, 0, "the new run starts clean")

func test_the_hold_does_not_root_outside_the_restart() -> void:
	TH.new_run(7)
	_play()
	var p := Run.player
	Run.victory_t = 5.0   # the restart timer is off: R means nothing here
	Controls.sim = {"held": ["reroll"], "move": Vector2(1, 0), "fire": true, "device": "mouse", "mouse": Vector2(p.x + 40, p.y)}
	var x0 := p.x
	_ticks(5)
	check(p.x != x0, "R outside the restart: the player still walks")
	check(Run.bullets.size() > 0, "and still shoots")
	near(Run.restart_t, 0.0, 1e-9)

func test_restart_run_keeps_the_character() -> void:
	U.seed_random(7)
	Flow.start_run("warden", 0, 7, "goblin")
	eq(Run.player.character, "goblin", "the run starts as the goblin")
	Flow.restart_run()
	eq(Run.player.character, "goblin", "the same character starts over")

func test_a_cheated_run_counts_no_kills() -> void:
	TH.new_run(7)
	Run.cheated = true
	Run.kills = 5
	var k0: int = Save.data.stats.kills
	Flow.restart_run()
	eq(Save.data.stats.kills, k0, "a cheated descent records nothing")

func test_the_new_run_keeps_the_slot() -> void:
	TH.new_run(7)
	Run.slot = 0
	check(RunSave.save(0), "the descent is saved")
	var old_seed := Run.seed
	Flow.restart_run()
	eq(Run.slot, 0, "same slot")
	var d := RunSave.read(0)
	check(not d.is_empty(), "the slot holds the new run")
	check(d.run.seed != old_seed, "and it is the new seed, not the abandoned one")
	eq(d.run.seed, Run.seed)
