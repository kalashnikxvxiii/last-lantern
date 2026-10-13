extends Screen
# Options from the title (Scenes.options in js/game.js).

var options: OptionsMenu

func enter() -> void:
	options = OptionsMenu.new(func(): Game.set_scene("title"))

func update(_dt: float) -> void:
	if Controls.back():
		Game.set_scene("title")
		return
	options.update()

func paint() -> void:
	options.draw(self)
