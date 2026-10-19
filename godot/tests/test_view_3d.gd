extends TestCase
# Godot-only 3D view: the lifted 2D details hide behind the walls in front of them.

var v: View3D

func before() -> void:
	TH.new_run(7)
	v = View3D.new()
	v.place_camera(Vector2.ZERO, Vector2.ZERO)

func after() -> void:
	v.free()
	Fx.cam = Vector2.ZERO
	Run.reset()

func test_the_bottom_wall_hides_what_is_behind_it() -> void:
	var ty := Consts.RH - 2
	Run.room.grid[ty][5] = Consts.T.FLOOR
	Run.room.grid[ty + 1][5] = Consts.T.WALL
	var c := RoomU.tile_center(5, ty)
	check(v.hidden(Vector3(c.x, 6.0, c.y + 4.0)), "low, just behind the wall: hidden")
	check(not v.hidden(Vector3(c.x, 40.0, c.y)), "above the wall: seen")

func test_the_open_floor_hides_nothing() -> void:
	var c := RoomU.tile_center(14, 7)
	for ty in range(7, Consts.RH - 1):
		Run.room.grid[ty][14] = Consts.T.FLOOR
	check(not v.hidden(Vector3(c.x, 6.0, c.y)))

func test_lights_stay_out_of_the_walls() -> void:
	var ty := Consts.RH - 2
	Run.room.grid[ty][5] = Consts.T.FLOOR
	Run.room.grid[ty + 1][5] = Consts.T.WALL
	var c := RoomU.tile_center(5, ty)
	var p := v.light_pos(c.x, c.y + 6.0)
	check(p.z <= Consts.RY + (ty + 1) * Consts.TS - 4.0, "4 px in front of the wall, not inside it")
	check(p.y < View3D.WALL_H and p.y > View3D.ROCK_H, "held below the top of the walls, above the rocks")
	var q := v.light_pos(c.x, c.y - 32.0)
	near(q.z, c.y - 32.0, 1e-6, "in the open: right over its source, so shadows fall away from it")

func test_the_players_light_hangs_at_the_lantern() -> void:
	var L := Lights.collect()
	var o := Lighting.lantern_origin(Run.player)
	var p := v.light_at(L[0], L[0])
	near(p.x, o.x, 1e-6, "the sprites' shadows fall where the floor's do")
	var f := v.feet(Run.player.x, Run.player.y, 0.0, Spr.size("player").y)
	near(p.z, f.z + o.y - Run.player.y, 1e-6, "as far from the feet as the lantern is from the body")
	if L.size() > 1:
		near(v.light_at(L[1], L[0]).z, L[1].y, 1e-6, "the other lights hang over themselves")

func test_sprites_do_not_move_into_a_rock_in_front() -> void:
	for ty in range(7, Consts.RH - 1):
		Run.room.grid[ty][14] = Consts.T.FLOOR
	var c := RoomU.tile_center(14, 8)
	var open := Vector3(c.x, 0.0, c.y)
	eq(v.sprite_bias(open), View3D.SPRITE_BIAS, "open floor: the full bias")
	Run.room.grid[8][14] = Consts.T.ROCK
	# just behind the rock as seen from the camera
	var d := v.cam.position - open
	var away := -Vector2(d.x, d.z).normalized() * (View3D.ROCK_R + 1.0)
	var b := v.sprite_bias(Vector3(c.x + away.x, 0.0, c.y + away.y))
	check(b > 0.0 and b < View3D.SPRITE_BIAS, "stops at the rock: %s" % b)

func test_walls_and_rocks_become_a_mesh() -> void:
	Run.room.grid[7][14] = Consts.T.ROCK
	var m := v.build_solids(Run.room)
	check(m.get_surface_count() > 0, "the room has walls and a rock")

