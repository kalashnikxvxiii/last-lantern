class_name Display
extends RefCounted
# Godot-only display and picture settings: window mode, resolution, VSync,
# FPS limit, pixel scaling and the brightness/contrast/saturation adjustments.
# Everything reads Save.data.settings; apply_all() runs at boot.

const WINDOW_MODES := ["windowed", "fullscreen", "exclusive"]
const VSYNC_MODES := ["off", "on", "adaptive"]
const FPS_CAPS := [0, 30, 60, 120, 144, 165, 240]
const SCALINGS := ["fit", "integer"]

static var _env: Environment
static var _last_full := "fullscreen"   # where F11 goes back to from a window

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root

static func settings() -> Dictionary:
	return Save.data.settings

static func apply_all() -> void:
	apply_window_mode()
	apply_vsync()
	apply_fps_cap()
	apply_scaling()
	apply_picture()

# --- window mode ---

static func apply_window_mode() -> void:
	if headless():
		return
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	match str(settings().windowMode):
		"fullscreen": mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		"exclusive": mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
		# on some platforms the switch completes later: size the window again next frame
		root().get_tree().process_frame.connect(func(): apply_resolution(), CONNECT_ONE_SHOT)
	apply_resolution()

# F11 and Alt+Enter: windowed <-> the last fullscreen mode
static func toggle_fullscreen() -> void:
	if settings().windowMode != "windowed":
		_last_full = settings().windowMode
	settings().windowMode = _last_full if settings().windowMode == "windowed" else "windowed"
	apply_window_mode()
	Save.write()

static func window_mode_name(m: String) -> String:
	return {"windowed": "Windowed", "fullscreen": "Fullscreen", "exclusive": "Exclusive"}.get(m, m)

# --- resolution: one of the classic sizes, up to the current screen's usable area;
# the window can't be resized by dragging ---

static func classic_resolutions() -> Array:
	return [
		{"w": 1280, "h": 720},
		{"w": 1366, "h": 768},
		{"w": 1600, "h": 900},
		{"w": 1920, "h": 1080},
		{"w": 2560, "h": 1440},
		{"w": 3840, "h": 2160},
	]

static func available_resolutions() -> Array:
	if headless():
		return classic_resolutions()   # the tests never open a window
	# without the taskbar: the window can't be resized, it must fit
	var max_v := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var out: Array = []
	for r in classic_resolutions():
		if r.w <= max_v.x and r.h <= max_v.y:
			out.append(r)
	if out.is_empty():
		out = [classic_resolutions()[0]]
	return out

static func saved_resolution_index() -> int:
	return int(settings().get("res", 2))

# position of the saved resolution inside avail, clamped to its largest entry
static func res_pos(avail: Array) -> int:
	var saved := saved_resolution_index()
	if saved < classic_resolutions().size():
		var i: int = avail.find(classic_resolutions()[saved])
		if i >= 0:
			return i
	return avail.size() - 1

# slider bar, same look as the volume bars
static func res_bar(idx: int, n: int) -> String:
	var frac := float(idx) / maxf(float(n) - 1.0, 1.0)
	var filled := 10 if n == 1 else int(round(frac * 10))
	return "[" + "#".repeat(filled) + "-".repeat(10 - filled) + "]"

# applies the saved resolution to the window, centered on the current screen
static func apply_resolution() -> void:
	if headless() or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var avail := available_resolutions()
	var r: Dictionary = avail[res_pos(avail)]
	var size := Vector2i(r.w, r.h)
	var scr := DisplayServer.window_get_current_screen()
	root().size = size
	var area := DisplayServer.screen_get_usable_rect(scr)
	root().position = area.position + ((area.size - size) / 2).maxi(0)

# --- frame pacing ---

static func apply_vsync() -> void:
	if headless():
		return
	var m := DisplayServer.VSYNC_ENABLED
	match str(settings().vsync):
		"off": m = DisplayServer.VSYNC_DISABLED
		"adaptive": m = DisplayServer.VSYNC_ADAPTIVE
	DisplayServer.window_set_vsync_mode(m)

static func apply_fps_cap() -> void:
	Engine.max_fps = int(settings().fpsCap)

# --- pixel scaling: "fit" fills the window, "integer" keeps every game pixel
# the same size and adds black borders ---

static func apply_scaling() -> void:
	var integer: bool = settings().scaling == "integer"
	root().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if integer else Window.CONTENT_SCALE_STRETCH_FRACTIONAL

# --- picture adjustments, applied to every canvas layer ---

static func environment() -> Environment:
	if _env == null:
		_env = Environment.new()
		_env.background_mode = Environment.BG_CANVAS
		_env.background_canvas_max_layer = 1000
		_env.adjustment_enabled = true
	return _env

static func apply_picture() -> void:
	var e := environment()
	e.adjustment_brightness = float(settings().brightness)
	e.adjustment_contrast = float(settings().contrast)
	e.adjustment_saturation = float(settings().saturation)

# --- helpers for the options menu ---

# next value of a list setting, clamped at the ends
static func step(list: Array, cur: Variant, d: int) -> Variant:
	var i := maxi(0, list.find(cur))
	return list[clampi(i + d, 0, list.size() - 1)]

static func percent(v: float) -> String:
	return str(int(U.jround(v * 100))) + "%"
