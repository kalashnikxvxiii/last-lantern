extends TestCase
# Run start, entering rooms, doors and transitions, player movement.

func before() -> void:
	TH.new_run(7)

func after() -> void:
	Controls.sim.clear()
	Run.reset()

func test_run_start() -> void:
	var p := Run.player
	eq(p.hp, p.stats.maxHp)
	eq(p.oil, p.stats.maxOil)
	eq(p.cons[0], {"id": "potion", "n": 1})
	eq(p.cons[1], {"id": "bomb", "n": 1})
	eq(Run.room.type, "start")
	check(Run.room.visited and Run.room.built)
	check(Run.room.get("tutorial", false))
	eq(Music.track_name, "crypt")
	eq(Run.toasts.back().text, "Find the warden and descend deeper.")
	var runs: int = Save.data.stats.runs
	TH.new_run(8)
	eq(Save.data.stats.runs, runs + 1)

func test_entering_through_a_door() -> void:
	var start := Run.room
	var d: String = start.doors.keys()[0]
	var n: Dictionary = start.doors[d]
	Flow.enter_room(n, d)
	check(is_same(Run.room, n))
	var e := RoomU.door_entry(RoomU.DIRS[d].opp)
	eq([Run.player.x, Run.player.y], [e.x, e.y])
	if n.type == "normal":
		check(n.combat, "normal room: combat")

func test_open_door_and_transition() -> void:
	var start := Run.room
	var d: String = start.doors.keys()[0]
	var next: Dictionary = start.doors[d]
	var dir := Vector2(RoomU.DIRS[d].dx, RoomU.DIRS[d].dy)
	var p := Run.player
	# 1 px past this room's edge, in the doorway: still the room's floor
	var at := RoomU.door_center(d) + dir * (Consts.TS / 2.0 + 1.0)
	p.x = at.x
	p.y = at.y
	p.dash_t = 0.1
	Run.bullets = [{"x": at.x - dir.x * 20, "y": at.y - dir.y * 20, "vx": 0.0, "vy": 0.0}]
	Flow.check_doors(Consts.DT)
	check(is_same(Run.room, next), "the room changes at the edge")
	check(Run.trans == null, "no fade, no pause")
	var off := RoomU.room_offset(d)
	eq(Vector2(p.x, p.y), at - off, "no jump: the same spot, seen from the next room")
	near(p.dash_t, 0.1, 1e-9, "a dash goes on")
	eq(Run.bullets.size(), 1, "the shots go on")
	eq(Vector2(Run.bullets[0].x, Run.bullets[0].y), at - dir * 20 - off)
	var back: String = RoomU.DIRS[d].opp
	check(RoomU.door_open(next, back), "the way in stays open while the player is in it")
	check(not Coll.collides(next, p.x, p.y, p.r, false, true), "and lets them through")
	var e := RoomU.door_entry(back)
	p.x = e.x
	p.y = e.y
	Flow.check_doors(Consts.DT)
	check(not next.has("entering"), "inside: the door is the room's again")
	eq(RoomU.door_open(next, back), next.cleared, "open only if the room is clear")

# Godot-only: the room starts (gates, waves) once the player is past its gate
func test_the_fight_waits_until_the_player_is_past_the_gate() -> void:
	var start := Run.room
	var d: String = start.doors.keys()[0]
	var next: Dictionary = start.doors[d]
	RoomBuilder.build_room(next, Run.floor)
	next.cleared = false
	next.waves = [[{"type": "rat", "mod": null}]]
	var dir := Vector2(RoomU.DIRS[d].dx, RoomU.DIRS[d].dy)
	var p := Run.player
	var at := RoomU.door_center(d) + dir * (Consts.TS / 2.0 + 1.0)
	p.x = at.x
	p.y = at.y
	Flow.check_doors(Consts.DT)
	check(is_same(Run.room, next))
	check(not next.combat, "in the doorway: no fight yet")
	for i in 120:
		Flow.update_game(Consts.DT)
	check(Run.enemies.is_empty() and Run.fx.is_empty(), "and no enemies")
	# back out, through the gate still open
	var back := RoomU.door_center(RoomU.DIRS[d].opp) - dir * (Consts.TS / 2.0 + 1.0)
	p.x = back.x
	p.y = back.y
	Flow.check_doors(Consts.DT)
	check(is_same(Run.room, start), "the player can go back")
	check(not next.has("entering") and not next.combat, "the room left untouched")
	# in again, and on past the gate
	p.x = at.x
	p.y = at.y
	Flow.check_doors(Consts.DT)
	var e := RoomU.door_entry(RoomU.DIRS[d].opp)
	p.x = e.x
	p.y = e.y
	Flow.check_doors(Consts.DT)
	check(next.combat, "past the gate: the fight starts")
	check(not RoomU.door_open(next, RoomU.DIRS[d].opp), "and the gate closes")

func test_movement_and_dash() -> void:
	var p := Run.player
	var x0 := p.x
	Controls.sim = {"move": Vector2(1, 0)}
	p.tick(Consts.DT)
	near(p.x - x0, p.speed() * Consts.DT, 1e-6)
	Controls.sim = {"move": Vector2(1, 0), "pressed": ["dash"]}
	p.tick(Consts.DT)
	eq(p.dash_charges, 0)
	near(p.dash_t, 0.16 - Consts.DT, 1e-9)

func test_game_scene_starts() -> void:
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	for i in 30:
		play.tick(Consts.DT)
	check(Run.player.get_parent() == play.get_node("Flat/World/Actors"))
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	check(Run.player.get_parent() == null, "the player stays alive after the scene")