func test_the_tops_of_the_walls_use_the_cap_tiles() -> void:
	Run.floor.depth = 5
	var src := TilePick.tileset("heart").get_source(0) as TileSetAtlasSource
	var size := Vector2(src.texture.get_size())
	var caps: Array[Rect2] = []
	for i in 4:
		var r := src.get_tile_texture_region(TilePick.coords("heart", "wall_cap_%d" % i))
		caps.append(Rect2(Vector2(r.position) / size, Vector2(r.size) / size).grow(1e-4))
	var a := v.build_solids(Run.room).surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var tops := 0
	for i in range(0, verts.size(), 3):
		if verts[i].y == View3D.WALL_H and verts[i + 1].y == View3D.WALL_H and verts[i + 2].y == View3D.WALL_H:
			tops += 1
			for k in 3:
				check(caps.any(func(c: Rect2) -> bool: return c.has_point(uvs[i + k])), "top face uv %s" % uvs[i + k])
	check(tops > 0, "the room has wall tops")

func test_no_sprite_for_the_dead_or_spawning() -> void:
	var p := Run.player
	check(not p.sprite_state().is_empty())
	p.dead = true
	eq(p.sprite_state(), {})
	p.dead = false
	var e := TH.spawn("rat", 100.0, 100.0)
	e.spawning = true
	eq(e.sprite_state(), {})

func test_leaving_the_3d_view_restores_the_rest() -> void:
	View3D.on = true
	View3D.current = v
	View3D.items = [{}]
	Controls.to_world = Callable(v, "screen_to_floor")
	Display.environment().background_canvas_max_layer = 1
	v._exit_tree()
	check(not View3D.on)
	eq(View3D.current, null)
	eq(View3D.items, [])
	check(not Controls.to_world.is_valid(), "the aim stops using the 3D floor")
	eq(Display.environment().background_canvas_max_layer, 1000, "every canvas layer shows again")

func test_an_error_while_drawing_does_not_leave_the_capture_on() -> void:
	Spr.capture = []   # as if a previous _draw stopped halfway
	var g := DrawGround.new()
	Run.active = false   # _draw returns early
	g._draw()
	Run.active = true
	g.free()
	eq(Spr.capture, null)

# screen height of a point, as seen by the camera (larger: higher on the screen)
func _screen_y(p: Vector3) -> float:
	var l := v.cam.transform.affine_inverse() * p
	return l.y / -l.z

func test_a_shop_item_shows_above_its_pedestal() -> void:
	var x := 240.0
	var y := 120.0
	var g := {"ground": y + 8}
	View3D.items = [
		{"name": "pedestal", "frame": 0, "x": x, "y": y + 4, "o": {}},
		{"name": "heart", "frame": 0, "x": x, "y": y - 8, "o": g},
	]
	v._sync_items()
	var ped_top: Vector3 = v.item_pool[0].position + v.cam.basis.y * Spr.size("pedestal").y
	var item_bottom: Vector3 = v.item_pool[1].position
	check(_screen_y(item_bottom) > _screen_y(ped_top), "the item floats above the pedestal, not over it")
	View3D.items = []

func test_gates_sink_into_the_floor_when_the_doors_open() -> void:
	var room := Run.room
	room.doors = {"n": {"type": "normal"}}
	room.cleared = false
	Run.player.x = 100.0   # far from the door
	v.build_gates(room, true)
	var g: MeshInstance3D = v.gates["n"]
	eq(g.position.y, 0.0, "closed: up like the walls")
	room.cleared = true
	v.sync_gates(0.1)
	check(g.position.y < 0.0 and g.visible, "open: sinking, not gone at once")
	v.sync_gates(1.0)
	eq(g.position.y, -View3D.WALL_H, "under the floor")
	check(not g.visible)
	v.build_gates(room, true)
	eq(v.gates["n"].position.y, -View3D.WALL_H, "a room entered open: already down")

func test_the_gate_behind_the_player_closes_after_them() -> void:
	var room := Run.room
	room.doors = {"n": {"type": "normal"}, "s": {"type": "normal"}}
	room.cleared = false
	var pos := RoomU.door_entry("s")
	Run.player.x = pos.x
	Run.player.y = pos.y
	v.build_gates(room, true)
	eq(v.gates["n"].position.y, 0.0, "the others: already closed")
	eq(v.gates["s"].position.y, -View3D.WALL_H, "the way in: still open")
	v.sync_gates(0.1)
	check(v.gates["s"].position.y > -View3D.WALL_H, "and rising")
	v.build_gates(room, false)
	eq(v.gates["s"].position.y, 0.0, "a rebuild inside the room: no entry")

