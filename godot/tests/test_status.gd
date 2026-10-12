extends TestCase
# Status effects (addStatus, updateStatuses, cleanse).

func before() -> void:
	TH.new_run(3)
	TH.arena()

func after() -> void:
	Run.reset()

func test_poison_stacks_with_limits() -> void:
	var p := Run.player
	for i in 6:
		Status.add(p, "poison", 3)
	eq(p.statuses.poison.stacks, 3, "player: maximum 3")
	var e := TH.spawn("ghoul", 200, 120)
	for i in 7:
		Status.add(e, "poison", 3, 2.0)
	eq(e.statuses.poison.stacks, 5, "enemy: maximum 5")

func test_three_frost_stacks_freeze() -> void:
	var e := TH.spawn("ghoul", 200, 120)
	Status.add(e, "chill", 2.2)
	Status.add(e, "chill", 2.2)
	eq(e.frozen, 0.0)
	Status.add(e, "chill", 2.2)
	eq(e.frozen, 1.6)
	check(not e.statuses.has("chill"))

func test_immunity() -> void:
	var p := Run.player
	Status.add(p, "immune", 6)
	Status.add(p, "burn", 3)
	check(not p.statuses.has("burn"))
	p.statuses.clear()
	p.stats.immune.poison = 1
	Status.add(p, "poison", 3)
	check(not p.statuses.has("poison"))
	Status.add(p, "rage", 3)
	Status.add(p, "weak", 3)
	Status.cleanse(p)
	eq(p.statuses.keys(), ["rage"])

func test_burn_hurts_every_half_second() -> void:
	var p := Run.player
	var hp := p.hp
	Status.add(p, "burn", 2)
	Status.update(p, 0.49, true)
	eq(p.hp, hp)
	Status.update(p, 0.02, true)
	eq(p.hp, hp - 2)
