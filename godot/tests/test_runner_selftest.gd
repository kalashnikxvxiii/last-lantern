extends TestCase
# Checks the test tools themselves.

func test_eq_tolerates_int_and_float() -> void:
	eq(3, 3.0)
	eq({"a": [1, 2.0, {"b": true}]}, {"a": [1.0, 2, {"b": true}]})

func test_eq_detects_differences() -> void:
	check(TestCase.diff([1, 2], [1, 3], "x") != "", "must detect different elements")
	check(TestCase.diff({"a": 1}, {"a": 1, "b": 2}, "x") != "", "must detect missing keys")
	check(TestCase.diff(1.0, 1.0 + 1e-12, "x") == "", "numeric tolerance")
