extends TestCase
# Exported sprites: manifest and sizes as compileRows in the JS (outline included).

func test_manifest_loaded() -> void:
	Spr.ensure()
	check(Spr.has("player"), "player")
	eq(Spr.size("player"), Vector2i(14, 16))
	eq(Spr.frame_count("player"), 10)
	eq(Spr.frame_count("coin"), 2)
	for n in ["rat", "bat", "skeleton", "skull", "ghoul", "boss_bones", "i_blade", "s_curse", "barrel", "merchant", "chest", "goldchest"]:
		check(Spr.has(n), "missing sprite " + n)
	check(not Spr.has("nonexistent"))

func test_hd_art_keeps_the_logical_size() -> void:
	# art drawn at 4 texels per logical pixel: same size and frames, k = 4
	var tex := ImageTexture.create_from_image(Image.create(112, 64, false, Image.FORMAT_RGBA8))
	var e := Spr.entry(tex, {"w": 14, "h": 16, "frames": 2})
	eq(Vector2i(e.w, e.h), Vector2i(14, 16))
	eq(e.k, 4)
	eq(Spr.src_rect(e, 1), Rect2(56, 0, 56, 64))
	Spr.ensure()
	eq(Spr.db.player.k, 4)   # the characters are HD art
