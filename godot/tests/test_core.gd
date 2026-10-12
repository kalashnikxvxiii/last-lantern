extends TestCase
# Core: RNG and utilities must match the JS bit for bit.

func test_rng_matches_the_js() -> void:
	for c in TestCase.golden("rng"):
		var r := RNG.new(int(c.seed))
		for i in c.values.size():
			var v := r.next()
			# multiples of 2^-32: a tolerance of 1e-12 is equivalent to equality
			# (Godot's JSON parser can lose the last bit of doubles)
			if absf(v - float(c.values[i])) > 1e-12:
				fail("seed %d, output %d: %s != %s" % [c.seed, i, v, c.values[i]])
				return

func test_hash2_matches_the_js() -> void:
	for h in TestCase.golden("util").hash2:
		var v := U.hash2(int(h[0]), int(h[1]), int(h[2]))
		if absf(v - float(h[3])) > 1e-12:
			fail("hash2(%d,%d,%d) = %s, expected %s" % [h[0], h[1], h[2], v, h[3]])
			return

func test_imul_matches_the_js() -> void:
	for c in TestCase.golden("util").imul:
		eq(U.imul(int(c[0]), int(c[1])), int(c[2]), "imul(%d,%d)" % [c[0], c[1]])

func test_jround_like_math_round() -> void:
	for c in TestCase.golden("util").round:
		eq(U.jround(float(c[0])), float(c[1]), "round(%s)" % c[0])

func test_fmt_time() -> void:
	for c in TestCase.golden("util").time:
		eq(U.fmt_time(float(c[0])), c[1])

func test_global_random_sequence() -> void:
	var g: Dictionary = TestCase.golden("util").seq
	U.seed_random(int(g.seed))
	eq(U.rnd(), g.rnd, "rnd()")
	eq(U.rnd(10), g.rnd10, "rnd(10)")
	eq(U.rnd(3, 7), g.rnd37, "rnd(3,7)")
	eq(U.rndi(2, 9), g.rndi29, "rndi(2,9)")
	eq(U.pick(["a", "b", "c", "d"]), g.pick, "pick")
	eq(U.chance(0.3), g.chance, "chance")
	eq(U.shuffle([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]), g.shuffle, "shuffle")
	eq(U.weighted_pick([["x", 1], ["y", 3], ["z", 0.5]], func(k): return k[1])[0], g.weighted, "weighted")

func test_rng_seed_zero_becomes_one() -> void:
	eq(RNG.new(0).next(), RNG.new(1).next())

func test_numbers_like_the_js() -> void:
	eq(U.num(100.0), "100")
	eq(U.num(3), "3")
	eq(U.num(2.5), "2.5")
