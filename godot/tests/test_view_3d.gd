extends TestCase
# Godot-only 3D view: the lifted 2D details hide behind the walls in front of them.

var v: View3D

func before() -> void:
	TH.new_run(7)
	v = View3D.new()
	v.place_camera(Vector2.ZERO, Vector2.ZERO)

func after() -> void:
	v.free()
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
	var p := v.light_pos(c.x, c.y)
	check(p.z > c.y, "still a bit toward the camera")
	check(p.z <= Consts.RY + (ty + 1) * Consts.TS - 4.0, "but 4 px in front of the wall, not inside it")
	var q := v.light_pos(c.x, c.y - 32.0)
	near(q.z, c.y - 32.0 + 12.0, 1e-6, "in the open: the full offset")
