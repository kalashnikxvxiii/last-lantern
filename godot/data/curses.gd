class_name Curses
extends RefCounted
# Maledizioni (CURSES in js/data.js). L'ordine conta: non riordinare.

static var ALL := {
	"c_dark": {"name": "Buio Pesto", "desc": "^r-25%^w raggio di luce."},
	"c_frail": {"name": "Fragilità", "desc": "^r+20%^w danni subiti."},
	"c_greed": {"name": "Avarizia", "desc": "Prezzi dei mercanti ^r+40%^w."},
	"c_haste": {"name": "Fretta", "desc": "I nemici sono più veloci del ^r12%^w."},
	"c_blood": {"name": "Sangue Amaro", "desc": "Le cure sono ^r40%^w meno efficaci."},
	"c_fog": {"name": "Nebbia", "desc": "La minimappa è nascosta."},
	"c_weak": {"name": "Debolezza", "desc": "^r-12%^w danno."},
	"c_rust": {"name": "Ruggine", "desc": "^r-1^w armatura e ^r-10%^w cadenza."},
}

static func apply(id: String, s: Dictionary) -> void:
	match id:
		"c_dark": s.lightMult -= 0.25
		"c_frail": s.dmgTaken *= 1.2
		"c_greed": s.priceMult *= 1.4
		"c_haste": s.enemySpeed *= 1.12
		"c_blood": s.healMult -= 0.4
		"c_fog": s.hideMap = 1
		"c_weak": s.dmgMult -= 0.12
		"c_rust":
			s.armor -= 1
			s.rateMult -= 0.1
