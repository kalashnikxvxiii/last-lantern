extends TestCase
# Tile: ogni chiave scelta da TilePick deve esistere nell'atlas di ogni bioma.

func test_tileset_per_ogni_bioma() -> void:
	for b in ["crypt", "fungus", "forge", "abyss", "heart"]:
		var ts := TilePick.tileset(b)
		check(ts != null, "tileset " + b)
		var src := ts.get_source(0) as TileSetAtlasSource
		check(src.has_tile(TilePick.coords(b, "wall_corner_1")), "muro d'angolo in " + b)

func test_chiavi_scelte_esistono() -> void:
	for s in [0, 17, 999]:
		for ty in Consts.RH:
			for tx in Consts.RW:
				var k := TilePick.floor_key(tx, ty, s)
				check(TilePick.coords("crypt", k) != Vector2i(-1, -1), "pavimento " + k)
				if tx == 0 or ty == 0 or tx == Consts.RW - 1 or ty == Consts.RH - 1:
					var w := TilePick.wall_key(tx, ty, s)
					check(TilePick.coords("crypt", w) != Vector2i(-1, -1), "muro " + w)
	eq(TilePick.wall_key(0, 0, 5).substr(0, 11), "wall_corner")
	eq(TilePick.wall_key(5, 0, 5).substr(0, 8), "wall_top")
	eq(TilePick.wall_key(0, 3, 5).substr(0, 10), "wall_left1")
	eq(TilePick.wall_key(28, 4, 5).substr(0, 11), "wall_right0")

func test_scelta_del_pavimento_come_il_js() -> void:
	# stessa logica di renderRoomBg: colore = floor(h * 3), giunto se h > 0.55, crepa se h < 0.08
	for i in 200:
		var tx := i % 29
		var ty := i / 29
		var h := U.hash2(tx, ty, 321)
		var k := TilePick.floor_key(tx, ty, 321)
		check(k.begins_with("floor_c%d_" % int(floor(h * 3))), k)
		if h < 0.08:
			check(k.contains("_crack_"), k)
		elif h > 0.55:
			check(k.contains("_seam_"), k)
		else:
			check(k.contains("_plain_"), k)
