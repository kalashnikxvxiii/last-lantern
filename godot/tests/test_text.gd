extends TestCase
# Misura e a capo del testo: devono coincidere con Font.width e Font.wrap del JS.

func test_larghezza_base() -> void:
	eq(Txt.width("Ciao"), 21.0)          # C5 i3 a5 o5 + 3 spazi tra glifi
	eq(Txt.width("^yCiao^w"), 21.0)      # i codici colore non contano
	eq(Txt.width("a b"), 15.0)           # lo spazio vale 3 + 1
	eq(Txt.width("Ciao", 2), 42.0)
	eq(Txt.width(""), 0.0)

func test_a_capo_conserva_il_colore() -> void:
	eq(Txt.wrap("^yuno due tre", 30), ["^yuno", "^ydue", "^ytre"])
	eq(Txt.wrap("uno\ndue", 200), ["uno", "due"])
	eq(Txt.wrap("", 50), [""])

func test_missing_glyph_fallback() -> void:
	eq(Txt.glyph("ò"), Txt.glyph("ò"))
	eq(Txt.glyph("Ò")[1], 5.0, "maiuscola accentata disegnata")
	eq(Txt.glyph("ñ"), Txt.glyph("?"), "senza glifo: punto interrogativo")
	eq(Txt.glyph("’"), Txt.glyph("?"))
	eq(Txt.width("ñ"), Txt.width("?"))
	eq(Txt.glyph("q")[1], 5.0)

func test_colori_del_testo() -> void:
	eq(Txt.COLORS.y, Color("#f6cf57"))
	eq(Txt.COLORS.k, Color("#0d0a12"))
	eq(Txt.COLORS.size(), 11)
