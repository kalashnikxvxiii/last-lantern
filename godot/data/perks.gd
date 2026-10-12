class_name Perks
extends RefCounted
# Perks chosen on level-up (PERKS in js/data.js). Order matters: do not reorder.

static var ALL := {
	"dmg": {"name": "Live Embers", "rar": 0, "max": 5, "icon": "i_blade", "desc": "+^y18%^w projectile damage."},
	"rate": {"name": "Nimble Hand", "rar": 0, "max": 5, "icon": "i_rate", "desc": "+^y14%^w fire rate."},
	"speed": {"name": "Soft Step", "rar": 0, "max": 3, "icon": "i_boot", "desc": "+^y10%^w movement speed."},
	"hp": {"name": "Sturdy Heart", "rar": 0, "max": 5, "icon": "i_heart", "desc": "+^y15^w max health and heal ^y15^w.", "onTake": true},
	"armor": {"name": "Tanned Hide", "rar": 0, "max": 4, "icon": "i_shield", "desc": "+^y1^w armor: reduces damage taken by ^y7%^w."},
	"crit": {"name": "Keen Eye", "rar": 0, "max": 4, "icon": "i_eye", "desc": "+^y7%^w critical hit chance."},
	"range": {"name": "Long Arm", "rar": 0, "max": 3, "icon": "i_range", "desc": "+^y20%^w range and +^y12%^w projectile speed."},
	"oilmax": {"name": "Wide Reservoir", "rar": 0, "max": 3, "icon": "i_drop", "desc": "+^y25^w max oil and +^y8%^w light radius."},
	"magnet": {"name": "Magnet", "rar": 0, "max": 2, "icon": "i_magnet", "desc": "+^y60%^w pickup radius."},
	"greed": {"name": "Golden Fingers", "rar": 0, "max": 3, "icon": "i_coin", "desc": "+^y30%^w coins collected."},
	"xp": {"name": "Lit Mind", "rar": 0, "max": 3, "icon": "i_book", "desc": "+^y15%^w experience gained."},
	"thorns": {"name": "Bramble Thorns", "rar": 0, "max": 2, "icon": "i_thorn", "desc": "Whoever touches you takes ^y150%^w of your damage."},
	"medic": {"name": "Herbalist", "rar": 0, "max": 2, "icon": "i_flask", "desc": "Potions and hearts heal ^y40%^w more."},
	"multishot": {"name": "Double Wick", "rar": 1, "max": 3, "icon": "i_multi", "desc": "+^y1^w projectile per volley, ^r-8%^w damage."},
	"pierce": {"name": "Iron Tip", "rar": 1, "max": 3, "icon": "i_pierce", "desc": "Projectiles pierce ^y1^w more enemy."},
	"bounce": {"name": "Ricochet", "rar": 1, "max": 3, "icon": "i_bounce", "desc": "Projectiles bounce off walls ^y1^w more time."},
	"homing": {"name": "Will-o'-the-Wisp", "rar": 1, "max": 2, "icon": "i_wisp", "desc": "Projectiles curve toward enemies."},
	"burn": {"name": "Firebrand", "rar": 1, "max": 3, "icon": "i_flame", "desc": "^y18%^w chance to ^oignite^w the target."},
	"poison": {"name": "Black Sap", "rar": 1, "max": 3, "icon": "i_poison", "desc": "^y20%^w chance to ^gpoison^w. Poison stacks."},
	"chill": {"name": "Hoarfrost", "rar": 1, "max": 3, "icon": "i_snow", "desc": "^y18%^w chance to ^cchill^w. Three stacks freeze."},
	"dash": {"name": "Nimble Legs", "rar": 1, "max": 2, "icon": "i_wing", "desc": "+^y1^w dash charge."},
	"dashfire": {"name": "Burning Trail", "rar": 1, "max": 1, "icon": "i_flame", "desc": "Dashing leaves a ^ofire trail^w that burns enemies."},
	"fury": {"name": "Frenzy", "rar": 1, "max": 2, "icon": "i_rate", "desc": "Each kill: +^y35%^w fire rate for ^y2.5^w seconds."},
	"dodge": {"name": "Reflexes", "rar": 1, "max": 3, "icon": "i_wing", "desc": "^y10%^w chance to dodge a hit."},
	"flare": {"name": "Fierce Flare", "rar": 1, "max": 2, "icon": "i_sun", "desc": "The Flare costs ^y25%^w less and deals +^y50%^w damage."},
	"leech": {"name": "Thirst", "rar": 1, "max": 3, "icon": "i_blood", "desc": "Each kill heals ^y1^w health."},
	"critdmg": {"name": "Killing Blow", "rar": 1, "max": 3, "icon": "i_skull", "desc": "+^y50%^w critical hit damage."},
	"oileff": {"name": "Clean Wick", "rar": 1, "max": 2, "icon": "i_lantern", "desc": "Oil burns ^y35%^w slower."},
	"chain": {"name": "Electric Arc", "rar": 2, "max": 3, "icon": "i_bolt", "desc": "^y15%^w chance for a hit to unleash ^blightning^w on 3 enemies."},
	"explode": {"name": "Unstable Ashes", "rar": 2, "max": 2, "icon": "i_urn", "desc": "Slain enemies ^oexplode^w, hurting those nearby."},
	"orbit": {"name": "Fireflies", "rar": 2, "max": 3, "icon": "i_orbit", "desc": "+^y1^w orbiting firefly: hurts enemies and blocks projectiles."},
	"split": {"name": "Shards", "rar": 2, "max": 1, "icon": "i_star", "desc": "Projectiles break into ^y3^w shards on impact."},
	"comet": {"name": "Comet", "rar": 2, "max": 2, "icon": "i_moon", "desc": "Every few shots a piercing ^ycomet^w fires for ^y300%^w damage."},
	"berserk": {"name": "Blood Fury", "rar": 2, "max": 1, "icon": "i_blood", "desc": "+^y1%^w damage for every ^y1%^w of missing health."},
	"secondwind": {"name": "Last Breath", "rar": 2, "max": 1, "icon": "i_heart", "desc": "Once per depth, survive a lethal hit."},
	"ashguard": {"name": "Ash Armor", "rar": 2, "max": 1, "icon": "i_shield", "desc": "When hit, you release a ^owave of fire^w."},
	"guardian": {"name": "Warden Light", "rar": 3, "max": 1, "icon": "i_lamp", "desc": "Every ^y10^w seconds a shield of light absorbs a hit."},
	"primal": {"name": "First Flame", "rar": 3, "max": 1, "icon": "i_flame", "desc": "All hits ^oignite^w and burning deals double damage."},
	"swarm": {"name": "Burning Swarm", "rar": 3, "max": 1, "icon": "i_multi", "desc": "+^y2^w projectiles per volley, ^r-12%^w damage."},
	"echo": {"name": "Echo", "rar": 3, "max": 1, "icon": "i_bell", "desc": "^y30%^w chance to fire a second volley."},
	"sun": {"name": "Little Sun", "rar": 3, "max": 1, "icon": "i_sun", "desc": "Your light ^oburns^w enemies close to you."},
}

