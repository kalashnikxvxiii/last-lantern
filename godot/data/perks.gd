class_name Perks
extends RefCounted
# Doni scelti al passaggio di livello (PERKS in js/data.js). L'ordine conta: non riordinare.

static var ALL := {
	"dmg": {"name": "Braci Vive", "rar": 0, "max": 5, "icon": "i_blade", "desc": "+^y18%^w danno dei proiettili."},
	"rate": {"name": "Mano Lesta", "rar": 0, "max": 5, "icon": "i_rate", "desc": "+^y14%^w cadenza di fuoco."},
	"speed": {"name": "Passo Felpato", "rar": 0, "max": 3, "icon": "i_boot", "desc": "+^y10%^w velocità di movimento."},
	"hp": {"name": "Cuore Robusto", "rar": 0, "max": 5, "icon": "i_heart", "desc": "+^y15^w vita massima e ne curi ^y15^w.", "onTake": true},
	"armor": {"name": "Pelle Conciata", "rar": 0, "max": 4, "icon": "i_shield", "desc": "+^y1^w armatura: riduce del ^y7%^w i danni subiti."},
	"crit": {"name": "Occhio Fino", "rar": 0, "max": 4, "icon": "i_eye", "desc": "+^y7%^w probabilità di colpo critico."},
	"range": {"name": "Braccio Lungo", "rar": 0, "max": 3, "icon": "i_range", "desc": "+^y20%^w gittata e +^y12%^w velocità dei proiettili."},
	"oilmax": {"name": "Serbatoio Ampio", "rar": 0, "max": 3, "icon": "i_drop", "desc": "+^y25^w olio massimo e +^y8%^w raggio di luce."},
	"magnet": {"name": "Calamita", "rar": 0, "max": 2, "icon": "i_magnet", "desc": "+^y60%^w raggio di raccolta."},
	"greed": {"name": "Dita d'Oro", "rar": 0, "max": 3, "icon": "i_coin", "desc": "+^y30%^w monete raccolte."},
	"xp": {"name": "Mente Accesa", "rar": 0, "max": 3, "icon": "i_book", "desc": "+^y15%^w esperienza ottenuta."},
	"thorns": {"name": "Spine di Rovo", "rar": 0, "max": 2, "icon": "i_thorn", "desc": "Chi ti tocca subisce il ^y150%^w del tuo danno."},
	"medic": {"name": "Erborista", "rar": 0, "max": 2, "icon": "i_flask", "desc": "Pozioni e cuori curano il ^y40%^w in più."},
	"multishot": {"name": "Doppio Stoppino", "rar": 1, "max": 3, "icon": "i_multi", "desc": "+^y1^w proiettile per raffica, ^r-8%^w danno."},
	"pierce": {"name": "Punta di Ferro", "rar": 1, "max": 3, "icon": "i_pierce", "desc": "I proiettili trapassano ^y1^w nemico in più."},
	"bounce": {"name": "Rimbalzo", "rar": 1, "max": 3, "icon": "i_bounce", "desc": "I proiettili rimbalzano sui muri ^y1^w volta in più."},
	"homing": {"name": "Fuoco Fatuo", "rar": 1, "max": 2, "icon": "i_wisp", "desc": "I proiettili curvano verso i nemici."},
	"burn": {"name": "Tizzone", "rar": 1, "max": 3, "icon": "i_flame", "desc": "^y18%^w di probabilità di ^oincendiare^w il bersaglio."},
	"poison": {"name": "Linfa Nera", "rar": 1, "max": 3, "icon": "i_poison", "desc": "^y20%^w di probabilità di ^gavvelenare^w. Il veleno si accumula."},
	"chill": {"name": "Brina", "rar": 1, "max": 3, "icon": "i_snow", "desc": "^y18%^w di probabilità di ^craffreddare^w. Tre cariche congelano."},
	"dash": {"name": "Gambe Agili", "rar": 1, "max": 2, "icon": "i_wing", "desc": "+^y1^w carica di scatto."},
	"dashfire": {"name": "Scia Ardente", "rar": 1, "max": 1, "icon": "i_flame", "desc": "Lo scatto lascia una ^oscia di fuoco^w che brucia i nemici."},
	"fury": {"name": "Frenesia", "rar": 1, "max": 2, "icon": "i_rate", "desc": "Ogni uccisione: +^y35%^w cadenza per ^y2.5^w secondi."},
	"dodge": {"name": "Riflessi", "rar": 1, "max": 3, "icon": "i_wing", "desc": "^y10%^w di probabilità di schivare un colpo."},
	"flare": {"name": "Vampata Feroce", "rar": 1, "max": 2, "icon": "i_sun", "desc": "La Vampata costa il ^y25%^w in meno e fa +^y50%^w danno."},
	"leech": {"name": "Sete", "rar": 1, "max": 3, "icon": "i_blood", "desc": "Ogni uccisione cura ^y1^w vita."},
	"critdmg": {"name": "Colpo Mortale", "rar": 1, "max": 3, "icon": "i_skull", "desc": "+^y50%^w danno dei colpi critici."},
	"oileff": {"name": "Stoppino Pulito", "rar": 1, "max": 2, "icon": "i_lantern", "desc": "L'olio si consuma il ^y35%^w più lentamente."},
	"chain": {"name": "Arco Voltaico", "rar": 2, "max": 3, "icon": "i_bolt", "desc": "^y15%^w di probabilità che un colpo scateni un ^bfulmine^w su 3 nemici."},
	"explode": {"name": "Ceneri Instabili", "rar": 2, "max": 2, "icon": "i_urn", "desc": "I nemici uccisi ^oesplodono^w ferendo quelli vicini."},
	"orbit": {"name": "Lucciole", "rar": 2, "max": 3, "icon": "i_orbit", "desc": "+^y1^w lucciola orbitante: ferisce i nemici e para i proiettili."},
	"split": {"name": "Schegge", "rar": 2, "max": 1, "icon": "i_star", "desc": "I proiettili si spezzano in ^y3^w schegge all'impatto."},
	"comet": {"name": "Cometa", "rar": 2, "max": 2, "icon": "i_moon", "desc": "Ogni pochi colpi parte una ^ycometa^w perforante da ^y300%^w danno."},
	"berserk": {"name": "Furore del Sangue", "rar": 2, "max": 1, "icon": "i_blood", "desc": "+^y1%^w danno per ogni ^y1%^w di vita mancante."},
	"secondwind": {"name": "Ultimo Respiro", "rar": 2, "max": 1, "icon": "i_heart", "desc": "Una volta per profondità sopravvivi a un colpo mortale."},
	"ashguard": {"name": "Corazza di Cenere", "rar": 2, "max": 1, "icon": "i_shield", "desc": "Quando vieni colpito rilasci un'^oonda di fuoco^w."},
	"guardian": {"name": "Lume Custode", "rar": 3, "max": 1, "icon": "i_lamp", "desc": "Ogni ^y10^w secondi uno scudo di luce assorbe un colpo."},
	"primal": {"name": "Fiamma Prima", "rar": 3, "max": 1, "icon": "i_flame", "desc": "Tutti i colpi ^oincendiano^w e la bruciatura fa il doppio."},
	"swarm": {"name": "Sciame Ardente", "rar": 3, "max": 1, "icon": "i_multi", "desc": "+^y2^w proiettili per raffica, ^r-12%^w danno."},
	"echo": {"name": "Eco", "rar": 3, "max": 1, "icon": "i_bell", "desc": "^y30%^w di probabilità di sparare una seconda raffica."},
	"sun": {"name": "Piccolo Sole", "rar": 3, "max": 1, "icon": "i_sun", "desc": "La tua luce ^obrucia^w i nemici che ti stanno vicino."},
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

# scelta dei doni pesata per rarità
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
