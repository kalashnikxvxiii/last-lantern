extends TestCase
# Error bar: only errors, not warnings.

func after() -> void:
	Game.error = ""

func test_warnings_are_not_errors() -> void:
	allow_errors()
	Game.error = ""
	push_warning("test warning")
	eq(Game.error, "")
	push_error("test error")
	check(Game.error != "", "a real error must be shown")
