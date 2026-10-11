class_name Player
extends Node2D
# Il portatore di lanterna (newPlayer e funzioni del giocatore in js/entities.js).
# x, y sono le coordinate logiche del JS; position si allinea a fine tick.

var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var r := 4.0
var hp := 1.0
var oil := 1.0
var xp := 0.0
var level := 1
var coins := 0
var keys := 1
var aim := 0.0
var fire_cd := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_charges := 1
var dash_dx := 0.0
var dash_dy := 0.0
var inv := 0.0
var statuses: Dictionary = {}
var perks: Dictionary = {}
var relics: Array = []
var curses: Array = []
var cons: Array = [null, null, null, null]
var shot_count := 0
var flare_cd := 0.0
var guard_t := 0.0
var guard_up := false
var secondwind_used := false
var coffin_used := false
var temp_orbit := 0
var temp_orbit_t := 0.0
var orbit_a := 0.0
var sun_t := 0.0
var storm_t := 3.0
var trail_t := 0.0
var echo_t := 0.0
var anim := 0.0
var moving := false
var lantern := "custode"
var stats: Dictionary = Stats.base()
var dead := false
var last_hit := ""
var facing := 1
var base_hp_mod := 0.0

# recalcStats: lanterna, doni, reliquie, maledizioni, Ardore e limiti
func recalc_stats() -> void:
	var s := Stats.base()
	DB.lantern(lantern).apply_stats(s)
	for id in perks:
		Perks.apply(id, s, perks[id])
	for id in relics:
		Relics.apply(id, s)
	for id in curses:
		Curses.apply(id, s)
	s.maxHp += base_hp_mod
	if Run.ardore >= 4:
		s.healMult -= 0.3
	if Run.ardore >= 5:
		s.oilDrain *= 1.5
	s.dmgMult = maxf(0.2, s.dmgMult)
	s.rateMult = maxf(0.3, s.rateMult)
	s.speedMult = maxf(0.5, s.speedMult)
	s.lightMult = maxf(0.35, s.lightMult)
	s.healMult = maxf(0.1, s.healMult)
	s.maxHp = maxf(10, U.jround(s.maxHp))
	s.armor = maxf(0, s.armor)
	s.dodge = minf(0.6, s.dodge)
	s.crit = minf(1, s.crit)
	stats = s
	hp = minf(hp, s.maxHp)
	oil = minf(oil, s.maxOil)
	dash_charges = mini(dash_charges, int(s.dashCharges))

func damage() -> float:
	var s := stats
	var m: float = s.dmgMult
	if statuses.has("rage"):
		m += 0.5
	if statuses.has("weak"):
		m -= 0.3
	if s.berserk:
		m += 1 - hp / s.maxHp
	if s.lowHpDmg and hp / s.maxHp < 0.4:
		m += s.lowHpDmg
	return s.dmg * maxf(0.15, m)

func fire_rate() -> float:
	var s := stats
	var m: float = s.rateMult
	if statuses.has("rage"):
		m += 0.5
	if statuses.has("fury"):
		m += s.fury
	return s.fireRate * maxf(0.3, m)

func speed() -> float:
	var m: float = stats.speedMult
	if statuses.has("slow"):
		m -= 0.35
	if statuses.has("chill"):
		m -= 0.3
	return stats.speed * maxf(0.35, m)

func light() -> float:
	var s := stats
	var frac: float = oil / s.maxOil if s.maxOil > 0 else 0.0
	var r_: float = s.light * s.lightMult * (0.45 + 0.55 * minf(1, frac * 1.3))
	if statuses.has("blind"):
		r_ *= 0.45
	return maxf(26, r_)

# parte pura di hurtPlayer: danno effettivo dopo armatura, fragilità e buio
func damage_taken(amount: float) -> int:
	var d: float = amount * stats.dmgTaken * (1 - minf(0.6, stats.armor * 0.07))
	if statuses.has("fragile"):
		d *= 1.3
	if oil <= 0:
		d *= 1.25
	return int(maxf(1, U.jround(d)))

func heal(v: float, raw: bool = false) -> void:
	var amt: float = v if raw else v * stats.healMult
	var before := hp
	hp = minf(stats.maxHp, hp + amt)
	var got := int(U.jround(hp - before))
	if got > 0:
		Floaters.add(x, y - 12, "+" + str(got), Txt.COLORS.g)
		Particles.burst(x, y, 10, ["#8fd35a", "#d0ffb0"], 40, 0.6, {"grav": -40})
		Sfx.play("heal")

func add_oil(v: float) -> void:
	oil = minf(stats.maxOil, oil + v)

func add_coins(v: float) -> int:
	var n := int(maxf(1, U.jround(v * stats.coinMult)))
	coins += n
	Run.coins_total += n
	return n

func give_cons(id: String) -> bool:
	for s in cons:
		if s != null and s.id == id and s.n < 3:
			s.n += 1
			return true
	var i := cons.find(null)
	if i >= 0:
		cons[i] = {"id": id, "n": 1}
		return true
	return false

func can_take_cons(id: String) -> bool:
	return cons.any(func(s): return s == null or (s.id == id and s.n < 3))

func add_xp(v: float) -> void:
	xp += v * stats.xpMult
	while xp >= Stats.xp_need(level):
		xp -= Stats.xp_need(level)
		level += 1
		Run.pending_levels += 1
		Floaters.add(x, y - 16, "LIVELLO " + str(level), Txt.COLORS.y, {"life": 1.4, "vy": -20})
		Particles.burst(x, y, 24, ["#f6cf57", "#fff2a8", "#f29c38"], 90, 0.8, {"grav": -30})
		Sfx.play("levelup")
		heal(6, true)
