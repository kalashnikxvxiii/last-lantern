class_name TH
extends RefCounted
# Aiuti per i test di gioco senza scena.

static func new_run(seed: int = 7, lantern: String = "custode") -> void:
	U.seed_random(seed)
	Flow.start_run(lantern, 0, seed)

static func room_of(type: String) -> Dictionary:
	for r in Run.floor.rooms:
		if r.type == type:
			return r
	return {}

static func enter(type: String) -> Dictionary:
	var r := room_of(type)
	Flow.enter_room(r, null)
	return r

# stanza di combattimento senza ondate: le porte restano chiuse finché vive un nemico
static func arena() -> Dictionary:
	var r := enter("normal")
	r.waves = []
	r.combat = true
	return r

static func ticks(n: int) -> void:
	for i in n:
		Flow.update_common(Consts.DT)
		Flow.update_game(Consts.DT)
		Controls.end_tick()
