extends Node
# Boot scene: leaves the choice of the first screen to Game.

func _ready() -> void:
	Game.boot.call_deferred()
