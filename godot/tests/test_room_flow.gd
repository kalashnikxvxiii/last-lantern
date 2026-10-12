extends TestCase
# Ondate, stanza ripulita, porte che si aprono, ricompense.

func after() -> void:
	Run.reset()

func test_ondata_compare_e_la_stanza_si_ripulisce() -> void:
	TH.new_run(41)
	var room := TH.enter("normal")
	check(room.combat)
	for i in 70:
		Run.player.inv = 99.0
		Flow.update_game(Consts.DT)
	check(not Run.enemies.is_empty(), "prima ondata comparsa")
	room.waveIdx = room.waves.size()   # niente altre ondate
	for i in 180:
		Run.player.inv = 99.0
		for e in Run.enemies.duplicate():
			Combat.kill_enemy(e)
		Run.prune_enemies()
		Flow.update_game(Consts.DT)
	check(room.cleared and not room.combat)
	eq(Run.rooms_cleared, 1)
	var d: String = room.doors.keys()[0]
	check(RoomU.door_open(room, d) or RoomU.door_locked(room, d))
