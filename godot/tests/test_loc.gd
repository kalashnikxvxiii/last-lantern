extends TestCase
# Translations (Loc): every language covers the game data, keeps codes and
# placeholders, has a glyph for every character and translates idempotently.

var saved: Dictionary

func before() -> void:
	saved = Save.data.settings.duplicate()

func after() -> void:
	Save.data.settings = saved
	Loc.use("en")

static func _strings() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://locale/strings.json"))

# the ^x codes and {n} placeholders of a text, in order
static func _marks(s: String) -> Array:
	var re := RegEx.create_from_string("\\^.|\\{\\d\\}")
	return re.search_all(s).map(func(m: RegExMatch) -> String: return m.get_string())

func test_every_language_translates_every_text() -> void:
	var all := _strings()
	for k in all:
		for l in Loc.LANGS:
			if l != "en":
				check(str(all[k].get(l, "")) != "", "%s missing in %s" % [k, l])

func test_codes_and_placeholders_are_kept() -> void:
	var all := _strings()
	for k in all:
		var want := _marks(k)
		want.sort()
		for l in all[k]:
			var got := _marks(all[k][l])
			got.sort()
			eq(got, want, "%s (%s)" % [k, l])

func test_game_data_is_translated() -> void:
	var all := _strings()
	var texts: Array = []
	for d in [Perks.ALL, Relics.ALL, Curses.ALL, Cons.ALL]:
		for id in d:
			texts.append_array([d[id].name, d[id].desc])
	for id in Statuses.ALL:
		texts.append(Statuses.ALL[id].name)
	for r in Stats.RARITY:
		texts.append(r.name)
	texts.append_array(Lore.ARDOR + Lore.MERCHANT_LINES)
	for L in DB.lanterns():
		texts.append_array([L.name, L.desc])
		if L.unlock_text != "":
			texts.append(L.unlock_text)
	for d in range(1, 6):
		texts.append_array([DB.biome_of(d).name, DB.biome_of(d).lore])
	for f in DirAccess.get_files_at("res://data/enemies"):
		if f.ends_with(".tres"):
			texts.append(DB.enemy(f.get_basename()).name)
	for f in DirAccess.get_files_at("res://data/bosses"):
		if f.ends_with(".tres"):
			texts.append_array([DB.boss(f.get_basename()).name, DB.boss(f.get_basename()).title])
	for s in texts:
		check(all.has(s), "not translated: " + s)

func test_every_character_has_a_glyph() -> void:
	var all := _strings()
	var fallback: Array = Txt.glyph("?")
	for l in Loc.LANGS:
		Loc.use(l)
		for n in Loc.NAMES.values():
			for ch in n:
				check(Txt.glyph(ch) != fallback, "%s: no glyph for %s" % [l, ch])
		if l == "en":
			continue
		var seen := {}
		for k in all:
			var s: String = all[k][l]
			var i := 0
			while i < s.length():
				if s[i] == "^":
					i += 2
					continue
				var ch := s[i]
				if ch != "?" and ch != " " and not seen.has(ch):
					seen[ch] = true
					check(Txt.glyph(ch) != fallback, "%s: no glyph for %s (%s)" % [l, ch, k])
				i += 1

# the drawing code translates again what is already translated: no translation
# may be the English text of another one
func test_translating_twice_changes_nothing() -> void:
	var all := _strings()
	for l in Loc.LANGS:
		Loc.use(l)
		for k in all:
			var once := Loc.t(k)
			eq(Loc.t(once), once, "%s (%s)" % [k, l])

func test_translate_and_format() -> void:
	Loc.use("it")
	eq(Loc.t("Back"), "Indietro")
	eq(Loc.f("Depth {0}", [3]), "Profondità 3")
	eq(Loc.t("not a game text"), "not a game text")
	eq(Txt.width("Back"), Txt.raw_width("Indietro"))
	Loc.use("en")
	eq(Loc.f("Depth {0}", [3]), "Depth 3")

func test_auto_follows_the_system() -> void:
	eq(Loc.resolve("auto"), Loc.detect())
	eq(Loc.resolve("fr"), "fr")
	eq(Loc.resolve("xx"), "en")
	check(Loc.detect() in Loc.LANGS)

func test_cjk_wraps_between_characters() -> void:
	Loc.use("ja")
	var lines := Txt.wrap("灯灯灯灯灯灯", 30)
	eq(lines, ["灯灯灯", "灯灯灯"])
	# punctuation never starts a line
	for line in Txt.wrap("灯灯灯。灯灯", 30):
		check(not (line as String).begins_with("。"), line)
	# the color goes on with the next line
	eq(Txt.wrap("^y灯灯灯灯", 30), ["^y灯灯灯", "^y灯"])

func test_language_option() -> void:
	var m := OptionsMenu.new(func(): pass)
	m.tab = OptionsMenu.TABS.find("Gameplay")
	var items: Array = m.menu().items
	var it: Dictionary = {}
	for x in items:
		if x.label is String and x.label == "Language":
			it = x
	check(not it.is_empty(), "Language entry")
	Save.data.settings.language = "en"
	it.adjust.call(1)
	eq(Save.data.settings.language, "it")
	eq(Loc.lang, "it")
	eq(Menu.label_of(it), "Lingua   Italiano")
