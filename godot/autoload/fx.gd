extends Node
# Global feedback (FX in js/entities.js) and render time (Render.time).

var shake_amt := 0.0
var hitstop_t := 0.0
var flash := 0.0
var flash_col := Color.WHITE
var time := 0.0
var vis := RNG.new(777)   # visual-only randomness: does not consume the game sequence
# Godot-only camera: the room leans away from the player, at most CAM_MAX pixels
const CAM_MAX := 6.0
const CAM_SPEED := 4.0
const VIEW_C := Vector2(Consts.RX + Consts.RW * Consts.TS / 2, Consts.RY + Consts.RH * Consts.TS / 2)
var cam := Vector2.ZERO

func _process(_delta: float) -> void:
	time = Time.get_ticks_msec() / 1000.0

func shake(v: float) -> void:
	if Save.data.settings.shake:
		shake_amt = maxf(shake_amt, v)

func hitstop(t: float) -> void:
	hitstop_t = maxf(hitstop_t, t)

func screen_flash(c: Variant, a: float) -> void:
	flash_col = UiDraw.col(c)
	flash = maxf(flash, a)

# part of updateCommon
func decay(dt: float) -> void:
	shake_amt = maxf(0.0, shake_amt - dt * 30)
	flash = maxf(0.0, flash - dt * 2.5)

# randomness for drawing (the JS rnd inside the draw* functions)
func vrnd(a: float, b: float) -> float:
	return vis.frange(a, b)

# shake offset (drawWorld), plus the camera
func offset() -> Vector2:
	if shake_amt > 0.1:
		return cam_px() + Vector2(U.jround(vrnd(-1, 1) * shake_amt), U.jround(vrnd(-1, 1) * shake_amt))
	return cam_px()

# where the camera goes with the player at px, py: the floor edge gives the full lean
static func cam_target(px: float, py: float) -> Vector2:
	var hx := (Consts.RW - 2) * Consts.TS / 2.0
	var hy := (Consts.RH - 2) * Consts.TS / 2.0
	return Vector2(-clampf((px - VIEW_C.x) / hx, -1, 1), -clampf((py - VIEW_C.y) / hy, -1, 1)) * CAM_MAX

func follow(px: float, py: float, delta: float) -> void:
	cam = cam.lerp(cam_target(px, py), 1.0 - exp(-delta * CAM_SPEED))

func cam_px() -> Vector2:
	return Vector2(U.jround(cam.x), U.jround(cam.y))

func reset() -> void:
	cam = Vector2.ZERO
	shake_amt = 0.0
	hitstop_t = 0.0
	flash = 0.0
