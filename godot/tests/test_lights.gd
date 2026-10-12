extends TestCase
# Lights collected like collectLights and ambient darkness like drawLighting.

func before() -> void:
	TH.new_run(7)

func after() -> void:
	Run.reset()

func test_player_light_and_braziers() -> void:
	var L := Lights.collect()
	var p := Run.player
	check(L[0].r > p.light() * 0.97 and L[0].r < p.light() * 1.03, "flicker within 3%")
	eq(L[0].col, "#f2a040")
	var braziers := 0
	for row in Run.room.grid:
		braziers += row.count(Consts.T.BRAZIER)
	eq(L.size(), 1 + braziers)

func test_ambient_darkness() -> void:
	near(Lighting.ambient(0.68, 1, false, false, false, false), 0.68)
	near(Lighting.ambient(0.68, 1, true, false, false, false), 0.68 * 0.84)
	near(Lighting.ambient(0.68, 1, true, true, false, false), 0.68, 1e-9, "the boss room does not brighten")
	near(Lighting.ambient(0.9, 1, false, false, true, true), 0.94, 1e-9, "without oil in combat, at most 0.94")
	near(Lighting.ambient(0.68, 8, false, false, false, false), 0.68 + 0.045)
