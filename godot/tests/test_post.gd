extends TestCase
# Godot-only post-processing: biome color grading, aberration and shockwave
# distortion, CRT filter.

var saved: Dictionary

func before() -> void:
	saved = Save.data.settings.duplicate()

func after() -> void:
	Controls.sim.clear()
	Save.data.settings = saved

func test_defaults() -> void:
	var s: Dictionary = Save.defaults().settings
	eq(s.grading, true)
	eq(s.screenFx, true)
	eq(s.crt, false)

func test_every_biome_has_a_grade() -> void:
	for id in ["crypt", "fungus", "forge", "abyss", "heart"]:
		var g: Dictionary = PostFx.grade_for(id)
		check(g.has("shadows") and g.has("highlights") and g.has("sat") and g.has("contrast"), id)
	var none: Dictionary = PostFx.grade_for("nowhere")
	eq(none.sat, 1.0, "unknown biome: neutral grade")
	eq(none.contrast, 1.0)

func test_rings_from_shockwaves_and_explosions() -> void:
	var fx := [
		{"type": "shockwave", "x": 100.0, "y": 80.0, "r": 30.0, "maxR": 120.0, "t": 0.1},
		{"type": "explosion", "x": 50.0, "y": 60.0, "r": 26.0, "life": 0.4, "t": 0.1},
		{"type": "explosion", "x": 50.0, "y": 60.0, "r": 26.0, "life": 0.4, "t": 0.0, "delay": 0.08},
		{"type": "fire", "x": 0.0, "y": 0.0, "t": 0.0, "life": 1.0},
	]
	var rings := PostFx.rings(fx, Vector2(2, -1))
	eq(rings.size(), 2, "delayed explosions and other effects make no ring")
	var a: Vector4 = rings[0]
	eq([a.x, a.y, a.z], [102.0, 79.0, 30.0], "shockwave ring at its radius, shake offset included")
	check(a.w > 0.0, "with some strength")
	var b: Vector4 = rings[1]
	check(b.z > 26.0 * 0.5 and b.w > 0.0, "explosion ring grows from half its radius")

func test_rings_are_capped() -> void:
	var fx: Array = []
	for i in 20:
		fx.append({"type": "shockwave", "x": 0.0, "y": 0.0, "r": 10.0, "maxR": 100.0, "t": 0.0})
	eq(PostFx.rings(fx, Vector2.ZERO).size(), PostFx.MAX_RINGS)

func test_aberration() -> void:
	eq(PostFx.aberration(0.0, 0.0), 0.0, "calm: none")
	check(PostFx.aberration(6.0, 0.0) > 0.0, "shake adds some")
	check(PostFx.aberration(100.0, 1.0) <= PostFx.MAX_ABERRATION, "capped")

func test_screen_fx_off() -> void:
	Save.data.settings.screenFx = false
	eq(PostFx.aberration(6.0, 1.0), 0.0)
	eq(PostFx.rings([{"type": "shockwave", "x": 0.0, "y": 0.0, "r": 10.0, "maxR": 100.0, "t": 0.0}], Vector2.ZERO).size(), 0)

func _entry(tab: String, label: String) -> OptionsMenu:
	var m := OptionsMenu.new(func(): pass)
	m.tab = OptionsMenu.TABS.find(tab)
	var items: Array = m.menu().items
	m.menu().sel = -1
	for i in items.size():
		if items[i].label is String and items[i].label == label:
			m.menu().sel = i
	return m

func test_menu_entries() -> void:
	for label in ["Color grading", "Screen effects"]:
		var m := _entry("Graphics", label)
		check(m.menu().sel >= 0, "the Graphics tab has " + label)
	Save.data.settings.crt = false
	var m := _entry("Picture", "CRT filter")
	check(m.menu().sel >= 0, "the Picture tab has the CRT filter")
	Controls.sim = {"pressed": ["confirm"]}
	m.update()
	eq(Save.data.settings.crt, true)

func test_crt_layer_follows_the_setting() -> void:
	var crt: CanvasItem = Game.get_node("CrtLayer/Crt")
	Save.data.settings.crt = true
	crt._process(0.0)
	check(crt.visible)
	Save.data.settings.crt = false
	crt._process(0.0)
	check(not crt.visible)
