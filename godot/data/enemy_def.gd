class_name EnemyDef
extends Resource
# Stats of an enemy (ENEMIES in js/data.js).

@export var id := ""
@export var name := ""
@export var spr := ""
@export var hp := 0.0
@export var spd := 0.0
@export var dmg := 0.0
@export var r := 0.0
@export var ai := ""
@export var xp := 0.0
@export var fly := false
@export var side := false        # side-view sprite (flips with direction)
@export var burst := false       # advances in bursts (rat)
@export var anim := 0.0          # animation speed; 0 = default (5)
@export var trail := false
@export var split := ""
@export var split_n := 0
@export var death_cloud := false
@export var keep := 0.0          # distance kept by ranged attackers
@export var charge_spd := 0.0
@export var hop_cd := 0.0
@export var land_ring := 0
@export var shield := false
@export var slam := false
@export var touch := ""
@export var summon := ""
@export var shot: Dictionary = {}   # kind, col, spd, cd, n, spread, ring, burst, aimed, status, arms
