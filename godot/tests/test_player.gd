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
