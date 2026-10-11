class_name Statuses
extends RefCounted
# Stati alterati (STATUS in js/data.js).

static var ALL := {
	"burn": {"name": "Bruciatura", "icon": "s_burn", "col": "#f29c38", "bad": true},
	"poison": {"name": "Veleno", "icon": "s_poison", "col": "#8fd35a", "bad": true},
	"chill": {"name": "Gelo", "icon": "s_chill", "col": "#7fd8e6", "bad": true},
	"slow": {"name": "Lentezza", "icon": "s_slow", "col": "#b8b2c2", "bad": true},
	"weak": {"name": "Debolezza", "icon": "s_weak", "col": "#e0574a", "bad": true},
	"fragile": {"name": "Fragilità", "icon": "s_fragile", "col": "#e0574a", "bad": true},
	"blind": {"name": "Accecamento", "icon": "s_blind", "col": "#8a8294", "bad": true},
	"rage": {"name": "Ira", "icon": "s_rage", "col": "#f29c38", "bad": false},
	"immune": {"name": "Purezza", "icon": "s_shield", "col": "#7fd8e6", "bad": false},
	"invis": {"name": "Invisibile", "icon": "s_invis", "col": "#b8b2c2", "bad": false},
	"fury": {"name": "Frenesia", "icon": "s_rage", "col": "#f6cf57", "bad": false},
}
