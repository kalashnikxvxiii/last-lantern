class_name Cons
extends RefCounted
# Consumables (CONS in js/data.js): 4 slots, stack up to 3. Order matters.

static var ALL := {
	"potion": {"name": "Red Potion", "spr": "potion", "w": 10, "price": 14, "desc": "Heals ^y30^w health."},
	"bigpotion": {"name": "Vital Elixir", "spr": "bigpotion", "w": 2, "price": 30, "desc": "Heals ^yall^w health."},
	"oil": {"name": "Oil Flask", "spr": "oilflask", "w": 8, "price": 10, "desc": "Restores ^y60^w oil."},
	"bomb": {"name": "Bomb", "spr": "bomb", "w": 9, "price": 9, "desc": "Explodes shortly after: ^y80^w area damage. Breaks cracked rocks and secret passages."},
	"antidote": {"name": "Antidote", "spr": "antidote", "w": 6, "price": 10, "desc": "Removes all debuffs and protects against them for ^y6^w seconds."},
	"rage": {"name": "Miner's Brew", "spr": "rage", "w": 6, "price": 12, "desc": "+^y50%^w damage and fire rate for ^y10^w seconds."},
	"frost": {"name": "Frost Vial", "spr": "frost", "w": 5, "price": 14, "desc": "^cFreezes^w all enemies in the room for ^y3^w seconds."},
	"map": {"name": "Scroll", "spr": "scroll", "w": 4, "price": 8, "desc": "Reveals the depth's map, secrets included."},
	"firefly": {"name": "Jar of Fireflies", "spr": "jar", "w": 5, "price": 12, "desc": "^y3^w fireflies protect you for ^y25^w seconds."},
	"dice": {"name": "Loaded Die", "spr": "dice", "w": 3, "price": 18, "desc": "Gain a random perk. ^r30%^w chance of also receiving a curse."},
	"smoke": {"name": "Shadow Dust", "spr": "pouch", "w": 4, "price": 10, "desc": "You become ^sinvisible^w for ^y4^w seconds."},
	"holy": {"name": "Holy Water", "spr": "holy", "w": 2, "price": 28, "desc": "Removes a ^pcurse^w. With no curses, heals 30 health."},
	"feather": {"name": "Phoenix Feather", "spr": "feather", "w": 1.5, "price": 35, "desc": "Passive: if you die, ^yrevive^w with half health (consumed).", "passive": true},
}

# consumable use(); true if the consumable was used
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
				Run.toast(Loc.f("Curse broken: {0}", [Loc.t(Curses.ALL[c].name)]), "#c57ae0")
				p.recalc_stats()
				Sfx.play("heal")
			else:
				if p.hp >= p.stats.maxHp:
					return false
				p.heal(30)
		"feather":
			return false
	return true
