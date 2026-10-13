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

# --- Godot-only shadows and ambient occlusion ---

func _cell(img: Image, tx: int, ty: int) -> float:
	# average of the tile's texels in the occluder mask
	var s := 0.0
	for y in Lighting.OCC_RES:
		for x in Lighting.OCC_RES:
			s += img.get_pixel(tx * Lighting.OCC_RES + x, ty * Lighting.OCC_RES + y).r
	return s / (Lighting.OCC_RES * Lighting.OCC_RES)

func test_occluder_mask() -> void:
	var room := Run.room
	room.grid[5][10] = Consts.T.ROCK
	room.grid[5][11] = Consts.T.FLOOR
	room.grid[5][12] = Consts.T.BRAZIER
	var img := Lighting.occluder_mask(room)
	eq(img.get_width(), Consts.RW * Lighting.OCC_RES)
	eq(img.get_height(), Consts.RH * Lighting.OCC_RES)
	near(_cell(img, 0, 0), 1.0, 1e-6, "walls block the light")
	check(_cell(img, 10, 5) > 0.5 and _cell(img, 10, 5) < 1.0, "rocks are round")
	near(_cell(img, 11, 5), 0.0, 1e-6, "the floor lets it through")
	near(_cell(img, 12, 5), 0.0, 1e-6, "a brazier is a light, not an occluder")

func test_shadow_casters_come_first() -> void:
	var L := [
		{"x": 0.0, "y": 0.0, "r": 12.0, "a": 0.45, "col": null},
		{"x": 0.0, "y": 0.0, "r": 72.0, "a": 0.95, "col": "#f29c38"},
		{"x": 0.0, "y": 0.0, "r": 16.0, "a": 0.7, "col": null},
		{"x": 0.0, "y": 0.0, "r": 90.0, "a": 1.0, "col": "#f2a040"},
	]
	var n := Lighting.shadow_first(L)
	eq(n, 2, "only the large lights cast shadows")
	eq([L[0].r, L[1].r], [72.0, 90.0], "large lights first, in their order")
	eq([L[2].r, L[3].r], [12.0, 16.0], "then the others, in their order")
