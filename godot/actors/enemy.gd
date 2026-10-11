class_name Enemy
extends Node2D
# Nemico (makeEnemy, updateEnemies, drawEnemy in js/entities.js e js/render.js).
# x, y sono le coordinate logiche del JS; position si allinea a fine tick.

var type := ""
var def: EnemyDef
var display_name := ""
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var r := 5.0
var hp := 1.0
var max_hp := 1.0
var spd := 0.0
var dmg := 0.0
var ai := ""
var fly := false
var st := 0.0
var state := "idle"
var shot_cd := 0.0
var flash := 0.0
var statuses: Dictionary = {}
var frozen := 0.0
var freeze_cd := 0.0
var stun := 0.35
var facing := 0.0
var anim := 0.0
var mod: Variant = null
var kbx := 0.0
var kby := 0.0
var xp := 0.0
var z := 0.0
var alpha := 1.0
var intangible := false
var wind := 0.0
var orb_cd := 0.0
var t := 0.0
var elite := false
var no_split := false
var summoned := false
var summoner: Variant = null
var spawning := false
var dead := false
var boss := false
var hit_wall := false
var shield_down := false
var wander: Variant = null
var wander_t: Variant = null
# campi che le AI del JS creano al volo
var jit: Variant = null
var jit_t := 0.0
var charge_a := 0.0
var trail_t := 0.0
var orbit_dir := 0
var burst_left := 0
var burst_t := 0.0
var charge_line: Variant = null
var slam_target: Variant = null
var dying: Variant = null
var invuln := 0.0

static func make(type_: String, x_: float, y_: float, mod_: Variant = null, o: Dictionary = {}) -> Enemy:
	var D := DB.enemy(type_)
	var d := Run.depth
	var e := Enemy.new()
	var hp_ := D.hp * Stats.depth_hp(d) * Stats.ard_hp()
	e.type = type_
	e.def = D
	e.display_name = D.name
	e.x = x_
	e.y = y_
	e.r = D.r
	e.hp = hp_
	e.max_hp = hp_
	e.spd = D.spd * (1 + 0.03 * (d - 1)) * Run.player.stats.enemySpeed
	e.dmg = D.dmg * Stats.depth_dmg(d) * Stats.ard_dmg()
	e.ai = D.ai
	e.fly = D.fly
	e.shot_cd = U.rnd(0.9, 1.8) + (D.shot.get("cd", 2.0) * 0.4 if not D.shot.is_empty() else 0.0)
	e.anim = U.rnd(0, 3)
	e.mod = mod_
	e.xp = D.xp * 2 * (1 + 0.15 * (d - 1))
	e.t = U.rnd(0, 5)
	if mod_ != null:
		e.elite = true
		e.hp *= 1.6
		e.xp *= 2.2
		if mod_ == "armored":
			e.hp *= 1.5
		if mod_ == "swift":
			e.spd *= 1.4
		e.max_hp = e.hp
	if o.get("small", false):
		e.hp *= 0.5
		e.max_hp = e.hp
		e.no_split = true
	if not Run.room.is_empty() and Run.player.stats.bellStun and not o.get("summoned", false):
		e.stun = maxf(e.stun, Run.player.stats.bellStun)
	e.position = Vector2(x_, y_)
	return e
