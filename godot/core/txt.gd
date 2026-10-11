class_name Txt
extends RefCounted
# Font bitmap (js/font.js): glifi, misura e a capo dei testi con i codici colore ^x.

const LINE := 10
static var COLORS := {
	"w": Color("#ece6d8"), "y": Color("#f6cf57"), "r": Color("#e0574a"), "g": Color("#8fd35a"),
	"b": Color("#6fa8e8"), "o": Color("#f29c38"), "p": Color("#c57ae0"), "d": Color("#8a8294"),
	"c": Color("#7fd8e6"), "s": Color("#b8b2c2"), "k": Color("#0d0a12"),
}
static var glyphs: Dictionary = {}   # carattere -> [x nell'atlas, larghezza]
static var _atlas: Texture2D

static func ensure() -> void:
	if not glyphs.is_empty():
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://assets/font/glyphs.json")) != OK:
		push_error("glyphs.json non leggibile")
		return
	glyphs = j.data

static func atlas() -> Texture2D:
	if _atlas == null:
		_atlas = load("res://assets/font/lanterna.png")
	return _atlas

# ripiego del JS: maiuscola/minuscola, poi il punto interrogativo
static func glyph(ch: String) -> Array:
	ensure()
	if glyphs.has(ch):
		return glyphs[ch]
	var up := ch.to_upper()
	if glyphs.has(up):
		return glyphs[up]
	var lo := ch.to_lower()
	if glyphs.has(lo):
		return glyphs[lo]
	return glyphs["?"]

# larghezza ignorando i codici colore
static func width(s: String, scale: float = 1.0) -> float:
	var w := 0.0
	var n := 0
	var i := 0
	while i < s.length():
		var ch := s[i]
		if ch == "^":
			i += 2
			continue
		if ch == " ":
			w += 3
		else:
			w += float(glyph(ch)[1])
		n += 1
		i += 1
	return (w + maxi(0, n - 1)) * scale

static func _last_code(word: String) -> String:
	var res := ""
	var i := 0
	while i < word.length():
		if word[i] == "^" and i + 1 < word.length():
			res = word[i + 1]
			i += 2
		else:
			i += 1
	return res

# a capo automatico, preserva i codici colore tra le righe
static func wrap(s: String, max_w: float, scale: float = 1.0) -> Array:
	var out: Array = []
	for para in s.split("\n"):
		var line := ""
		var last_code := ""
		for word in para.split(" "):
			var test: String = line + " " + word if line != "" else word
			if width(test, scale) > max_w and line != "":
				out.append(line)
				line = ("^" + last_code if last_code != "" else "") + word
			else:
				line = test
			var code := _last_code(word)
			if code != "":
				last_code = code
		out.append(line)
	return out
