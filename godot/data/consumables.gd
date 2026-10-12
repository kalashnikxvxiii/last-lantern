class_name Cons
extends RefCounted
# Consumabili (CONS in js/data.js): 4 slot, si impilano fino a 3. L'ordine conta.

static var ALL := {
	"potion": {"name": "Pozione Rossa", "spr": "potion", "w": 10, "price": 14, "desc": "Cura ^y30^w vita."},
	"bigpotion": {"name": "Elisir Vitale", "spr": "bigpotion", "w": 2, "price": 30, "desc": "Cura ^ytutta^w la vita."},
	"oil": {"name": "Fiaschetta d'Olio", "spr": "oilflask", "w": 8, "price": 10, "desc": "Ricarica ^y60^w olio."},
	"bomb": {"name": "Bomba", "spr": "bomb", "w": 9, "price": 9, "desc": "Esplode dopo poco: ^y80^w danni ad area. Sfonda rocce incrinate e passaggi segreti."},
	"antidote": {"name": "Antidoto", "spr": "antidote", "w": 6, "price": 10, "desc": "Rimuove tutti i malus e ne protegge per ^y6^w secondi."},
	"rage": {"name": "Grappa del Minatore", "spr": "rage", "w": 6, "price": 12, "desc": "+^y50%^w danno e cadenza per ^y10^w secondi."},
	"frost": {"name": "Fiala di Gelo", "spr": "frost", "w": 5, "price": 14, "desc": "^cCongela^w tutti i nemici della stanza per ^y3^w secondi."},
	"map": {"name": "Pergamena", "spr": "scroll", "w": 4, "price": 8, "desc": "Rivela la mappa della profondità, segreti inclusi."},
	"firefly": {"name": "Barattolo di Lucciole", "spr": "jar", "w": 5, "price": 12, "desc": "^y3^w lucciole ti proteggono per ^y25^w secondi."},
	"dice": {"name": "Dado Truccato", "spr": "dice", "w": 3, "price": 18, "desc": "Ottieni un dono casuale. ^r30%^w di ricevere anche una maledizione."},
	"smoke": {"name": "Polvere d'Ombra", "spr": "pouch", "w": 4, "price": 10, "desc": "Diventi ^sinvisibile^w per ^y4^w secondi."},
	"holy": {"name": "Acqua Santa", "spr": "holy", "w": 2, "price": 28, "desc": "Rimuove una ^pmaledizione^w. Senza maledizioni cura 30 vita."},
	"feather": {"name": "Piuma di Fenice", "spr": "feather", "w": 1.5, "price": 35, "desc": "Passiva: se muori, ^yrinasci^w con metà vita (si consuma).", "passive": true},
}

# use() dei consumabili; vero se il consumabile è stato usato
static func use(id: String, p) -> bool:
	match id:
		"potion":
			if p.hp >= p.stats.maxHp:
				return false
			p.heal(30)
		"bigpotion":
			if p.hp >= p.stats.maxHp:
				return false
			p.heal(999)
		"oil":
			if p.oil >= p.stats.maxOil:
				return false
			p.add_oil(60)
			Sfx.play("oil")
		"bomb":
			Effects.place_bomb(p.x, p.y + 3, "player")
		"antidote":
			Status.cleanse(p)
			Status.add(p, "immune", 6)
			Sfx.play("heal")
		"rage":
			Status.add(p, "rage", 10)
			Sfx.play("flare", 0.5)
		"frost":
			Combat.freeze_all(3)
		"map":
			Flow.reveal_map()
		"firefly":
			p.temp_orbit_t = 25.0
			p.temp_orbit = 3
			Sfx.play("pickup")
		"dice":
			Flow.roll_dice()
		"smoke":
			Status.add(p, "invis", 4)
			Particles.burst(p.x, p.y, 30, ["#4a4068", "#8a80b0", "#2a2440"], 60, 0.8)
			Sfx.play("dash")
		"holy":
			if not p.curses.is_empty():
				var c: String = p.curses.pop_back()
				Run.toast("Maledizione spezzata: " + Curses.ALL[c].name, "#c57ae0")
				p.recalc_stats()
				Sfx.play("heal")
			else:
				if p.hp >= p.stats.maxHp:
					return false
				p.heal(30)
		"feather":
			return false
	return true
