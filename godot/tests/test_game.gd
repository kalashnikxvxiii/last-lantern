extends TestCase
# Barra degli errori: solo errori, non avvisi.

func after() -> void:
	Game.error = ""

func test_gli_avvisi_non_sono_errori() -> void:
	allow_errors()
	Game.error = ""
	push_warning("avviso di prova")
	eq(Game.error, "")
	push_error("errore di prova")
	check(Game.error != "", "un errore vero va mostrato")
