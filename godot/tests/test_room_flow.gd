extends TestCase
# Waves, cleared room, opening doors, rewards.

func after() -> void:
	Run.reset()

func test_wave_appears_and_the_room_clears() -> void:
	TH.new_run(41)
	var room := TH.enter("normal")
	check(room.combat)
	for i in 70:
		Run.player.inv = 99.0
		Flow.update_game(Consts.DT)
	check(not Run.enemies.is_empty(), "first wave appeared")
	room.waveIdx = room.waves.size()   # no more waves
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
