class_name RunSave
extends RefCounted
# Godot-only: save slots for the runs in progress, one file per slot next to
# the permanent save. A resumed run restarts the fight of the room it was
# left in (the waves start over), everything else is kept as it was.

const SLOTS := 3
const RUN_VARS := ["seed", "depth", "ardor", "kills", "time", "dmg_dealt", "dmg_taken", "coins_total",
	"pending_levels", "reroll_cost", "offered_relics", "won", "endless", "rooms_cleared", "blood_paid", "win_recorded"]

# follows Save.path, so the tests use their own files
static func path(slot: int) -> String:
	return Save.path.get_basename() + "_slot%d.run" % (slot + 1)

static func save(slot: int) -> bool:
	if slot < 0 or not Run.active or Run.player == null:
		return false
	var p := Run.player
	var run := {"rng": Run.rng.s, "cheated": Run.cheated}
	for k in RUN_VARS:
		run[k] = Run.get(k)
	var player := {}
	for pr in p.get_property_list():
		if pr.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			player[pr.name] = p.get(pr.name)
	# the doors point to the neighbouring rooms: saved as their keys
	var rooms: Array = []
	for r in Run.floor.rooms:
		var c: Dictionary = r.duplicate()
		c.doors = {}
		for d in r.doors:
			c.doors[d] = RoomU.key(r.doors[d])
		rooms.append(c)
	var perks := 0
	for id in p.perks:
		perks += p.perks[id]
	var summary := {"lantern": p.lantern, "depth": Run.depth, "ardor": Run.ardor, "level": p.level,
		"hp": p.hp, "maxHp": p.stats.maxHp, "coins": p.coins, "time": Run.time, "kills": Run.kills,
		"perks": perks, "relics": p.relics.duplicate(), "endless": Run.endless,
		"date": Time.get_datetime_string_from_system(false, true)}
	var d := {"v": 1, "summary": summary, "run": run, "player": player, "rooms": rooms,
		"room": RoomU.key(Run.room)}
	return Save.write_file(path(slot), var_to_bytes(d))

# {} when the slot is empty or unreadable
static func read(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var bytes := FileAccess.get_file_as_bytes(path(slot))
	var d: Variant = bytes_to_var(bytes) if bytes.size() > 0 else null   # no objects allowed
	if not (d is Dictionary and d.get("v") == 1 and d.has_all(["summary", "player", "rooms", "room"])):
		return {}
	# a slot from before RUN_VARS grew, or a truncated one, would break resume
	if not (d.get("run") is Dictionary and d.run.has_all(RUN_VARS + ["rng"])):
		return {}
	return d

static func erase(slot: int) -> void:
	if slot >= 0 and FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))

static func resume(slot: int) -> bool:
	var d := read(slot)
	if d.is_empty():
		return false
	Run.reset()
	Run.active = true
	Run.slot = slot
	for k in RUN_VARS:
		Run.set(k, d.run[k])
	Run.rng = RNG.new(1)
	Run.rng.s = d.run.rng
	Run.cheated = d.run.get("cheated", false)   # added later: older slots lack it
	var p := Player.new()
	for k in d.player:
		p.set(k, d.player[k])
	Run.player = p
	var map := {}
	var by_key := {}   # Godot-only: a room may cover several cells
	for r in d.rooms:
		by_key[RoomU.key(r)] = r
		for c in RoomU.cells(r):
			map[FloorGen._key(r.gx + c.x, r.gy + c.y)] = r
	var start: Dictionary = {}
	for r in d.rooms:
		for dir in r.doors:
			r.doors[dir] = by_key[r.doors[dir]]
		r.bgDirty = true
		if r.type == "start":
			start = r
	Run.floor = {"depth": Run.depth, "rooms": d.rooms, "map": map, "start": start}
	Particles.clear()
	Floaters.clear()
	var x := p.x
	var y := p.y
	Flow.enter_room(by_key[d.room], null)
	p.x = x
	p.y = y
	Music.play(DB.biome_of(Run.depth).music)
	return true
