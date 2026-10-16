extends TestCase
# Room background: the 2D tiles and the 3D solids both rebuild from room.bgDirty,
# so one view must not clear the flag before the other has read it.

func before() -> void:
	TH.new_run(5)

func after() -> void:
	Run.reset()

func _room_view() -> Node2D:
	return load("res://world/room_view.gd").new()

func test_show_room_leaves_the_flag_for_the_3d_view() -> void:
	var room := TH.arena()
	room.bgDirty = true
	var rv := _room_view()
	rv.show_room(room)
	check(room.bgDirty, "the 2D view must not clear bgDirty: the 3D solids still need to rebuild")
	rv.free()

func test_show_room_drops_a_destroyed_rock() -> void:
	var room := TH.arena()
	room.grid[5][10] = Consts.T.CRACK
	var rv := _room_view()
	rv.show_room(room)
	check(rv.rocks.get_used_cells().has(Vector2i(10, 5)), "the cracked rock is drawn")
	room.grid[5][10] = Consts.T.FLOOR
	room.bgDirty = true
	rv.show_room(room)
	check(not rv.rocks.get_used_cells().has(Vector2i(10, 5)), "the broken rock is gone")
	rv.free()

func _verts(v: View3D) -> int:
	if v.solids.mesh == null or v.solids.mesh.get_surface_count() == 0:
		return 0
	return (v.solids.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

func test_the_3d_solids_drop_a_broken_rock() -> void:
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var v: View3D = play.get_node("View")
	Run.room.grid[7][14] = Consts.T.ROCK
	Run.room.bgDirty = true
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var with_rock := _verts(v)
	Run.room.grid[7][14] = Consts.T.FLOOR
	Run.room.bgDirty = true
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var without_rock := _verts(v)
	check(without_rock < with_rock, "the boulder is gone: %d < %d vertices" % [without_rock, with_rock])
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame

func test_play_clears_the_flag_after_the_views() -> void:
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	await (Engine.get_main_loop() as SceneTree).process_frame
	Run.room.bgDirty = true
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	check(not Run.room.get("bgDirty", false), "Play clears bgDirty once the views have rebuilt")
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame

func test_hd_tiles_draw_at_the_logical_size() -> void:
	# a 64 px tileset is scaled down to the 16 px grid
	var ts := TileSet.new()
	ts.tile_size = Vector2i(64, 64)
	TilePick._sets[DB.biome_of(Run.floor.depth).id] = ts
	var rv := _room_view()
	rv.show_room(TH.arena())
	eq(rv.floor_layer.scale, Vector2(0.25, 0.25))
	eq(rv.rocks.scale, Vector2(0.25, 0.25))
	TilePick._sets = {}
	rv.free()
