extends TestCase
# Economia del giocatore: cure, olio, monete, consumabili, esperienza.

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

func test_cura_e_moltiplicatore() -> void:
	p.stats.healMult = 0.5
	p.heal(20)
	eq(p.hp, 40.0)
	p.heal(100, true)
	eq(p.hp, 60.0, "non oltre la vita massima")

func test_monete_arrotondate() -> void:
	p.stats.coinMult = 1.3
	eq(p.add_coins(1), 1)
	eq(p.add_coins(5), 7)
	eq(p.coins, 8)
	eq(Run.coins_total, 8)

func test_consumabili_si_impilano_fino_a_tre() -> void:
	for i in 3:
		check(p.give_cons("bomb"))
	eq(p.cons[0], {"id": "bomb", "n": 3})
	check(p.give_cons("bomb"), "va nello slot successivo")
	eq(p.cons[1], {"id": "bomb", "n": 1})
	p.cons = [{"id": "a", "n": 3}, {"id": "b", "n": 3}, {"id": "c", "n": 3}, {"id": "d", "n": 3}]
	check(not p.give_cons("potion"))
	check(not p.can_take_cons("potion"))

func test_esperienza_e_livelli() -> void:
	p.add_xp(19)     # xpNeed(1) = 21
	eq(p.level, 1)
	p.add_xp(40)     # 59 totali: livello 2 (21) e livello 3 (32)
	eq(p.level, 3)
	eq(Run.pending_levels, 2)
	near(p.xp, 6.0)
