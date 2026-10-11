extends Node
# Scena di avvio: lascia a Game la scelta della prima schermata.

func _ready() -> void:
	Game.boot.call_deferred()
