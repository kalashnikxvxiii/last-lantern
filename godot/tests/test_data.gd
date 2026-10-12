extends TestCase
# Data tables: counts, order and values as in js/data.js.

func test_tables_and_order() -> void:
	eq(Perks.ALL.size(), 41)
	eq(Perks.ALL.keys()[0], "dmg")
	eq(Perks.ALL.keys()[40], "sun")
	eq(Relics.ALL.size(), 26)
	eq(Relics.ALL.keys()[25], "r_gauntlet")
	eq(Curses.ALL.keys(), ["c_dark", "c_frail", "c_greed", "c_haste", "c_blood", "c_fog", "c_weak", "c_rust"])
	eq(EliteMods.ALL.keys(), ["armored", "swift", "vampiric", "volatile", "regen", "splitter", "venom"])
	eq(Cons.ALL.keys(), ["potion", "bigpotion", "oil", "bomb", "antidote", "rage", "frost", "map", "firefly", "dice", "smoke", "holy", "feather"])
	eq(Statuses.ALL.size(), 11)
	eq(Stats.base().size(), 71)

func test_sample_values() -> void:
	eq(Perks.ALL["range"].desc, "+^y20%^w range and +^y12%^w projectile speed.")
	eq(Relics.ALL.r_skull.curse, "c_frail")
	eq(Cons.ALL.feather.w, 1.5)
	check(Cons.ALL.feather.passive)
	var s := Stats.base()
	Perks.apply("range", s, 2)
	near(s["range"], 200 * 1.4)
	near(s.shotSpeed, 230 * 1.24)

func test_enemy_and_boss_resources() -> void:
	var rat := DB.enemy("rat")
	eq([rat.name, rat.hp, rat.spd, rat.ai, rat.side, rat.burst], ["Crypt Rat", 14.0, 74.0, "chaser", true, true])
	eq(DB.enemy("skull").shot, {"kind": "orb", "col": "violet", "spd": 68.0, "cd": 3.2, "ring": 6})
	eq(DB.enemy("ghoul").charge_spd, 225.0)
	var b := DB.boss("bones")
	eq([b.hp, b.r, b.phases.size(), b.phases[1].pats.size()], [800.0, 11.0, 2, 5])
	var c := DB.biome_of(1)
	eq(c.pool, [["rat", 1, 3], ["bat", 1, 3], ["skeleton", 2, 3], ["skull", 3, 2], ["ghoul", 3, 1.5]])
	eq(c.dark, 0.68)

func test_lanterns() -> void:
	eq(DB.LANTERN_IDS, ["warden", "pilgrim", "broken", "hollow", "black"])
	var st: Dictionary = Save.defaults().stats
	check(DB.lantern("warden").unlocked(st))
	check(not DB.lantern("pilgrim").unlocked(st))
	st.bossKills = 1
	check(DB.lantern("pilgrim").unlocked(st))
	eq(DB.lantern("nonexistent").id, "warden")
	var s := Stats.base()
	DB.lantern("broken").apply_stats(s)
	eq(s.maxHp, 39.0)
