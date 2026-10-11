class_name Stats
extends RefCounted
# Statistiche di base del giocatore, rarità e scalature (da js/data.js e js/entities.js).

static var RARITY := [
	{"name": "Comune", "col": "#c8c0b0", "w": 62},
	{"name": "Raro", "col": "#6fa8e8", "w": 27},
	{"name": "Epico", "col": "#c57ae0", "w": 9},
	{"name": "Leggendario", "col": "#f6cf57", "w": 2.5},
]

static func base() -> Dictionary:
	return {
		"maxHp": 60, "dmg": 10, "dmgMult": 1, "fireRate": 3.0, "rateMult": 1, "shotSpeed": 230, "range": 200, "shotSize": 3,
		"proj": 1, "pierce": 0, "bounce": 0, "homing": 0, "crit": 0.05, "critMult": 2.0,
		"speed": 92, "speedMult": 1, "armor": 0, "dodge": 0, "dashCharges": 1, "dashCd": 1.0, "dashDist": 1, "iframes": 0.9,
		"maxOil": 100, "oilDrain": 1, "light": 104, "lightMult": 1, "pickup": 26, "coinMult": 1, "xpMult": 1, "healMult": 1,
		"leech": 0, "thorns": 0, "burn": 0, "poison": 0, "chill": 0, "chain": 0, "explode": 0, "orbit": 0, "flareCost": 40, "flareMult": 1,
		"fury": 0, "comet": 0, "split": 0, "berserk": 0, "secondwind": 0, "ashguard": 0, "guardian": 0, "primal": 0, "echo": 0, "sun": 0,
		"dashfire": 0, "critBurn": 0, "critHeal": 0, "dashReflect": 0, "noOilDrain": 0, "bellStun": 0, "immune": {}, "chillAll": 0,
		"storm": 0, "extraChoice": 0, "luck": 0, "revive": 0, "ashTrail": 0, "lowHpDmg": 0, "priceMult": 1,
		"enemySpeed": 1, "dmgTaken": 1, "mapReveal": 0, "hideMap": 0, "goldKeys": 0, "burnMult": 1,
	}

# scalature per profondità
static func depth_hp(d: int) -> float:
	return 1 + 0.6 * (d - 1) + 0.08 * (d - 1) * (d - 1)

static func depth_dmg(d: int) -> float:
	return 1 + 0.2 * (d - 1)

static func xp_need(level: int) -> float:
	return U.jround(12 + 7 * level + 1.5 * level * level)
