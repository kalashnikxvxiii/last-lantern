extends TestCase
# Godot-only camera that leans toward the player, and the fake height of walls and rocks.

func before() -> void:
	Fx.reset()
	Controls.sim = {}

func after() -> void:
	Fx.reset()
	Controls.sim = {}

func test_camera_target_is_clamped() -> void:
	eq(Fx.cam_target(Fx.VIEW_C.x, Fx.VIEW_C.y), Vector2.ZERO, "player in the middle: no lean")
	eq(Fx.cam_target(1000, -1000), Vector2(-Fx.CAM_MAX, Fx.CAM_MAX), "never more than CAM_MAX")
	var t: Vector2 = Fx.cam_target(Fx.VIEW_C.x + 50, Fx.VIEW_C.y)
	check(t.x < 0 and t.x > -Fx.CAM_MAX and t.y == 0, "the room moves the other way")

func test_follow_eases_and_feeds_the_offset() -> void:
	Fx.follow(1000, 1000, 10.0)
	near(Fx.cam.x, -Fx.CAM_MAX, 1e-6)
	eq(Fx.offset(), Fx.cam_px(), "no shake: the offset is the camera")

func test_aim_ignores_the_camera() -> void:
	Fx.cam = Vector2(-6, 0)
	Controls.sim = {"device": "mouse", "mouse": Vector2(294, 100)}
	near(Controls.aim_angle(100, 104, 1.5), 0.0, 1e-9, "aims where the mouse points in the room")

func test_tops_lean_away_from_the_eye() -> void:
	var eye: Vector2 = Fx.VIEW_C
	eq(RoomView.lift(eye.x, eye.y, eye), Vector2.ZERO, "under the eye: no side faces")
	var l: Vector2 = RoomView.lift(Consts.RX + 8.0, eye.y, eye)
	check(l.x < 0 and l.y == 0, "left wall leans left, its inner face shows")
	eq(l.x, roundf(l.x), "whole pixels")
	check(RoomView.lift(Consts.RX + 8.0, eye.y, eye - Vector2(50, 0)).x > l.x, "closer eye, smaller face")
