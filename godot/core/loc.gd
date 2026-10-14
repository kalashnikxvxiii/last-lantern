class_name Loc
extends RefCounted
# Godot-only: game text translations. locale/strings.json maps each English text
# (the key) to its translation in every language. UiDraw.text, Txt.width and
# Txt.wrap translate whole strings, so only text built from pieces needs Loc.f.

const LANGS := ["en", "it", "es", "fr", "de", "pt", "ru", "zh", "ja", "ko"]
const NAMES := {
	"en": "English", "it": "Italiano", "es": "Español", "fr": "Français", "de": "Deutsch",
	"pt": "Português", "ru": "Русский", "zh": "简体中文", "ja": "日本語", "ko": "한국어",
}

static var lang := "en"
static var _table: Dictionary = {}

static func t(s: String) -> String:
	return _table.get(s, s)

# template with {0}, {1}... placeholders, translated before filling it
static func f(template: String, args: Array) -> String:
	return t(template).format(args)

# the language of the system (OS locale), English if it is not translated
static func detect() -> String:
	var l := OS.get_locale_language()
	return l if l in LANGS else "en"

# "auto" follows the system
static func resolve(setting: String) -> String:
	return detect() if setting == "auto" else (setting if setting in LANGS else "en")

static func apply() -> void:
	use(resolve(str(Save.data.settings.get("language", "auto"))))

static func use(code: String) -> void:
	lang = code
	_table = table(code)
	Txt.reset()

static func table(code: String) -> Dictionary:
	if code == "en":
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://locale/strings.json")) != OK or not (j.data is Dictionary):
		push_error("locale/strings.json not readable")
		return {}
	var out := {}
	for k in j.data:
		var v: String = j.data[k].get(code, "")
		if v != "":
			out[k] = v
	return out
