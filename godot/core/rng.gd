class_name RNG
extends RefCounted
# Seeded pseudo-random generator (mulberry32), identical to RNG in js/core.js.
# Works on unsigned 32-bit integers.

const M32 := 0xFFFFFFFF
var s: int

func _init(seed: int) -> void:
	s = seed & M32
	if s == 0:
		s = 1

func next() -> float:
	s = (s + 0x6D2B79F5) & M32
	var t := s
	t = U.imul(t ^ (t >> 15), t | 1) & M32
	t = (t ^ ((t + (U.imul(t ^ (t >> 7), t | 61) & M32)) & M32)) & M32
	return float((t ^ (t >> 14)) & M32) / 4294967296.0

# JS range() (the name range is a global GDScript function)
func frange(a: float, b: float) -> float:
	return a + next() * (b - a)

# JS int()
func rint(a: int, b: int) -> int:
	return a + int(floor(next() * (b - a + 1)))

func pick(arr: Array) -> Variant:
	return arr[int(floor(next() * arr.size()))]

func chance(p: float) -> bool:
	return next() < p

func shuffle(arr: Array) -> Array:
	var i := arr.size() - 1
	while i > 0:
		var j := int(floor(next() * (i + 1)))
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		i -= 1
	return arr

func weighted(list: Array, wf: Callable) -> Variant:
	var tot := 0.0
	for it in list:
		tot += wf.call(it)
	var r := next() * tot
	for it in list:
		r -= wf.call(it)
		if r <= 0:
			return it
	return list[list.size() - 1]
