extends TestCase
# Particles, floating numbers and global feedback (limits and decay as in the JS).

func before() -> void:
	Particles.clear()
	Floaters.clear()
	Fx.reset()
	U.seed_random(3)

func test_particles_capped_and_expired() -> void:
	for i in 950:
		Particles.add({"x": 0.0, "y": 0.0, "life": 1.0})
	eq(Particles.list.size(), 901)
	Particles.update(1.01)
	eq(Particles.list.size(), 0)

func test_burst_and_friction() -> void:
	Particles.burst(10, 10, 5, ["#ffffff", "#000000"], 60, 0.5, {"grav": 40})
	eq(Particles.list.size(), 5)
	var p: Dictionary = Particles.list[0]
	var vx0: float = p.vx
	Particles.update(0.1)
	near(p.vx, vx0 - vx0 * 2.0 * 0.1, 1e-9, "default friction 2")

func test_floating_numbers() -> void:
	for i in 90:
		Floaters.add(0, 0, "x")
	eq(Floaters.list.size(), 81)
	Floaters.update(0.81)
	eq(Floaters.list.size(), 0)

func test_shake_respects_the_options() -> void:
	Save.data.settings.shake = false
	Fx.shake(5)
	eq(Fx.shake_amt, 0.0)
	Save.data.settings.shake = true
	Fx.shake(5)
	eq(Fx.shake_amt, 5.0)
	Fx.screen_flash("#c02020", 0.35)
	Fx.decay(0.1)
	near(Fx.shake_amt, 2.0)
	near(Fx.flash, 0.1)
