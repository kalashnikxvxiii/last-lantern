extends TestCase
# Sprite esportati: manifest e dimensioni come compileRows nel JS (outline incluso).

func test_manifest_caricato() -> void:
	Spr.ensure()
	check(Spr.has("player"), "player")
	eq(Spr.size("player"), Vector2i(14, 16))
	eq(Spr.frame_count("player"), 2)
	eq(Spr.frame_count("coin"), 2)
	for n in ["rat", "bat", "skeleton", "skull", "ghoul", "boss_bones", "i_blade", "s_curse", "barrel", "merchant", "chest", "goldchest"]:
		check(Spr.has(n), "manca lo sprite " + n)
	check(not Spr.has("inesistente"))
