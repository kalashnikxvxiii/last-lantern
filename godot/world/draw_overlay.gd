extends Node2D
# Sovrimpressione visibile anche al buio (drawWorld in js/render.js): telegrafi, occhi,
# proiettili nemici, particelle alte, numeri fluttuanti, prompt d'interazione.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	_enemy_bullets()
	Particles.draw(self, true)
	Floaters.draw(self)

# drawEnemyBullets (js/render.js)
func _enemy_bullets() -> void:
	for b in Run.ebullets:
		var col := Bullets.color_of(b)
		if b.kind == "bone":
			var a: float = b.t * 14
			var dx := cos(a) * 3
			var dy := sin(a) * 3
			draw_line(Vector2(b.x - dx, b.y - dy), Vector2(b.x + dx, b.y + dy), UiDraw._a("#0b0810"), 4)
			draw_line(Vector2(b.x - dx, b.y - dy), Vector2(b.x + dx, b.y + dy), UiDraw._a("#e8e4dc"), 2)
			continue
		UiDraw.px_circle(self, b.x, b.y, b.r + 1, "#0b0810")
		UiDraw.px_circle(self, b.x, b.y, b.r, col)
		UiDraw.px_rect(self, b.x - 1, b.y - 1, 2, 2, "#140a1c" if b.kind == "void" else "#ffffff")