static func apply(id: String, s: Dictionary, n: int) -> void:
	match id:
		"dmg": s.dmgMult += 0.18 * n
		"rate": s.rateMult += 0.14 * n
		"speed": s.speedMult += 0.10 * n
		"hp": s.maxHp += 15 * n
		"armor": s.armor += n
		"crit": s.crit += 0.07 * n
		"range":
			s["range"] *= 1 + 0.2 * n
			s.shotSpeed *= 1 + 0.12 * n
		"oilmax":
			s.maxOil += 25 * n
			s.lightMult += 0.08 * n
		"magnet": s.pickup *= 1 + 0.6 * n
		"greed": s.coinMult += 0.3 * n
		"xp": s.xpMult += 0.15 * n
		"thorns": s.thorns += 1.5 * n
		"medic": s.healMult += 0.4 * n
		"multishot":
			s.proj += n
			s.dmgMult -= 0.08 * n
		"pierce": s.pierce += n
		"bounce": s.bounce += n
		"homing": s.homing += n
		"burn": s.burn += 0.18 * n
		"poison": s.poison += 0.2 * n
		"chill": s.chill += 0.18 * n
		"dash": s.dashCharges += n
		"dashfire": s.dashfire = n
		"fury": s.fury += 0.35 * n
		"dodge": s.dodge += 0.1 * n
		"flare":
			s.flareCost *= pow(0.75, n)
			s.flareMult += 0.5 * n
		"leech": s.leech += n
		"critdmg": s.critMult += 0.5 * n
		"oileff": s.oilDrain *= pow(0.65, n)
		"chain": s.chain += 0.15 * n
		"explode": s.explode += n
		"orbit": s.orbit += n
		"split": s.split = n
		"comet": s.comet += n
		"berserk": s.berserk = n
		"secondwind": s.secondwind = n
		"ashguard": s.ashguard = n
		"guardian": s.guardian = n
		"primal":
			s.primal = n
			s.burnMult += 1
		"swarm":
			s.proj += 2
			s.dmgMult -= 0.12
		"echo": s.echo = 0.3
		"sun": s.sun = n

static func on_take(id: String, p) -> void:
	match id:
		"hp": p.heal(15, true)

# perk choice weighted by rarity
static func roll_choices(n: int, min_rar: int = 0) -> Array:
	var p = Run.player
	var luck: float = p.stats.luck + (Run.depth - 1) * 0.25
	var pool: Array = ALL.keys().filter(func(id): return p.perks.get(id, 0) < ALL[id]["max"] and ALL[id].rar >= min_rar)
	var wf := func(k):
		var r: int = ALL[k].rar
		return Stats.RARITY[r].w * (1.0 if r == 0 else 1 + luck * (0.3 + r * 0.35))
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var id: String = U.weighted_pick(pool, wf)
		out.append(id)
		pool.erase(id)
	return out
