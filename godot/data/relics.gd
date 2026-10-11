class_name Relics
extends RefCounted
# Reliquie (RELICS in js/data.js). L'ordine conta: non riordinare.

static var ALL := {
	"r_stoneheart": {"name": "Cuore di Pietra", "icon": "i_heart", "desc": "+^y30^w vita massima. ^r-5%^w velocità.", "onTake": true},
	"r_mirror": {"name": "Specchio Incrinato", "icon": "i_mirror", "desc": "Scattando ^yrifletti^w i proiettili nemici vicini."},
	"r_crown": {"name": "Corona dell'Annegato", "icon": "i_crown", "desc": "+^y40%^w monete. I mercanti fanno lo sconto del ^y25%^w."},
	"r_skull": {"name": "Teschio Ridente", "icon": "i_skull", "desc": "+^y35%^w danno. ^pMaledizione:^w Fragilità.", "curse": "c_frail"},
	"r_lens": {"name": "Lente d'Ambra", "icon": "i_lens", "desc": "+^y12%^w critico. I critici ^oincendiano^w."},
	"r_wick": {"name": "Stoppino Eterno", "icon": "i_lantern", "desc": "L'olio non si consuma più col tempo."},
	"r_bell": {"name": "Campana Muta", "icon": "i_bell", "desc": "Entrando in una stanza i nemici restano ^ystorditi^w per 1.5 secondi."},
	"r_hourglass": {"name": "Clessidra Rotta", "icon": "i_hourglass", "desc": "+^y25%^w cadenza, +^y12%^w velocità. ^pMaledizione:^w Fretta.", "curse": "c_haste"},
	"r_tooth": {"name": "Dente di Vampiro", "icon": "i_tooth", "desc": "Ogni colpo critico cura ^y1^w vita."},
	"r_eye": {"name": "Terzo Occhio", "icon": "i_eye", "desc": "Rivela la mappa e le stanze segrete. +^y10%^w luce."},
	"r_quiver": {"name": "Faretra di Ossa", "icon": "i_quiver", "desc": "+^y2^w proiettili. ^r-10%^w cadenza."},
	"r_anvil": {"name": "Incudine", "icon": "i_anvil", "desc": "+^y50%^w danno, proiettili più grossi. ^r-20%^w cadenza."},
	"r_feather": {"name": "Piuma di Corvo", "icon": "i_wing", "desc": "+^y1^w carica di scatto, scatto più lungo e rapido a ricaricarsi."},
	"r_moth": {"name": "Ali di Falena", "icon": "i_wing", "desc": "Immune a ^gveleno^w e ^slentezza^w. +^y10%^w velocità."},
	"r_ember": {"name": "Brace del Primo Fuoco", "icon": "i_flame", "desc": "+^y1^w lucciola orbitante. La Vampata costa la metà."},
	"r_key": {"name": "Chiave dello Scheletro", "icon": "i_key", "desc": "+^y3^w chiavi. I forzieri dorati sono più generosi.", "onTake": true},
	"r_blood": {"name": "Patto di Sangue", "icon": "i_cup", "desc": "+^y60%^w danno sotto il 40% di vita. ^pMaledizione:^w Sangue Amaro.", "curse": "c_blood"},
	"r_ice": {"name": "Cuore di Brina", "icon": "i_ice", "desc": "Tutti i colpi ^craffreddano^w. Immune al gelo."},
	"r_storm": {"name": "Bottiglia di Tempesta", "icon": "i_storm", "desc": "Ogni 3 secondi un ^bfulmine^w colpisce un nemico (250% danno)."},
	"r_shell": {"name": "Guscio di Tartaruga", "icon": "i_shell", "desc": "+^y4^w armatura. ^r-12%^w velocità."},
	"r_clover": {"name": "Quadrifoglio Secco", "icon": "i_clover", "desc": "Doni più rari e una ^yquarta scelta^w a ogni livello."},
	"r_lamp": {"name": "Lampada del Minatore", "icon": "i_lamp", "desc": "+^y35%^w raggio di luce, +^y10%^w critico."},
	"r_coffin": {"name": "Chiodo di Bara", "icon": "i_coffin", "desc": "Alla morte ^yrinasci^w una volta con metà vita."},
	"r_ash": {"name": "Urna di Cenere", "icon": "i_urn", "desc": "I nemici uccisi lasciano ^ofiamme^w a terra."},
	"r_mask": {"name": "Maschera del Giullare", "icon": "i_mask", "desc": "+^y20%^w schivata. ^pMaledizione:^w Nebbia.", "curse": "c_fog"},
	"r_gauntlet": {"name": "Guanto del Fabbro", "icon": "i_hand", "desc": "+^y20%^w danno, +^y2^w armatura, proiettili trapassano +^y1^w."},
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
