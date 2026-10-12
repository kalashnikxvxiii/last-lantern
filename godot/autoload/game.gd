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

# devStart (js/game.js): argomenti di prova dopo "--"
func dev_start() -> void:
	var seed := int(dev.get("seed", -1))
	if seed >= 0:
		U.seed_random(seed)
	Flow.start_run(str(dev.get("lantern", "custode")), int(dev.get("ardore", 0)), seed)
	var mode := str(dev.get("test", ""))
	if mode in ["boss", "shop", "treasure", "elite", "shrine", "secret"]:
		var rs: Array = Run.floor.rooms.filter(func(x): return x.type == mode)
		if not rs.is_empty():
			var r: Dictionary = rs[0]
			r.seen = true
			if mode == "secret":
				r.found = true
			Flow.enter_room(r, null)
			var c := RoomU.tile_center(14, 12)
			Run.player.x = c.x
			Run.player.y = c.y
	elif mode == "fight":
		var rs: Array = Run.floor.rooms.filter(func(x): return x.type == "normal")
		if not rs.is_empty():
			Flow.enter_room(rs[0], rs[0].doors.keys()[0])
	if dev.has("perks"):
		for id in str(dev.perks).split(","):
			if Perks.ALL.has(id):
				Run.player.perks[id] = Run.player.perks.get(id, 0) + 1
	if dev.has("relics"):
		for id in str(dev.relics).split(","):
			if Relics.ALL.has(id):
				Run.player.relics.append(id)
	Run.player.recalc_stats()
	Run.intro = null
	if dev.has("lv"):
		Run.pending_levels = int(dev.lv)
	if dev.has("coins"):
		Run.player.coins = int(dev.coins)
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
	set_scene("play")
