extends TestCase
# Avvio della run, ingresso nelle stanze, porte e transizioni, movimento del giocatore.

func before() -> void:
	TH.new_run(7)

func after() -> void:
	Controls.sim.clear()
	Run.reset()

func test_avvio_della_run() -> void:
	var p := Run.player
	eq(p.hp, p.stats.maxHp)
	eq(p.oil, p.stats.maxOil)
	eq(p.cons[0], {"id": "potion", "n": 1})
	eq(p.cons[1], {"id": "bomb", "n": 1})
	eq(Run.room.type, "start")
	check(Run.room.visited and Run.room.built)
	check(Run.room.get("tutorial", false))
	eq(Music.track_name, "crypt")
	eq(Run.toasts.back().text, "Trova il guardiano e scendi più in basso.")
	var runs: int = Save.data.stats.runs
	TH.new_run(8)
	eq(Save.data.stats.runs, runs + 1)

func test_ingresso_da_una_porta() -> void:
	var start := Run.room
	var d: String = start.doors.keys()[0]
	var n: Dictionary = start.doors[d]
	Flow.enter_room(n, d)
	check(is_same(Run.room, n))
	var e := RoomU.door_entry(RoomU.DIRS[d].opp)
	eq([Run.player.x, Run.player.y], [e.x, e.y])
	if n.type == "normal":
		check(n.combat, "stanza normale: combattimento")

func test_porta_aperta_e_transizione() -> void:
	var start := Run.room
	var d: String = start.doors.keys()[0]
	var dc := RoomU.door_center(d)
	var p := Run.player
	p.x = dc.x
	p.y = dc.y
	match d:
		"n":
			p.y = Consts.RY + 10
		"s":
			p.y = Consts.RY + (Consts.RH - 1) * Consts.TS + 6
		"w":
			p.x = Consts.RX + 10
		"e":
			p.x = Consts.RX + (Consts.RW - 1) * Consts.TS + 6
	Flow.check_doors(Consts.DT)
	check(Run.trans != null and Run.trans.kind == "room")
	for i in 9:
		Flow.update_trans(Consts.DT)
	check(is_same(Run.room, start.doors[d]), "dopo 0,13 s si cambia stanza")

func test_movimento_e_scatto() -> void:
	var p := Run.player
	var x0 := p.x
	Controls.sim = {"move": Vector2(1, 0)}
	p.tick(Consts.DT)
	near(p.x - x0, p.speed() * Consts.DT, 1e-6)
	Controls.sim = {"move": Vector2(1, 0), "pressed": ["dash"]}
	p.tick(Consts.DT)
	eq(p.dash_charges, 0)
	near(p.dash_t, 0.16 - Consts.DT, 1e-9)

func test_scena_di_gioco_si_avvia() -> void:
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	for i in 30:
		play.tick(Consts.DT)
	check(Run.player.get_parent() == play.get_node("World/Actors"))
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	check(Run.player.get_parent() == null, "il giocatore resta vivo dopo la scena")
