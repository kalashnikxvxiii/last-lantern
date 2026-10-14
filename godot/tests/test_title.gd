extends TestCase
# Title menu: the Godot-only Quit entry asks for a second press.
# The screen is never added to the tree and the second press is never sent:
# it would quit the test runner.

var sc: Node

func before() -> void:
	sc = load(Game.SCENES.title).instantiate()
	sc.enter()

func after() -> void:
	Controls.sim.clear()
	sc.free()
	Run.reset()

func _press(a: String) -> void:
	Controls.sim = {"pressed": [a]}
	sc.update(Consts.DT)
	Controls.sim.clear()

func test_quit_asks_first() -> void:
	var m: Menu = sc.menu
	m.sel = m.items.size() - 1
	eq(Menu.label_of(m.current()), "Quit the game")
	_press("confirm")
	check(sc.confirm_quit)
	eq(Menu.label_of(m.current()), "Sure? Press again to quit")
	_press("nav_up")
	check(not sc.confirm_quit, "moving away cancels the confirmation")
	_press("nav_down")
	eq(Menu.label_of(m.current()), "Quit the game")
