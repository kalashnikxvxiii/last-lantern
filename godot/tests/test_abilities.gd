extends TestCase
# Godot-only: the character abilities on the right button (Player.use_ability).

var p: Player

func before() -> void:
	TH.new_run(21)
	var room := TH.arena()
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			room.grid[ty][tx] = Consts.T.FLOOR
	p = Run.player
	p.inv = 0.0
	p.stats.crit = 0.0
	p.oil = 100.0

func after() -> void:
	Run.reset()

func _as(id: String) -> void:
	p.character = id

func test_cost_scales_with_the_flare_cost() -> void:
	eq(p.ability_cost(), p.stats.flareCost)
	_as("goblin")
	near(p.ability_cost(), p.stats.flareCost * 35.0 / 40.0)
	p.stats.flareCost = 20.0   # halved by a perk or relic: every ability costs half
	near(p.ability_cost(), 17.5)

func test_no_oil_no_ability() -> void:
	_as("wizard")
	p.oil = 10.0
	p.use_ability()
	eq(p.oil, 10.0)
	eq(Run.bullets.size(), 0)
	near(p.flare_cd, 0.4)

func test_smoke_bomb_blinds_the_enemies_near() -> void:
	_as("goblin")
	var near_e := TH.spawn("ghoul", p.x + 30, p.y)
	var far_e := TH.spawn("ghoul", p.x + 150, p.y)
	p.use_ability()
	near(p.oil, 100.0 - p.ability_cost())
	check(near_e.statuses.has("blind"))
	check(not far_e.statuses.has("blind"))
	check(p.statuses.has("invis"))
	check(not is_same(near_e.target(), p), "a blinded enemy loses the player")
	check(not is_same(far_e.target(), p), "the player is invisible to everyone")

func test_phase_jump_moves_along_the_aim_and_chills() -> void:
	_as("stranger")
	var x0 := p.x
	var e := TH.spawn("ghoul", p.x + 20, p.y)
	p.aim = PI   # left
	p.use_ability()
	check(p.x < x0 - 60, "jumped about 80 px to the left")
	check(e.statuses.has("chill"), "the pulse at the start chills")
	check(p.inv > 0)

func test_phase_jump_stops_inside_the_room() -> void:
	_as("stranger")
	p.x = Consts.RX + 30
	p.aim = PI
	p.use_ability()
	check(not Coll.collides(Run.room, p.x, p.y, p.r, false, true))
	check(p.x >= Consts.RX + p.r)

func test_overclock() -> void:
	_as("cogling")
	var d0 := p.damage()
	var t0 := p.damage_taken(20)
	p.use_ability()
	near(p.damage(), d0 * (p.stats.dmgMult + 0.5) / p.stats.dmgMult)
	check(p.damage_taken(20) < t0, "+2 armor")
	near(p.statuses.rage.t, 5.0)
	for i in 301:
		p.tick(Consts.DT)
	eq(p.damage_taken(20), t0, "the armor lasts 5 seconds too")

func test_talon_dash_strikes_once_on_the_way() -> void:
	_as("owlfox")
	var e := TH.spawn("ghoul", p.x + 30, p.y)
	e.stun = 10.0
	p.aim = 0.0
	var charges := p.dash_charges
	p.use_ability()
	check(p.dash_t > 0)
	eq(p.dash_charges, charges, "does not spend a dash")
	for i in 20:
		p.tick(Consts.DT)
	check(p.x > e.x - 10, "dashed through")
	if is_instance_valid(e):
		var hits := e.max_hp - e.hp
		check(hits > 0)
		for i in 20:
			p.tick(Consts.DT)
		eq(e.max_hp - e.hp, hits, "struck once")

func test_arcane_volley() -> void:
	_as("wizard")
	p.use_ability()
	eq(Run.bullets.size(), 12)
	for b in Run.bullets:
		eq(b.pierce, 99)
