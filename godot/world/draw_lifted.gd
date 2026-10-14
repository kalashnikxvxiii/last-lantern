class_name DrawLifted
extends Node2D
# Godot-only, with the 3D view: the details that belong to standing things (eyes,
# health bars, flames, the lantern, floating numbers, prompts), drawn on the screen
# above the 3D room by the same 2D code, moved to where the 3D view shows each anchor.
# The picture adjustments reach them through shaders/picture.gdshader, not the HUD.

func _ready() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/picture.gdshader")
	material = m

func _process(_delta: float) -> void:
	var s: Dictionary = Save.data.settings
	(material as ShaderMaterial).set_shader_parameter("bcs", Vector3(s.brightness, s.contrast, s.saturation))
	queue_redraw()

func _draw() -> void:
	var v := View3D.current
	if v == null or not Run.active or Run.room.is_empty():
		return
	var room := Run.room
	var tt := Fx.time
	var ga := UiDraw.alpha
	# flames of braziers and altars, the merchant's lantern
	var bh := Spr.size("brazier").y / 2.0
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			if room.grid[ty][tx] == Consts.T.BRAZIER:
				var cx: float = Consts.RX + tx * Consts.TS + 8
				var cy: float = Consts.RY + ty * Consts.TS + 8
				if v.hidden(Vector3(cx, bh * 2, cy + 2 + bh)):   # the flame on top, behind a wall
					continue
				_on_floor(v, cx, cy + 2 + bh)
				UiDraw.flame(self, cx, cy - 3, 1, tt)
	for o in room.objects:
		if o.get("gone", false):
			continue
		if o.type == "shrine" and o.uses > 0 and not (o.kind == "fortune" or o.kind == "fountain"):
			_on_floor(v, o.x, o.y + Spr.size("altar").y / 2.0)
			UiDraw.flame(self, o.x, o.y - 10, 1, tt)
		elif o.type == "merchant":
			_on_floor(v, o.x, o.y + Spr.size("merchant").y / 2.0)
			DrawGround.merchant_lantern(self, o)
	# actors: what the 2D drawing puts on them
	for e in Run.enemies:
		if not is_instance_valid(e) or e.dead or e.spawning or not Spr.has(e._spr_name()):
			continue
		var h := Spr.size(e._spr_name()).y / 2.0
		var base := v.feet(e.x, e.y, e.z, h * 2)
		if v.hidden(v.sprite_mid(base, h * 2)):   # behind a wall or a rock
			continue
		_at(v, Vector2(e.x, e.y - e.z + h), base)
		e.draw_extras(self)
		DrawOverlay.eye(self, e)
		DrawOverlay.warn_spark(self, e)
	var p := Run.player
	if p != null and not p.dead:
		var h := Spr.size("player").y / 2.0
		var base := v.feet(p.x, p.y, 0.0, h * 2)
		if not v.hidden(v.sprite_mid(base, h * 2)):   # behind a wall or a rock
			_at(v, Vector2(p.x, p.y + h), base)
			UiDraw.alpha = p.sprite_state().o.alpha
			if not p.lantern_behind():   # behind the body it is hidden
				p.draw_lantern(self)
			UiDraw.alpha = ga
			p.draw_orbitals(self)
	# floating numbers and panels, at their point of the floor
	Floaters.draw(self, func(x: float, y: float) -> void: _on_floor(v, x, y))
	if Run.focus != null:
		_on_floor(v, Run.focus.x, Run.focus.y)
		DrawOverlay.prompt(self)
	for o in room.objects:
		_on_floor(v, o.x, o.y)
		DrawOverlay.bubble(self, o)
	UiDraw.set_origin(self, Vector2.ZERO)

# from here the 2D point at2d is drawn where the 3D view shows p3
func _at(v: View3D, at2d: Vector2, p3: Vector3) -> void:
	UiDraw.set_origin(self, v.project(p3) - at2d)

func _on_floor(v: View3D, x: float, y: float) -> void:
	_at(v, Vector2(x, y), Vector3(x, 0, y))
