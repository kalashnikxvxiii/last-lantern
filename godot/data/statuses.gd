class_name Statuses
extends RefCounted
# Status effects (STATUS in js/data.js).

static var ALL := {
	"burn": {"name": "Burning", "icon": "s_burn", "col": "#f29c38", "bad": true},
	"poison": {"name": "Poison", "icon": "s_poison", "col": "#8fd35a", "bad": true},
	"chill": {"name": "Frost", "icon": "s_chill", "col": "#7fd8e6", "bad": true},
	"slow": {"name": "Slow", "icon": "s_slow", "col": "#b8b2c2", "bad": true},
	"weak": {"name": "Weakness", "icon": "s_weak", "col": "#e0574a", "bad": true},
	"fragile": {"name": "Frailty", "icon": "s_fragile", "col": "#e0574a", "bad": true},
	"blind": {"name": "Blindness", "icon": "s_blind", "col": "#8a8294", "bad": true},
	"rage": {"name": "Rage", "icon": "s_rage", "col": "#f29c38", "bad": false},
	"immune": {"name": "Purity", "icon": "s_shield", "col": "#7fd8e6", "bad": false},
	"invis": {"name": "Invisible", "icon": "s_invis", "col": "#b8b2c2", "bad": false},
	"fury": {"name": "Frenzy", "icon": "s_rage", "col": "#f6cf57", "bad": false},
}
