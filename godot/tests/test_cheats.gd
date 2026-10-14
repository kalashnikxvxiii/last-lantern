extends TestCase
# Developer cheats: toggles, actions and the panel in the game scene.

var play: Node

func before() -> void:
	TH.new_run(31)
	Cheats.reset()
	play = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)

func after() -> void:
	Cheats.reset()
	Controls.sim.clear()
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	Run.reset()

func test_god_mode_blocks_damage() -> void:
	var p := Run.player
	Cheats.god = true
	check(not Combat.hurt_player(50, "test"), "no hit")
	eq(p.hp, p.stats.maxHp)
	Cheats.god = false
	check(Combat.hurt_player(5, "test"), "hit")

func test_one_shot_kills() -> void:
	TH.arena()
	var e := TH.spawn("ghoul", 200, 120)
	Cheats.one_shot = true
	Combat.hit_enemy(e, 0.1)
	check(e.dead, "dead")

func test_infinite_oil_and_freeze() -> void:
	TH.arena()
	var e := TH.spawn("rat", 200, 120)
	Run.player.oil = 1.0
	Cheats.inf_oil = true
	Cheats.freeze = true
	Fx.hitstop_t = 0.0
	play.tick(Consts.DT)   # frozen from the end of the first tick
	var x := e.x
	for i in 30:
		play.tick(Consts.DT)
	eq(Run.player.oil, Run.player.stats.maxOil)
	eq(e.x, x)

func test_noclip_walks_through_walls() -> void:
	var p := Run.player
	Cheats.noclip = true
	p.y = RoomU.tile_center(14, 3).y   # away from the west door
	Controls.sim = {"move": Vector2(-1, 0)}
	for i in 240:
		play.tick(Consts.DT)
	near(p.x, Consts.RX + p.r, 0.01)

func test_kill_all_and_clear_room() -> void:
	var r := TH.arena()
	r.waves = [[{"type": "rat", "mod": null}]]
	r.waveIdx = 0
	TH.spawn("rat", 200, 120)
	TH.spawn("bat", 220, 120)
	Cheats.clear_room()
	TH.ticks(2)
	check(r.cleared, "cleared")
	eq(Run.enemies.size(), 0)

func test_build_cheats() -> void:
	var p := Run.player
	check(Cheats.add_perk("dmg"), "perk")
	eq(p.perks.dmg, 1)
	check(Cheats.remove_perk("dmg"), "removed")
	check(not p.perks.has("dmg"), "gone")
	Cheats.toggle_relic("r_skull")
	check(p.relics.has("r_skull") and p.curses.has("c_frail"), "relic with its curse")
	Cheats.toggle_relic("r_skull")
	check(not p.relics.has("r_skull"), "relic removed")
	check(Cheats.give_cons("bomb"), "bomb")
	Cheats.clear_build()
	eq(p.curses.size(), 0)

func test_spawn_and_travel() -> void:
	Cheats.spawn_enemy("skull", "swift")
	for i in 60:
		Effects.update(Consts.DT)
	eq(Run.enemies.size(), 1)
	eq(Run.enemies[0].mod, "swift")
	check(Cheats.goto_room("shop"), "shop")
	eq(Run.room.type, "shop")
	Cheats.goto_depth(3)
	eq(Run.depth, 3)
	check(Cheats.boss_ids().size() == 5, "five wardens")
	check(Cheats.enemy_ids().has("rat"), "enemy list")

func test_level_up_opens_the_perk_choice() -> void:
	Run.room.combat = false
	Cheats.level_up()
	play.tick(Consts.DT)
	eq(play.mode, "levelup")

func test_panel_opens_navigates_and_closes() -> void:
	Controls.sim = {"pressed": ["cheats"]}
	play.tick(Consts.DT)
	eq(play.mode, "cheats")
	Controls.sim = {"pressed": ["confirm"]}   # Player
	play.tick(Consts.DT)
	eq(play.cheat_page, "Player")
	Controls.sim = {"pressed": ["confirm"]}   # God mode
	play.tick(Consts.DT)
	check(Cheats.god, "god on")
	Controls.sim = {"pressed": ["back"]}
	play.tick(Consts.DT)
	eq(play.cheat_page, "main")
	eq(play.cheat_menu.sel, 0)
	Controls.sim = {"pressed": ["cheats"]}
	play.tick(Consts.DT)
	eq(play.mode, "play")

func test_game_speed() -> void:
	Cheats.speed_i = 4
	var t := Run.time
	play._physics_process(0.0)
	near(Run.time - t, Consts.DT * 4, 1e-6)
	Cheats.speed_i = 0
	t = Run.time
	play._physics_process(0.0)
	near(Run.time - t, Consts.DT * 0.25, 1e-6)

# the "Dev" export presets turn the cheats on through the "cheats" feature tag
func test_dev_presets_enable_cheats() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK)
	var names := {}
	for s in cfg.get_sections():
		if s.ends_with(".options"):
			continue
		var name: String = cfg.get_value(s, "name")
		var features: String = cfg.get_value(s, "custom_features", "")
		names[name] = true
		eq("cheats" in features.split(","), name.ends_with(" Dev"), name)
	for p in ["Windows Desktop", "Linux"]:
		check(names.has(p), p)
		check(names.has(p + " Dev"), p + " Dev")

func test_a_new_run_starts_without_cheats() -> void:
	Cheats.god = true
	Cheats.noclip = true
	Cheats.speed_i = 4
	TH.new_run(32)
	check(not Cheats.any_active(), "the toggles do not carry into the next run")

func test_a_cheated_run_records_no_stats() -> void:
	check(not Run.cheated)
	Cheats.god = true
	play.tick(Consts.DT)
	check(Run.cheated, "a toggle marks the run")
	var kills: int = Save.data.stats.kills
	Run.kills = 5
	var sc: Node = load(Game.SCENES.gameover).instantiate()
	sc.enter()
	sc.free()
	eq(Save.data.stats.kills, kills, "the kills of a cheated run are not counted")
	check(RunSave.save(0))
	Run.cheated = false
	check(RunSave.resume(0))
	check(Run.cheated, "a resumed slot is still cheated")
	RunSave.erase(0)
	TH.new_run(33)
	check(not Run.cheated, "a new run starts clean")
