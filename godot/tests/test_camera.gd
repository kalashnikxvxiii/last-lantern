extends TestCase
# Godot-only 3D view: the camera that follows the player and the mouse on the floor.

func before() -> void:
	Fx.reset()
	Controls.sim = {}

func after() -> void:
	Fx.reset()
	Controls.sim = {}
	Controls.to_world = Callable()

func test_camera_target_is_clamped() -> void:
	eq(Fx.cam_target(Fx.VIEW_C.x, Fx.VIEW_C.y), Vector2.ZERO, "player in the middle: camera in the middle")
	eq(Fx.cam_target(1000, -1000), Vector2(Fx.CAM_MAX.x, -Fx.CAM_MAX.y), "never more than CAM_MAX")
	var t: Vector2 = Fx.cam_target(Fx.VIEW_C.x + 50, Fx.VIEW_C.y)
	check(t.x > 0 and t.x < Fx.CAM_MAX.x and t.y == 0, "the camera goes toward the player")

func test_follow_eases() -> void:
	Fx.follow(1000, 1000, 1.0 / 60)
	check(Fx.cam.x > 0 and Fx.cam.x < Fx.CAM_MAX.x, "one frame: part of the way")
	Fx.follow(1000, 1000, 10.0)
	near(Fx.cam.x, Fx.CAM_MAX.x, 1e-3)
	eq(Fx.offset(), Vector2.ZERO, "the camera is not part of the shake offset")

func test_aim_at_the_floor_under_the_mouse() -> void:
	Controls.sim = {"device": "mouse", "mouse": Vector2(0, 0)}
	Controls.to_world = func(_m: Vector2) -> Vector2: return Vector2(300, 100)
	near(Controls.aim_angle(100, 104, 1.5), 0.0, 1e-9, "aims at the projected point")

func test_view_projects_the_mouse_on_the_floor() -> void:
	var v := View3D.new()
	Engine.get_main_loop().root.add_child(v)
	v.place_camera(Vector2.ZERO, Vector2.ZERO)
	var p := v.screen_to_floor(Vector2(Consts.W, Consts.H) / 2.0)
	v.free()
	check(absf(p.x - Fx.VIEW_C.x) < 40 and absf(p.y - Fx.VIEW_C.y) < 40, "the middle of the screen looks at the room: %s" % p)

func test_project_and_back() -> void:
	var v := View3D.new()
	Engine.get_main_loop().root.add_child(v)
	v.place_camera(Vector2.ZERO, Vector2.ZERO)
	var s := v.project(Vector3(100, 0, 200))
	var p := v.screen_to_floor(s)
	v.free()
	near(p.x, 100, 0.01)
	near(p.y, 200, 0.01)

func test_standing_sprites_are_recorded_not_drawn() -> void:
	var n := Node2D.new()
	Spr.capture = []
	UiDraw.alpha = 0.5
	Spr.draw(n, "barrel", 0, 50, 60, {"ground": 70})
	UiDraw.alpha = 1.0
	var got: Array = Spr.capture
	Spr.capture = null
	n.free()
	eq(got.size(), 1)
	eq(got[0].name, "barrel")
	eq(got[0].o.ground, 70)
	near(got[0].alpha, 0.5)
