extends TestCase
# Dialog panels must grow to fit their text: the merchant bubble and the toast
# subtitle used to be capped and let their text overflow.

func test_panel_fits_a_single_line() -> void:
	eq(UiDraw.panel_width("Hello", "", 12.0), Txt.width("Hello") + 12.0)

func test_panel_fits_the_wider_of_two_lines() -> void:
	var sub := "Explodes shortly after: ^y80^w area damage."
	eq(UiDraw.panel_width("Bomb", sub, 16.0), Txt.width(sub) + 16.0)
	eq(UiDraw.panel_width(sub, "Bomb", 16.0), Txt.width(sub) + 16.0)

func test_merchant_bubble_fits_every_line() -> void:
	for line in Lore.MERCHANT_LINES:
		check(UiDraw.panel_width(line, "", 12.0) >= Txt.width(line) + 1.0, line)

func test_toast_sub_fits_every_description() -> void:
	for id in Cons.ALL:
		var c: Dictionary = Cons.ALL[id]
		check(UiDraw.panel_width(c.name, c.desc, 16.0) >= Txt.width(c.desc) + 1.0, id)
