class_name TH
extends RefCounted
# Helpers for game tests without a scene.

static func new_run(seed: int = 7, lantern: String = "warden") -> void:
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

# combat room without waves: the doors stay closed while an enemy is alive
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
static func spawn(type: String, x: float, y: float, mod: Variant = null) -> Enemy:
	var e := Enemy.make(type, x, y, mod)
	e.stun = 0.0
	Run.add_enemy(e)
	return e
