extends TestCase
# Text measuring and wrapping: must match Font.width and Font.wrap of the JS.

func test_base_width() -> void:
	eq(Txt.width("Hello"), 25.0)         # H5 e5 l3 l3 o5 + 4 gaps between glyphs
	eq(Txt.width("^yHello^w"), 25.0)     # color codes do not count
	eq(Txt.width("a b"), 15.0)           # the space is worth 3 + 1
	eq(Txt.width("Hello", 2), 50.0)
	eq(Txt.width(""), 0.0)

func test_wrap_keeps_the_color() -> void:
	eq(Txt.wrap("^yone two three", 30), ["^yone", "^ytwo", "^ythree"])
	eq(Txt.wrap("one\ntwo", 200), ["one", "two"])
	eq(Txt.wrap("", 50), [""])

func test_missing_glyph_fallback() -> void:
	eq(Txt.glyph("ò"), Txt.glyph("ò"))
	eq(Txt.glyph("Ò")[1], 5.0, "accented capital drawn")
	eq(Txt.glyph("ñ"), Txt.glyph("?"), "no glyph: question mark")
	eq(Txt.glyph("’"), Txt.glyph("?"))
	eq(Txt.width("ñ"), Txt.width("?"))
	eq(Txt.glyph("q")[1], 5.0)

func test_text_colors() -> void:
	eq(Txt.COLORS.y, Color("#f6cf57"))
	eq(Txt.COLORS.k, Color("#0d0a12"))
	eq(Txt.COLORS.size(), 11)
