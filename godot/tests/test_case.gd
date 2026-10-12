class_name TestCase
extends RefCounted
# Test base: assertions with deep comparison and numeric tolerance.

var failures: Array[String] = []
var errors_allowed := false

func before() -> void:
	pass

func after() -> void:
	pass

func allow_errors() -> void:
	errors_allowed = true

func fail(msg: String) -> void:
	failures.append(msg)

func check(cond: bool, msg: String = "condition false") -> void:
	if not cond:
		fail(msg)

func eq(a: Variant, b: Variant, msg: String = "") -> void:
	var d := TestCase.diff(a, b, "")
	if d != "":
		fail((msg + ": " if msg != "" else "") + d)

func near(a: float, b: float, eps: float = 1e-9, msg: String = "") -> void:
	if absf(a - b) > eps * maxf(1.0, absf(b)):
		fail("%s expected %s, got %s" % [msg, b, a])

static func _num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

# "" if equal, otherwise the description of the first difference.
static func diff(a: Variant, b: Variant, path: String) -> String:
	if _num(a) and _num(b):
		var fa := float(a)
		var fb := float(b)
		if absf(fa - fb) <= 1e-9 * maxf(1.0, absf(fb)):
			return ""
		return "%s: %s != %s" % [path, fa, fb]
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s: length %d != %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	if a is Dictionary and b is Dictionary:
		for k in b:
			if not a.has(k):
				return "%s.%s: missing key" % [path, k]
		for k in a:
			if not b.has(k):
				return "%s.%s: extra key" % [path, k]
			var d := diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		return ""
	if typeof(a) != typeof(b) or a != b:
		return "%s: %s != %s" % [path, a, b]
	return ""

static func golden(name: String) -> Variant:
	var txt := FileAccess.get_file_as_string("res://tests/golden/%s.json" % name)
	var j := JSON.new()
	if j.parse(txt) != OK:
		push_error("golden %s not readable" % name)
		return null
	return j.data
