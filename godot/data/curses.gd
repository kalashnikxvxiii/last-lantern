class_name Curses
extends RefCounted
# Curses (CURSES in js/data.js). Order matters: do not reorder.

static var ALL := {
	"c_dark": {"name": "Pitch Dark", "desc": "^r-25%^w light radius."},
	"c_frail": {"name": "Frailty", "desc": "^r+20%^w damage taken."},
	"c_greed": {"name": "Greed", "desc": "Merchant prices ^r+40%^w."},
	"c_haste": {"name": "Haste", "desc": "Enemies are ^r12%^w faster."},
	"c_blood": {"name": "Bitter Blood", "desc": "Healing is ^r40%^w less effective."},
	"c_fog": {"name": "Fog", "desc": "The minimap is hidden."},
	"c_weak": {"name": "Weakness", "desc": "^r-12%^w damage."},
	"c_rust": {"name": "Rust", "desc": "^r-1^w armor and ^r-10%^w fire rate."},
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
