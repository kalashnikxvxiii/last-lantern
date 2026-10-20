extends TestCase
# Player economy: healing, oil, coins, consumables, experience.

var p: Player

func before() -> void:
	Run.reset()
	Run.active = true
	p = Player.new()
	Run.player = p
	p.recalc_stats()
	p.hp = 30
	p.oil = 50

func after() -> void:
	Run.reset()

func test_heal_and_multiplier() -> void:
	p.stats.healMult = 0.5
	p.heal(20)
	eq(p.hp, 40.0)
	p.heal(100, true)
	eq(p.hp, 60.0, "not beyond max health")

func test_coins_rounded() -> void:
	p.stats.coinMult = 1.3
	eq(p.add_coins(1), 1)
	eq(p.add_coins(5), 7)
	eq(p.coins, 8)
	eq(Run.coins_total, 8)

func test_consumables_stack_up_to_three() -> void:
	for i in 3:
		check(p.give_cons("bomb"))
	eq(p.cons[0], {"id": "bomb", "n": 3})
	check(p.give_cons("bomb"), "goes to the next slot")
	eq(p.cons[1], {"id": "bomb", "n": 1})
	p.cons = [{"id": "a", "n": 3}, {"id": "b", "n": 3}, {"id": "c", "n": 3}, {"id": "d", "n": 3}]
	check(not p.give_cons("potion"))
	check(not p.can_take_cons("potion"))

func test_experience_and_levels() -> void:
	p.add_xp(19)     # xpNeed(1) = 21
	eq(p.level, 1)
	p.add_xp(40)     # 59 total: level 2 (21) and level 3 (32)
	eq(p.level, 3)
	eq(Run.pending_levels, 2)
	near(p.xp, 6.0)

# Godot-only: the 3D view asks for the alpha again in DrawLifted; it must not
# draw the dash flash a second time and shift the visual sequence
func test_sprite_alpha_leaves_the_flash_alone() -> void:
	p.dash_t = 0.1
	var s := Fx.vis.s
	eq(p.sprite_alpha(), 1.0)
	eq(Fx.vis.s, s)
	p.statuses["invis"] = 1.0
	eq(p.sprite_alpha(), 0.35)
	eq(p.sprite_state().o.alpha, 0.35)

# Godot-only: the sprite turns with the aim, 5 views (down to up) of 2 frames,
# mirrored for the left side
func test_sprite_view_follows_the_aim() -> void:
	for c in [[PI / 2, 0, false], [PI / 4, 2, false], [0.0, 4, false], [-PI / 4, 6, false],
			[-PI / 2, 8, false], [PI, 4, true], [3 * PI / 4, 2, true], [-3 * PI / 4, 6, true]]:
		p.aim = c[0]
		p.facing = 1 if cos(p.aim) >= 0 else -1
		var st := p.sprite_state()
		eq(st.frame, c[1], "aim %s" % c[0])
		eq(st.o.flip, c[2], "aim %s" % c[0])
