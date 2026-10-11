class_name LanternDef
extends Resource
# Lanterna iniziale (LANTERNS in js/data.js). Effetti sulle statistiche come campi,
# così si modificano dall'Inspector.

@export var id := ""
@export var name := ""
@export var glass := "#f6cf57"
@export_multiline var desc := ""
@export var unlock_stat := ""    # chiave di Save.data.stats; "" = sempre disponibile
@export var unlock_min := 0
@export var unlock_text := ""
@export var max_hp_add := 0.0
@export var max_hp_mult := 1.0
@export var armor_add := 0.0
@export var speed_mult_add := 0.0
@export var rate_mult_add := 0.0
@export var dmg_mult_add := 0.0
@export var crit_add := 0.0
@export var max_oil_add := 0.0
@export var flare_cost_mult := 1.0
@export var light_mult_add := 0.0
@export var dash_charges_add := 0
@export var start_cons: Array[String] = []
@export var start_perks: Array[String] = []
@export var random_relics := 0
@export var random_curses := 0

func unlocked(st: Dictionary) -> bool:
	return unlock_stat == "" or st.get(unlock_stat, 0) >= unlock_min

func apply_stats(s: Dictionary) -> void:
	s.maxHp += max_hp_add
	if max_hp_mult != 1.0:
		s.maxHp = U.jround(s.maxHp * max_hp_mult)
	s.armor += armor_add
	s.speedMult += speed_mult_add
	s.rateMult += rate_mult_add
	s.dmgMult += dmg_mult_add
	s.crit += crit_add
	s.maxOil += max_oil_add
	s.flareCost *= flare_cost_mult
	s.lightMult += light_mult_add
	s.dashCharges += dash_charges_add

# start() del JS
func on_start(p) -> void:
	for c in start_cons:
		p.give_cons(c)
	for k in start_perks:
		p.perks[k] = 1
	if random_relics > 0:
		var pool := Relics.ALL.keys().filter(func(k): return not Relics.ALL[k].has("curse"))
		U.shuffle(pool)
		var cs := Curses.ALL.keys().filter(func(c): return c != "c_fog")
		U.shuffle(cs)
		for i in random_relics:
			p.relics.append(pool[i])
		for i in random_curses:
			p.curses.append(cs[i])
		for i in random_relics:
			Relics.on_take(pool[i], p)
