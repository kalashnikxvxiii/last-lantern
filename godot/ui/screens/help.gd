extends Screen
# Come si gioca (Scenes.help in js/game.js).

var page := 0

func update(_dt: float) -> void:
	if Controls.back():
		Game.set_scene("title")
		return
	if Controls.right() or Controls.confirm() or Controls.mouse_left_pressed():
		page += 1
		Sfx.play("select")
		if page > 2:
			Game.set_scene("title")
	if Controls.left() and page > 0:
		page -= 1
		Sfx.play("select")

func paint() -> void:
	var W := Consts.W
	var H := Consts.H
	UiDraw.panel(self, 24, 14, W - 48, H - 28)
	var titles := ["Comandi", "La discesa", "Stati alterati"]
	UiDraw.text(self, titles[mini(page, 2)], W / 2.0, 24, {"align": "center", "color": "#f6cf57", "scale": 2})
	var x := 44.0
	if page == 0:
		var rows := [
			[["W", "A", "S", "D"], "Muoviti"], [["Mouse"], "Mira  (oppure le frecce)"], [["Clic Sx"], "Spara  (oppure tieni premute le frecce)"],
			[["Spazio"], "Scatto: attraversi i colpi senza danno"], [["Clic Dx", "F"], "Vampata: onda di fuoco, consuma olio"],
			[["1", "2", "3", "4"], "Usa un consumabile"], [["E"], "Interagisci: forzieri, reliquie, mercante"], [["Tab", "M"], "Mappa della profondità"], [["Esc", "P"], "Pausa e equipaggiamento"],
		]
		for i in rows.size():
			var kx := x
			for k in rows[i][0]:
				kx += UiDraw.keycap(self, kx, 50 + i * 18, k) + 3
			UiDraw.text(self, rows[i][1], x + 110, 51 + i * 18, {"color": "#d8d0c0"})
		UiDraw.text_wrapped(self, "^dGamepad: stick sinistro per muoverti, stick destro per mirare e sparare, A scatto, B Vampata, X interagisci, croce direzionale per i consumabili.", x, 216, W - 90, {})
	elif page == 1:
		var txt := [
			"^yLa lanterna è la tua vita.^w Durante i combattimenti l'olio si consuma e la luce si restringe. Ogni nemico ucciso restituisce un po' d'olio. Senza olio il buio ti ferisce: subisci ^r+25%^w danni.",
			"^yLa Vampata^w brucia e respinge chi ti sta attorno e cancella i proiettili vicini. Costa olio: usala con giudizio.",
			"^yI doni^w arrivano salendo di livello e si scelgono quando la stanza è sicura. ^yLe reliquie^w si trovano nei tesori, dai mercanti, nei segreti e dai guardiani. Alcune portano ^pmaledizioni^w.",
			"Le ^ybombe^w aprono passaggi segreti: cerca le crepe sui muri. Ogni profondità ha un ^rguardiano^w: sconfiggilo e scendi dalla botola. Sono cinque profondità fino al Cuore del Pozzo.",
		]
		var y := 46.0
		for tx in txt:
			y += UiDraw.text_wrapped(self, tx, x, y, W - 90, {"color": "#d8d0c0"}) + 6
	else:
		var desc := {
			"burn": "Danno continuo per qualche secondo.", "poison": "Danno continuo che si accumula a ogni colpo.", "chill": "Rallenta. Tre cariche congelano i nemici.",
			"slow": "Ti muovi più lentamente.", "weak": "Infliggi il 30% di danno in meno.", "fragile": "Subisci il 30% di danno in più.", "blind": "La tua luce si riduce drasticamente.",
			"rage": "Danno e cadenza aumentati.", "immune": "Nessun malus può colpirti.", "invis": "I nemici perdono le tue tracce.", "fury": "Cadenza aumentata dopo ogni uccisione.",
		}
		var ks := Statuses.ALL.keys()
		for i in ks.size():
			var k: String = ks[i]
			var y := 46 + i * 16
			UiDraw.px_rect(self, x, y - 2, 11, 12, "#0b0810")
			Spr.draw(self, Statuses.ALL[k].icon, 0, x + 5.5, y + 4)
			UiDraw.text(self, Statuses.ALL[k].name, x + 18, y, {"color": Statuses.ALL[k].col})
			UiDraw.text(self, desc.get(k, ""), x + 110, y, {"color": "#d8d0c0"})
	UiDraw.text(self, str(mini(page, 2) + 1) + " / 3   -   frecce per sfogliare, ESC per uscire", W / 2.0, H - 26, {"align": "center", "color": "#55505e"})
