class_name U
extends RefCounted
# Utilities ported from js/core.js and js/dungeon.js.
# All game randomness (Math.random in the JS) goes through U.random(),
# so tests can fix its seed with U.seed_random().

static var rand: RNG = RNG.new(int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF)

static func random() -> float:
	return rand.next()

static func seed_random(s: int) -> void:
	rand = RNG.new(s)

# rnd(a) in [0, a), rnd(a, b) in [a, b)
static func rnd(a: float = 1.0, b: Variant = null) -> float:
	if b == null:
		return random() * a
	return a + random() * (float(b) - a)

static func rndi(a: int, b: int) -> int:
	return int(floor(rnd(a, b + 1)))

static func pick(arr: Array) -> Variant:
	return arr[int(floor(random() * arr.size()))]

static func chance(p: float) -> bool:
	return random() < p

static func shuffle(arr: Array) -> Array:
	var i := arr.size() - 1
	while i > 0:
		var j := int(floor(random() * (i + 1)))
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		i -= 1
	return arr

static func weighted_pick(list: Array, wf: Callable) -> Variant:
	var tot := 0.0
	for it in list:
		tot += wf.call(it)
	var r := random() * tot
	for it in list:
		r -= wf.call(it)
		if r <= 0:
			return it
	return list[list.size() - 1]

static func dist(ax: float, ay: float, bx: float, by: float) -> float:
	return sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))

static func dist2(ax: float, ay: float, bx: float, by: float) -> float:
	return (bx - ax) * (bx - ax) + (by - ay) * (by - ay)

static func ang_to(ax: float, ay: float, bx: float, by: float) -> float:
	return atan2(by - ay, bx - ax)

static func ang_diff(a: float, b: float) -> float:
	var d := b - a
	while d > PI:
		d -= TAU
	while d < -PI:
		d += TAU
	return d

static func approach(v: float, t: float, d: float) -> float:
	return minf(v + d, t) if v < t else maxf(v - d, t)

# JS Math.round: halves go toward +infinity
static func jround(v: float) -> float:
	return floor(v + 0.5)

static func fmt_time(sec: float) -> String:
	var s := int(floor(sec))
	var m := s / 60
	var r := s % 60
	return "%d:%s%d" % [m, "0" if r < 10 else "", r]

static func to_int32(v: int) -> int:
	v = v & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v

# JS ToInt32 applied to a floating-point number
static func f_to_int32(x: float) -> int:
	if is_nan(x) or is_inf(x):
		return 0
	return to_int32(int(x) & 0xFFFFFFFF)

# Math.imul: 32-bit product without 64-bit overflow
static func imul(a: int, b: int) -> int:
	a = a & 0xFFFFFFFF
	b = b & 0xFFFFFFFF
	var lo := (a * (b & 0xFFFF)) & 0xFFFFFFFF
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return to_int32((lo + hi) & 0xFFFFFFFF)

# hash2 from js/dungeon.js. The second product in the JS is floating point
# and loses precision: it must be reproduced with a float, not an integer.
static func hash2(x: int, y: int, s: int = 0) -> float:
	var h := to_int32(x * 374761393 + y * 668265263 + s * 1442695041)
	var v := to_int32(h ^ ((h & 0xFFFFFFFF) >> 13))
	var p := float(v) * 1274126177.0
	var a := f_to_int32(p)
	var b := (a & 0xFFFFFFFF) >> 16
	return float((a ^ b) & 0xFFFFFFFF) / 4294967296.0

static func rgba(r: int, g: int, b: int, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)

static func later(sec: float, fn: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(sec).timeout.connect(fn)

# number as the JS prints it: no ".0" for integer values
static func num(v: Variant) -> String:
	if typeof(v) == TYPE_FLOAT and v == floorf(v) and absf(v) < 1e15:
		return str(int(v))
	return str(v)
