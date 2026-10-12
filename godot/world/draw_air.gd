extends Node2D
# Above the actors and below the light (drawWorld in js/render.js): player projectiles,
# low particles, airborne effects.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	_player_bullets()
	Particles.draw(self, false)
	_air_fx()

# drawPlayerBullets (js/render.js)
func _player_bullets() -> void:
	for b in Run.bullets:
		if b.kind == "comet":
			UiDraw.px_circle(self, b.x, b.y, b.r + 1, "#0b0810")
			UiDraw.px_circle(self, b.x, b.y, b.r, "#7fd8e6")
			UiDraw.px_circle(self, b.x, b.y, b.r - 1.5, "#ffffff")
		elif b.kind == "shard":
			UiDraw.px_rect(self, b.x - 1, b.y - 1, 2, 2, "#f6cf57")
		else:
			var r: float = b.r + (0.6 if b.crit else 0.0)
			UiDraw.px_circle(self, b.x, b.y, r + 0.7, "#fff2a8" if b.crit else "#b5571f")
			UiDraw.px_circle(self, b.x, b.y, r - 0.3, "#ffffff" if b.crit else "#f29c38")
			UiDraw.px_rect(self, b.x - 1, b.y - 1, 2, 2, "#fff2a8")

# drawAirFx (js/render.js)
func _air_fx() -> void:
	var ga := UiDraw.alpha
	for f in Run.fx:
		if f.get("delay", 0.0) > 0:
			continue
		var k: float = f.t / f.life
		match f.type:
			"explosion":
				var r: float = f.r * (0.4 + 0.6 * minf(1, k * 3))
				UiDraw.alpha = 1 - k
				UiDraw.px_circle(self, f.x, f.y, r, "#fff2a8" if k < 0.3 else "#f29c38")
				UiDraw.alpha = (1 - k) * 0.7
				UiDraw.px_circle(self, f.x, f.y, r * 0.6, "#ffffff" if k < 0.3 else "#f6cf57")
			"flare":
				UiDraw.alpha = 1 - k
				UiDraw.px_ring(self, f.x, f.y, f.r * (0.3 + k * 0.9), "#fff2a8", 3)
				UiDraw.px_ring(self, f.x, f.y, f.r * (0.2 + k * 0.7), "#f29c38", 2)
			"shockwave":
				UiDraw.alpha = maxf(0, 1 - f.r / f.maxR)
				var col := "#f29c38" if f.owner == "player" else ("#a24ab8" if f.owner == "visual" else "#e8e4dc")
				UiDraw.px_ring(self, f.x, f.y, f.r, col, 3)
			"bolt":
				UiDraw.alpha = 1 - k
				var pts := PackedVector2Array()
				for i in f.pts.size():
					var pt: Array = f.pts[i]
					if i > 0:
						var pv: Array = f.pts[i - 1]
						for j in range(1, 4):
							pts.append(Vector2(lerpf(pv[0], pt[0], j / 4.0) + Fx.vrnd(-4, 4), lerpf(pv[1], pt[1], j / 4.0) + Fx.vrnd(-4, 4)))
					pts.append(Vector2(pt[0], pt[1]))
				if pts.size() > 1:
					draw_polyline(pts, UiDraw._a("#c8f2f5"), 2)
					draw_polyline(pts, UiDraw._a("#ffffff"), 1)
		UiDraw.alpha = ga
