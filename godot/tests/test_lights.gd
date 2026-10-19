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

# --- Godot-only materials: dry stone stays matte, wet and metal surfaces shine ---

func test_every_biome_has_a_sheen() -> void:
	for id in ["crypt", "fungus", "forge", "abyss", "heart"]:
		var s := Lighting.sheen(id)
		check(s >= 0.0 and s <= 1.0, id)
	eq(Lighting.sheen("crypt"), 0.0, "the crypts are dry rock")
	check(Lighting.sheen("forge") > Lighting.sheen("crypt"), "the forge shines more")

func test_walls_are_matte_in_every_biome() -> void:
	var v := View3D.new()
	for d in range(1, 6):   # one floor of each biome
		Run.floor.depth = d
		var w := v.build_solids(Run.room).surface_get_material(0) as ShaderMaterial
		check(w.shader.code.contains("specular_disabled"), "depth %d: this room's walls, no glare either" % d)
		var m := v.build_solids(Run.room, true).surface_get_material(0) as StandardMaterial3D
		eq(m.specular_mode, BaseMaterial3D.SPECULAR_DISABLED, "depth %d: the light rests on the wall, no glare" % d)
		near(m.roughness, 1.0, 1e-6, "depth %d: fully rough" % d)
	v.free()

func test_lifted_details_follow_the_picture_settings() -> void:
	var saved: Dictionary = Save.data.settings.duplicate()
	Save.data.settings.brightness = 1.2
	Save.data.settings.contrast = 0.8
	Save.data.settings.saturation = 0.5
	var d := DrawLifted.new()
	d._ready()
	d._process(0.0)
	eq((d.material as ShaderMaterial).get_shader_parameter("bcs"), Vector3(1.2, 0.8, 0.5))
	d.free()
	Save.data.settings = saved

# --- Godot-only: the player and the enemies cast shadows like the room's elements ---

func test_the_player_and_live_enemies_block_the_light() -> void:
	var p := Run.player
	var e := TH.spawn("rat", p.x + 40, p.y)
	var gone := TH.spawn("rat", p.x - 40, p.y)
	gone.dead = true
	var born := TH.spawn("rat", p.x, p.y + 40)
	born.spawning = true
	var A := Lighting.actor_occluders()
	eq(A.size(), 2, "the player and the live enemy")
	eq(A[0], Vector3(p.x, p.y, Lighting.PLAYER_R))
	eq(A[1], Vector3(e.x, e.y, e.r))

func test_the_lantern_casts_the_players_shadow_from_where_it_is_held() -> void:
	var p := Run.player
	for aim in [0.0, PI / 2, PI, -PI / 2]:
		p.aim = aim
		var o := Lighting.lantern_origin(p)
		near(o.x, p.x + cos(aim) * 7.0, 1e-4, "held on the aiming side")
		near(o.y, p.y + sin(aim) * 7.0, 1e-4)
		check(o.distance_to(Vector2(p.x, p.y)) > Lighting.PLAYER_R, "outside the body, so the body casts a shadow")

func test_only_the_players_own_light_casts_from_the_lantern() -> void:
	var saved: Dictionary = Save.data.settings.duplicate()
	Save.data.settings.shadows = "high"
	Run.room.grid[3][3] = Consts.T.BRAZIER
	var p := Run.player
	var g := Lighting.new()
	g._ready()
	var m := g.light.material as ShaderMaterial
	g.refresh(Vector2.ZERO)
	check((m.get_shader_parameter("lantern") as Vector2).x > -1e4, "the lantern casts the actors' shadows")
	p.statuses["blind"] = 5.0
	p.oil = 0.0
	check(p.light() < Lighting.SHADOW_MIN_R, "too small to cast shadows: the brazier comes first")
	g.refresh(Vector2.ZERO)
	eq(m.get_shader_parameter("lantern"), Vector2(-1e5, -1e5), "the brazier keeps its own shadows")
	g.free()
	Save.data.settings = saved

func test_the_players_shadow_starts_at_its_feet() -> void:
	var h := Spr.size("player").y
	eq(Lighting.player_feet(), Vector2(0, h / 2.0 - 1.0), "where the sprite stands, as View3D.feet() puts it")
