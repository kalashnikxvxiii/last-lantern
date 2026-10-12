class_name Relics
extends RefCounted
# Relics (RELICS in js/data.js). Order matters: do not reorder.

static var ALL := {
	"r_stoneheart": {"name": "Stone Heart", "icon": "i_heart", "desc": "+^y30^w max health. ^r-5%^w speed.", "onTake": true},
	"r_mirror": {"name": "Cracked Mirror", "icon": "i_mirror", "desc": "Dashing ^yreflects^w nearby enemy projectiles."},
	"r_crown": {"name": "Drowned Man's Crown", "icon": "i_crown", "desc": "+^y40%^w coins. Merchants give a ^y25%^w discount."},
	"r_skull": {"name": "Laughing Skull", "icon": "i_skull", "desc": "+^y35%^w damage. ^pCurse:^w Frailty.", "curse": "c_frail"},
	"r_lens": {"name": "Amber Lens", "icon": "i_lens", "desc": "+^y12%^w crit. Crits ^oignite^w."},
	"r_wick": {"name": "Eternal Wick", "icon": "i_lantern", "desc": "Oil no longer burns over time."},
	"r_bell": {"name": "Silent Bell", "icon": "i_bell", "desc": "Entering a room leaves enemies ^ystunned^w for 1.5 seconds."},
	"r_hourglass": {"name": "Broken Hourglass", "icon": "i_hourglass", "desc": "+^y25%^w fire rate, +^y12%^w speed. ^pCurse:^w Haste.", "curse": "c_haste"},
	"r_tooth": {"name": "Vampire Fang", "icon": "i_tooth", "desc": "Each critical hit heals ^y1^w health."},
	"r_eye": {"name": "Third Eye", "icon": "i_eye", "desc": "Reveals the map and secret rooms. +^y10%^w light."},
	"r_quiver": {"name": "Bone Quiver", "icon": "i_quiver", "desc": "+^y2^w projectiles. ^r-10%^w fire rate."},
	"r_anvil": {"name": "Anvil", "icon": "i_anvil", "desc": "+^y50%^w damage, bigger projectiles. ^r-20%^w fire rate."},
	"r_feather": {"name": "Raven Feather", "icon": "i_wing", "desc": "+^y1^w dash charge, longer dash that recharges faster."},
	"r_moth": {"name": "Moth Wings", "icon": "i_wing", "desc": "Immune to ^gpoison^w and ^sslow^w. +^y10%^w speed."},
	"r_ember": {"name": "Ember of the First Fire", "icon": "i_flame", "desc": "+^y1^w orbiting firefly. The Flare costs half."},
	"r_key": {"name": "Skeleton Key", "icon": "i_key", "desc": "+^y3^w keys. Golden chests are more generous.", "onTake": true},
	"r_blood": {"name": "Blood Pact", "icon": "i_cup", "desc": "+^y60%^w damage below 40% health. ^pCurse:^w Bitter Blood.", "curse": "c_blood"},
	"r_ice": {"name": "Heart of Frost", "icon": "i_ice", "desc": "All hits ^cchill^w. Immune to frost."},
	"r_storm": {"name": "Storm Bottle", "icon": "i_storm", "desc": "Every 3 seconds ^blightning^w strikes an enemy (250% damage)."},
	"r_shell": {"name": "Tortoise Shell", "icon": "i_shell", "desc": "+^y4^w armor. ^r-12%^w speed."},
	"r_clover": {"name": "Dried Clover", "icon": "i_clover", "desc": "Rarer perks and a ^yfourth choice^w each level."},
	"r_lamp": {"name": "Miner's Lamp", "icon": "i_lamp", "desc": "+^y35%^w light radius, +^y10%^w crit."},
	"r_coffin": {"name": "Coffin Nail", "icon": "i_coffin", "desc": "On death, ^yrevive^w once with half health."},
	"r_ash": {"name": "Ash Urn", "icon": "i_urn", "desc": "Slain enemies leave ^oflames^w on the ground."},
	"r_mask": {"name": "Jester's Mask", "icon": "i_mask", "desc": "+^y20%^w dodge. ^pCurse:^w Fog.", "curse": "c_fog"},
	"r_gauntlet": {"name": "Smith's Gauntlet", "icon": "i_hand", "desc": "+^y20%^w damage, +^y2^w armor, projectiles pierce +^y1^w."},
}

static func apply(id: String, s: Dictionary) -> void:
	match id:
		"r_stoneheart":
			s.maxHp += 30
			s.speedMult -= 0.05
		"r_mirror": s.dashReflect = 1
		"r_crown":
			s.coinMult += 0.4
			s.priceMult *= 0.75
		"r_skull": s.dmgMult += 0.35
		"r_lens":
			s.crit += 0.12
			s.critBurn = 1
		"r_wick": s.noOilDrain = 1
		"r_bell": s.bellStun = 1.5
		"r_hourglass":
			s.rateMult += 0.25
			s.speedMult += 0.12
		"r_tooth": s.critHeal = 1
		"r_eye":
			s.mapReveal = 1
			s.lightMult += 0.1
		"r_quiver":
			s.proj += 2
			s.rateMult -= 0.1
		"r_anvil":
			s.dmgMult += 0.5
			s.rateMult -= 0.2
			s.shotSize += 1
		"r_feather":
			s.dashCharges += 1
			s.dashDist += 0.3
			s.dashCd *= 0.8
		"r_moth":
			s.immune.poison = 1
			s.immune.slow = 1
			s.speedMult += 0.1
		"r_ember":
			s.orbit += 1
			s.flareCost *= 0.5
		"r_key": s.goldKeys = 1
		"r_blood": s.lowHpDmg = 0.6
		"r_ice":
			s.chillAll = 1
			s.immune.chill = 1
		"r_storm": s.storm = 1
		"r_shell":
			s.armor += 4
			s.speedMult -= 0.12
		"r_clover":
			s.extraChoice = 1
			s.luck += 1
		"r_lamp":
			s.lightMult += 0.35
			s.crit += 0.1
		"r_coffin": s.revive = 1
		"r_ash": s.ashTrail = 1
		"r_mask": s.dodge += 0.2
		"r_gauntlet":
			s.dmgMult += 0.2
			s.armor += 2
			s.pierce += 1

static func on_take(id: String, p) -> void:
	match id:
		"r_stoneheart": p.heal(30, true)
		"r_key": p.keys += 3
