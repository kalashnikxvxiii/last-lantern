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

# the static caches hold GPU resources: they are released on quit, while the renderer is still up
func test_quit_releases_static_caches() -> void:
	Spr.ensure()
	Display.environment()
	Game.release_caches()
	check(Spr.db.is_empty(), "sprites")
	check(Display._env == null, "environment")
	check(UiDraw._glow_tex == null, "glow texture")
	check(Txt._atlas == null, "font atlas")
	Spr.ensure()   # the other tests draw again
