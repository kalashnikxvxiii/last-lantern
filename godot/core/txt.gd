class_name Txt
extends RefCounted
# Bitmap font (js/font.js): glyphs, text measuring and wrapping with ^x color codes.

const LINE := 10
static var COLORS := {
	"w": Color("#ece6d8"), "y": Color("#f6cf57"), "r": Color("#e0574a"), "g": Color("#8fd35a"),
	"b": Color("#6fa8e8"), "o": Color("#f29c38"), "p": Color("#c57ae0"), "d": Color("#8a8294"),
	"c": Color("#7fd8e6"), "s": Color("#b8b2c2"), "k": Color("#0d0a12"),
}
static var glyphs: Dictionary = {}   # character -> [x in the atlas, width], CJK -> [x, width, y in cjk.png]
static var _atlas: Texture2D
static var _cjk_atlas: Texture2D

static func ensure() -> void:
	if not glyphs.is_empty():
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://assets/font/glyphs.json")) != OK:
		push_error("glyphs.json not readable")
		return
	glyphs = j.data
	# Godot-only: the CJK glyphs of the translations (tools/build_cjk_font.py), one set
	# per language because Chinese and Japanese draw the same character differently;
	# the current language goes first, the others cover the language names
	if j.parse(FileAccess.get_file_as_string("res://assets/font/cjk.json")) != OK:
		push_error("cjk.json not readable")
		return
	var sets: Dictionary = j.data
	var order: Array = [Loc.lang] + sets.keys()
	for l in order:
		var cs: Dictionary = sets.get(l, {})
		for ch in cs:
			if not glyphs.has(ch):
				glyphs[ch] = cs[ch]

# the glyphs are picked again for the new language
static func reset() -> void:
	glyphs = {}

static func atlas() -> Texture2D:
	if _atlas == null:
		_atlas = load("res://assets/font/lantern.png")
	return _atlas

static func cjk_atlas() -> Texture2D:
	if _cjk_atlas == null:
		_cjk_atlas = load("res://assets/font/cjk.png")
	return _cjk_atlas

# JS fallback: upper/lower case, then the question mark
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

# width ignoring the color codes, of the translated text
static func width(s: String, scale: float = 1.0) -> float:
	return raw_width(Loc.t(s), scale)

static func raw_width(s: String, scale: float = 1.0) -> float:
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

# Godot-only: Chinese and Japanese have no spaces and break between any two
# characters (Hangul uses spaces like the Latin scripts)
static func is_cjk(ch: String) -> bool:
	var c := ch.unicode_at(0)
	return c >= 0x2E80 and not (c >= 0xAC00 and c <= 0xD7AF)

const NO_LINE_START := "、。，．！？：；）」』〉》ー"

# words split on spaces, CJK characters one by one; each is [text, space before]
static func _tokens(para: String) -> Array:
	var out: Array = []
	var words := para.split(" ")
	for wi in words.size():
		var cur := ""
		var sp := wi > 0
		for ch in words[wi]:
			if cur != "" and is_cjk(ch) and not NO_LINE_START.contains(ch):
				out.append([cur, sp])
				cur = ""
				sp = false
			cur += ch
		out.append([cur, sp])
	return out

# automatic wrapping of the translated text, keeps the color codes across lines
static func wrap(s: String, max_w: float, scale: float = 1.0) -> Array:
	var out: Array = []
	for para in Loc.t(s).split("\n"):
		var line := ""
		var last_code := ""
		for tok in _tokens(para):
			var word: String = tok[0]
			var test: String = line + (" " if tok[1] else "") + word if line != "" else word
			if raw_width(test, scale) > max_w and line != "":
				out.append(line)
				line = ("^" + last_code if last_code != "" else "") + word
			else:
				line = test
			var code := _last_code(word)
			if code != "":
				last_code = code
		out.append(line)
	return out