func test_the_rooms_beyond_the_doors_stand_unlit_next_to_this_one() -> void:
	var room := Run.room
	var offered: Dictionary = Run.offered_relics.duplicate()
	v.build_neighbors(room)
	for d in room.doors:
		if not RoomU.door_visible(room, d):
			check(not v.neighbors.has(d), "%s: a hidden door shows nothing" % d)
			continue
		var n: MeshInstance3D = v.neighbors[d]
		var off := RoomU.room_offset(d)
		eq(Vector2(n.position.x, n.position.z), off, "%s: right beyond the wall" % d)
		eq(n.layers, View3D.NEIGHBOR_LAYER)
		check((n.mesh.surface_get_material(0) as StandardMaterial3D).disable_ambient_light, "dark until a light reaches it")
		check(not room.doors[d].built, "%s: only laid out, not built" % d)
	eq(Run.offered_relics, offered, "laying out draws no relics")

func test_a_laid_out_room_has_the_grid_it_will_be_built_with() -> void:
	var r: Dictionary = Run.floor.rooms.filter(func(x): return not x.built)[0]
	var g: Array = RoomBuilder.layout_of(r).grid
	RoomBuilder.build_room(r, Run.floor)
	eq(g, r.grid)

func test_the_camera_eases_into_the_next_room() -> void:
	var room := Run.room
	var d: String = room.doors.keys()[0]
	Fx.cam = Vector2(0, -10)
	var target := Fx.cam_target(Run.player.x, Run.player.y)
	v.start_pan(room, room.doors[d])
	# the follow's own jump (the player is now at the other side of the room) is part of the move
	var from := RoomU.room_offset(RoomU.DIRS[d].opp) + Vector2(0, -10) - target
	eq(Fx.cam, target, "the follow is where it wants to be")
	eq(v.pan_offset(), from, "the camera starts where it was, over the room left behind")
	v.pan_t = View3D.PAN_TIME * 0.1
	check(v.pan_offset().length() > from.length() * 0.98, "ease in: a gentle start")
	v.pan_t = View3D.PAN_TIME / 2.0
	near(v.pan_offset().length(), from.length() * 0.5, 1e-3, "halfway at half time")
	v.pan_t = View3D.PAN_TIME * 0.9
	check(v.pan_offset().length() < from.length() * 0.02, "ease out: a soft landing")
	v.pan_t = View3D.PAN_TIME
	eq(v.pan_offset(), Vector2.ZERO)
	v.start_pan({}, room)
	eq(v.pan_offset(), Vector2.ZERO, "from elsewhere (a new floor): no move")
	Fx.cam = Vector2.ZERO

func test_the_lights_change_rooms_with_the_camera() -> void:
	View3D.current = v
	var room := Run.room
	var d: String = room.doors.keys()[0]
	var next: Dictionary = room.doors[d]
	RoomBuilder.build_room(next, Run.floor)
	Run.room = next
	v.start_pan(room, next)
	v.build_neighbors(next)
	eq(View3D.reveal(), 0.0, "entering: the new room's ambient light is still off")
	var back: MeshInstance3D = v.neighbors[RoomU.DIRS[d].opp]
	var m := back.mesh.surface_get_material(0) as StandardMaterial3D
	v.fade_left_room(1.0)
	near(m.emission_energy_multiplier, 1.0, 1e-6, "the room left behind keeps its light")
	v.pan_t = View3D.PAN_TIME / 2.0
	v.fade_left_room(1.0)
	near(View3D.reveal(), 0.5, 1e-3)
	near(m.emission_energy_multiplier, 0.5, 1e-3, "and loses it as the camera moves away")
	v.pan_t = View3D.PAN_TIME
	v.fade_left_room(1.0)
	eq(View3D.reveal(), 1.0)
	eq(m.emission_energy_multiplier, 0.0, "dark once the camera has arrived")
	View3D.current = null

func test_the_shots_plane_reaches_over_the_rooms_next_door() -> void:
	var r := View3D.air_view()
	for d in RoomU.DIRS:
		var c := RoomU.door_center(d) + Vector2(RoomU.DIRS[d].dx, RoomU.DIRS[d].dy) * Consts.TS * 3.0
		check(r.has_point(c), "%s: a shot three tiles past the door still drawn" % d)

