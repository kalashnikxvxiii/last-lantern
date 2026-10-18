extends TestCase
# Projectiles: walls, bounces, piercing, shards, hits on the player, leaving the screen.

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

func test_wall_without_bounce() -> void:
	_shot(Consts.RX + 20, 120, -600, 0)
	for i in 10:
		Bullets.update_player(Consts.DT)
	eq(Run.bullets.size(), 0)

func test_bounce() -> void:
	var b := _shot(Consts.RX + 20, 120, -600, 0, {"bounce": 1})
	for i in 4:
		Bullets.update_player(Consts.DT)
	check(b.vx > 0, "bounced")
	eq(b.bounce, 0)

func test_piercing() -> void:
	var a := TH.spawn("ghoul", 200, 120)
	var c := TH.spawn("ghoul", 240, 120)
	_shot(170, 120, 300, 0, {"pierce": 1})
	for i in 30:
		Bullets.update_player(Consts.DT)
	check(a.hp < a.max_hp and c.hp < c.max_hp, "both hit")
	eq(Run.bullets.size(), 0)

func test_shards_on_the_wall() -> void:
	Run.player.stats.split = 1
	_shot(Consts.RX + 20, 120, -600, 0)
	for i in 3:
		Bullets.update_player(Consts.DT)
	eq(Run.bullets.filter(func(b): return b.kind == "shard").size(), 3)

func test_enemy_hit_and_status() -> void:
	var p := Run.player
	var hp := p.hp
	Run.ebullets.append({"x": p.x - 20, "y": p.y - 1, "vx": 300.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "violet", "status": "slow", "src": "Test", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false})
	for i in 10:
		Bullets.update_enemy(Consts.DT)
	check(p.hp < hp)
	check(p.statuses.has("slow"))
	eq(Run.ebullets.size(), 0)

func test_ghost_shots_leave_the_edge() -> void:
	Run.ebullets.append({"x": Consts.RX + 20.0, "y": 60.0, "vx": -600.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "red", "status": null, "src": "Test", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false, "ghost": true})
	for i in 5:
		Bullets.update_enemy(Consts.DT)
	eq(Run.ebullets.size(), 0)

# Godot-only: the rooms lie side by side; a shot through an open door flies on over
# the room next door, harmless there
func _next_room_north() -> Dictionary:
	TH.new_run(7)   # the start room: cleared, its only door to the north
	var next: Dictionary = Run.room.doors["n"]
	RoomBuilder.build_room(next, Run.floor)
	return next

func test_a_shot_flies_on_through_an_open_door() -> void:
	_next_room_north()
	var c := RoomU.door_center("n")
	var b := _shot(c.x, c.y + 20, 0, -200)
	for i in 30:
		Bullets.update_player(Consts.DT)
	check(not b.get("dead", false), "still flying")
	check(b.y < Consts.RY - Consts.TS, "past the edge, over the room next door: %s" % b.y)

func test_a_shot_stops_on_the_next_room_without_harming_it() -> void:
	var next := _next_room_north()
	var k := 12 * Consts.RW + 14
	next.grid[12][14] = Consts.T.BARREL
	next.tileHp[k] = 18
	var c := RoomU.door_center("n")
	var b := _shot(c.x, c.y + 20, 0, -200)
	for i in 60:
		Bullets.update_player(Consts.DT)
	check(b.get("dead", false), "stopped by the barrel")
	var barrel_bottom := Consts.RY + 13 * Consts.TS - Consts.RH * Consts.TS   # in this room's coordinates
	check(b.y < Consts.RY - Consts.TS and b.y >= barrel_bottom - 4.0, "at the barrel, not before nor through it: %s" % b.y)
	eq(next.tileHp[k], 18, "the barrel takes no damage")
	eq(next.grid[12][14], Consts.T.BARREL)

func test_a_closed_door_still_stops_a_shot() -> void:
	_next_room_north()
	Run.room.cleared = false
	Run.room.combat = true
	var c := RoomU.door_center("n")
	var b := _shot(c.x, c.y + 20, 0, -200)
	for i in 30:
		Bullets.update_player(Consts.DT)
	check(b.get("dead", false))
	check(b.y >= Consts.RY, "at the gate")
