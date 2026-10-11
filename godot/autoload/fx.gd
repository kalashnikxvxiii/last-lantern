extends Node
# Feedback globali (FX in js/entities.js) e tempo di rendering (Render.time).

var shake_amt := 0.0
var hitstop_t := 0.0
var flash := 0.0
var flash_col := Color.WHITE
var time := 0.0
var vis := RNG.new(777)   # casualità solo visiva: non consuma la sequenza di gioco

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

# parte di updateCommon
func decay(dt: float) -> void:
	shake_amt = maxf(0.0, shake_amt - dt * 30)
	flash = maxf(0.0, flash - dt * 2.5)

# casualità per il disegno (rnd del JS dentro le funzioni draw*)
func vrnd(a: float, b: float) -> float:
	return vis.frange(a, b)

# scostamento dello scuotimento (drawWorld)
func offset() -> Vector2:
	if shake_amt > 0.1:
		return Vector2(U.jround(vrnd(-1, 1) * shake_amt), U.jround(vrnd(-1, 1) * shake_amt))
	return Vector2.ZERO

func reset() -> void:
	shake_amt = 0.0
	hitstop_t = 0.0
	flash = 0.0