func test_the_shadows_come_from_the_big_lights_nearest_the_player() -> void:
	var b := func(x: float, r: float) -> Dictionary: return {"x": x, "y": 100.0, "r": r, "a": 0.95}
	var L: Array = [b.call(400.0, 72.0), b.call(300.0, 74.0), b.call(10.0, 20.0), b.call(60.0, 69.0), b.call(500.0, 75.0), {"x": 0.0, "y": 98.0, "r": 60.0, "a": 1.0}]
	View3D.sort_lights(L, 0.0, 100.0)
	eq(L.map(func(l): return l.x), [0.0, 60.0, 300.0, 400.0, 500.0, 10.0], "near first among those that cast shadows; the small ones after")

func test_lights_as_near_or_as_strong_keep_one_order() -> void:
	var b := func(x: float, y: float, r: float) -> Dictionary: return {"x": x, "y": y, "r": r, "a": 0.95}
	var L: Array = [b.call(-50.0, 0.0, 72.0), b.call(50.0, 0.0, 72.0), b.call(0.0, -50.0, 72.0), b.call(0.0, 50.0, 72.0), b.call(9.0, 0.0, 20.0), b.call(-9.0, 0.0, 20.0)]
	var order := []
	for i in 6:
		if i % 2 == 0:
			L.reverse()
		else:
			L.push_back(L.pop_front())
		View3D.sort_lights(L, 0.0, 0.0)
		order.append(L.map(func(l): return Vector2(l.x, l.y)))
	for o in order:
		eq(o, order[0], "the same order however they come: no swapped shadows between frames")

func test_actors_cast_an_upright_shadow_toward_each_light_that_casts_shadows() -> void:
	var p := Run.player
	p.aim = 0.0   # the lantern on the right
	Run.room.grid[3][3] = Consts.T.BRAZIER   # a second light, from another side
	v._make_lights()
	v._sync_lights()
	v._sync_sprites()
	var id := p.get_instance_id()
	var s: Sprite3D = v.sprites[id]
	eq(s.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the billboard leans back: its shadow would be flat")
	var cs: Array = v.casters[id]
	eq(cs.size(), View3D.SHADOW_LIGHTS, "one copy per light that casts shadows")
	var lit := 0
	for i in cs.size():
		var c: Sprite3D = cs[i]
		var l: OmniLight3D = v.lights[i]
		eq(c.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "an unseen upright copy casts it")
		eq(c.billboard, BaseMaterial3D.BILLBOARD_DISABLED)
		eq(c.layers, View3D.CASTER_LAYER << i)
		for j in cs.size():
			eq(bool(v.lights[j].shadow_caster_mask & c.layers), i == j, "light %d casts only its own copy's shadow" % j)
		check(bool(l.shadow_caster_mask & 1), "and the room's")
		eq(c.visible, l.visible, "no light, no shadow")
		if not l.visible:
			continue
		lit += 1
		var n := c.basis.z
		near(n.y, 0.0, 1e-5, "upright")
		var to := Vector3(l.position.x - c.position.x, 0, l.position.z - c.position.z).normalized()
		check(n.dot(to) > 0.999, "%d: facing its light" % i)
		near(c.scale.x, s.scale.x * View3D.CASTER_SCALE.x, 1e-5, "slimmer than the body")
		near(c.scale.y, s.scale.y * View3D.CASTER_SCALE.y, 1e-5, "under the lantern: the shadow stays short")
	check(lit >= 2, "the lantern and the brazier")
	var e := TH.spawn("rat", p.x + 40, p.y)
	v._sync_sprites()
	var ec: Sprite3D = v.casters[e.get_instance_id()][0]
	eq(ec.scale, (v.sprites[e.get_instance_id()] as Sprite3D).scale, "an enemy's shadow keeps its full size")
	p.dead = true
	v._sync_sprites()
	check(not v.casters.has(id), "gone with its actor")

func test_behind_the_rooms_there_is_only_black() -> void:
	v._ready()
	eq(v.env.background_mode, Environment.BG_COLOR)
	eq(v.env.background_color, Color.BLACK)
	eq(Display.environment().background_canvas_max_layer, 1, "the HUD layers stay in front of the room")
	v._exit_tree()
