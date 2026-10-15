extends Node
# Scenes, development arguments, screenshots and error capture
# (setScene, boot and devStart in js/game.js).

var SCENES := {
	"title": "res://ui/screens/title.tscn",
	"options": "res://ui/screens/options.tscn",
	"slots": "res://ui/screens/slots.tscn",
	"select": "res://ui/screens/select.tscn",
	"records": "res://ui/screens/records.tscn",
	"help": "res://ui/screens/help.tscn",
	"play": "res://scenes/play.tscn",
	"gameover": "res://ui/screens/gameover.tscn",
	"victory": "res://ui/screens/victory.tscn",
}
var scene_name := ""
var scene_arg: Variant = null
var dev: Dictionary = {}
var error := ""
var frames := 0

class ErrorLogger extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return   # warnings are not game errors
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
		Quality.first_boot(RenderingServer.get_video_adapter_type())
	var env := WorldEnvironment.new()
	env.environment = Display.environment()
	add_child(env)
	Display.apply_all()
	Loc.apply()
	get_window().focus_exited.connect(_on_focus_lost)
	var crt_layer := CanvasLayer.new()
	crt_layer.name = "CrtLayer"
	crt_layer.layer = 99   # above every screen, below the error bar
	var crt := Crt.new()
	crt.name = "Crt"
	crt_layer.add_child(crt)
	add_child(crt_layer)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(ErrorBar.new())
	add_child(layer)

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

# called by the boot scene
func boot() -> void:
	if dev.has("test") or dev.has("spawn") or dev.has("seed"):
		dev_start()
	elif dev.has("scene"):
		set_scene(str(dev.scene))
	else:
		set_scene("title")

# auto-pause when the window loses focus (boot in js/game.js)
static func should_autopause(scene: String, mode: Variant, dead: bool, victory_t: float) -> bool:
	return scene == "play" and mode == "play" and not dead and victory_t == 0.0

func _on_focus_lost() -> void:
	var sc := get_tree().current_scene
	if sc != null and Run.active and Run.player != null and should_autopause(scene_name, sc.get("mode"), Run.player.dead, Run.victory_t):
		sc.open_pause()

# Godot-only: closing the window during a run saves it in its slot
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Run.active and Run.player != null \
			and should_autopause(scene_name, "play", Run.player.dead, Run.victory_t):
		RunSave.save(Run.slot)

# Godot-only: on quit the static caches would outlive the renderer and crash
# the engine when they free their textures (signal 11 after "RID allocations leaked")
func _exit_tree() -> void:
	release_caches()

func release_caches() -> void:
	Spr.db = {}
	Txt._atlas = null
	UiDraw._glow_tex = null
	WellBg._bg = null
	TilePick._sets = {}
	Sparks._palettes = {}
	Display._env = null
	DB._cache = {}

# F11 and Alt+Enter: fullscreen (as in desktop/main.js)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			Display.toggle_fullscreen()
			get_viewport().set_input_as_handled()

# error bar (frame() in js/game.js), above every screen
class ErrorBar extends Node2D:
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		# top right, just left of the minimap: the bottom left holds the level,
		# the coins, the keys and the consumables, the bottom right the cheats
		if Save.data.settings.showFps and not CheatMenu.info_shown():
			UiDraw.text(self, str(int(Engine.get_frames_per_second())) + " FPS", 387, 6, {"align": "right", "color": "#8a8294"})
		var g := get_node("/root/Game")
		if g.error == "":
			return
		UiDraw.px_rect(self, 0, Consts.H - 32, Consts.W, 32, "#300810")
		UiDraw.text(self, Loc.f("Error: {0}", [g.error.substr(0, 70)]), 4, Consts.H - 29, {"color": "#ff8080"})
		var seed_txt := ("  seed " + str(Run.seed)) if Run.active else ""
		UiDraw.text(self, Loc.f("Take a screenshot and send it along with the feedback form. {0}", [Consts.VERSION + seed_txt]), 4, Consts.H - 16, {"color": "#e8c0c0"})

func _process(_delta: float) -> void:
	if dev.has("screenshot") and scene_name != "":
		frames += 1
		if frames == int(dev.get("shot-after", 30)):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(str(dev.screenshot))
			get_tree().quit()

# devStart (js/game.js): test arguments after "--"
func dev_start() -> void:
	var seed := int(dev.get("seed", -1))
	if seed >= 0:
		U.seed_random(seed)
	Flow.start_run(str(dev.get("lantern", "warden")), int(dev.get("ardor", 0)), seed)
	if dev.has("depth"):
		Run.depth = int(dev.depth)
		Flow.new_floor()
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
	# --spawn=rat,bat: enemies in the current room, to try out the AI
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
