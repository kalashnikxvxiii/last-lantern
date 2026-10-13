extends TestCase
# Godot-only quality presets: one entry that sets bloom, shadows, ambient
# occlusion and particles together, picked once from the graphics card.

var saved: Dictionary

func before() -> void:
	saved = Save.data.settings.duplicate()

func after() -> void:
	Controls.sim.clear()
	Save.data.settings = saved

func _press(m: OptionsMenu, a: String) -> void:
	Controls.sim = {"pressed": [a]}
	m.update()
	Controls.sim.clear()

func test_presets_cover_the_same_settings() -> void:
	eq(Quality.LEVELS, ["low", "medium", "high", "ultra"])
	for level in Quality.LEVELS:
		eq(Quality.PRESETS[level].keys(), ["bloom", "shadows", "ao", "particles"], level)

func test_preset_values_exist() -> void:
	for level in Quality.LEVELS:
		var p: Dictionary = Quality.PRESETS[level]
		check(Bloom.LEVELS.has(p.bloom), level + " bloom")
		check(Lighting.SHADOW_STEPS.has(p.shadows), level + " shadows")
		check(AmbientFx.AMOUNT.has(p.particles), level + " particles")
		check(Sparks.SHARE.has(p.particles), level + " sparks")

func test_the_defaults_are_high() -> void:
	Save.data.settings = Save.defaults().settings
	eq(Quality.current(), "high")

func test_apply_and_custom() -> void:
	Quality.apply("low")
	eq(Save.data.settings.shadows, "off")
	eq(Save.data.settings.bloom, "off")
	eq(Quality.current(), "low")
	Save.data.settings.bloom = "high"
	eq(Quality.current(), "custom", "a hand-made mix is Custom")

func test_ultra_goes_further() -> void:
	check(Lighting.SHADOW_STEPS.ultra > Lighting.SHADOW_STEPS.high)
	check(AmbientFx.AMOUNT.ultra > AmbientFx.AMOUNT.high)
	check(Sparks.SHARE.ultra > Sparks.SHARE.high)

func test_menu_entry() -> void:
	Quality.apply("high")
	var m := OptionsMenu.new(func(): pass)
	m.tab = OptionsMenu.TABS.find("Graphics")
	m.menu().sel = 0
	eq(Menu.label_of(m.menu().current()), "Quality   High", "Quality is the first entry")
	_press(m, "nav_right")
	eq(Quality.current(), "ultra")
	_press(m, "nav_right")
	eq(Quality.current(), "ultra", "the choice stops at Ultra")
	Save.data.settings.ao = false
	eq(Menu.label_of(m.menu().current()), "Quality   Custom")
	_press(m, "nav_left")
	eq(Quality.current(), "medium", "from Custom, left starts below High")

func test_auto_pick() -> void:
	eq(Quality.auto_pick(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU), "high")
	eq(Quality.auto_pick(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU), "medium")
	eq(Quality.auto_pick(RenderingDevice.DEVICE_TYPE_CPU), "low")
	eq(Quality.auto_pick(RenderingDevice.DEVICE_TYPE_OTHER), "medium")

func test_first_boot_picks_once() -> void:
	Save.data.settings = Save.defaults().settings
	eq(Save.data.settings.qualityPicked, false)
	Quality.first_boot(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU)
	eq(Quality.current(), "medium")
	eq(Save.data.settings.qualityPicked, true)
	Quality.apply("ultra")
	Quality.first_boot(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU)
	eq(Quality.current(), "ultra", "later boots keep the player's choice")
