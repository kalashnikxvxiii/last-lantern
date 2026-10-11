extends TestCase
# Verifica gli strumenti di test stessi.

func test_eq_tolera_int_e_float() -> void:
	eq(3, 3.0)
	eq({"a": [1, 2.0, {"b": true}]}, {"a": [1.0, 2, {"b": true}]})

func test_eq_rileva_differenze() -> void:
	check(TestCase.diff([1, 2], [1, 3], "x") != "", "deve rilevare elementi diversi")
	check(TestCase.diff({"a": 1}, {"a": 1, "b": 2}, "x") != "", "deve rilevare chiavi mancanti")
	check(TestCase.diff(1.0, 1.0 + 1e-12, "x") == "", "tolleranza numerica")
