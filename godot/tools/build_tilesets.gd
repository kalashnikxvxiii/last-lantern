extends SceneTree
# Generates assets/tiles/<biome>.tres from the exported atlases and layout.json.
# Usage: godot --headless --path godot -s res://tools/build_tilesets.gd

func _initialize() -> void:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://assets/tiles/layout.json")) != OK:
		push_error("layout.json not readable")
		quit(1)
		return
	for biome in j.data.biomes:
		var tex: Texture2D = load("res://assets/tiles/%s.png" % biome)
		# 16 px tiles, or HD ones (64 px): the atlas width says which
		var px := tex.get_width() / int(j.data.columns)
		var ts := TileSet.new()
		ts.tile_size = Vector2i(px, px)
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(px, px)
		for key in j.data.biomes[biome]:
			var c: Array = j.data.biomes[biome][key]
			src.create_tile(Vector2i(int(c[0]), int(c[1])))
		ts.add_source(src, 0)
		var err := ResourceSaver.save(ts, "res://assets/tiles/%s.tres" % biome)
		if err != OK:
			push_error("saving %s failed: %d" % [biome, err])
			quit(1)
			return
		print("tileset ", biome)
	quit(0)
