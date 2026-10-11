class_name EnemyDef
extends Resource
# Statistiche di un nemico (ENEMIES in js/data.js).

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
@export var side := false        # sprite di profilo (si gira con la direzione)
@export var burst := false       # avanza a scatti (ratto)
@export var anim := 0.0          # velocità d'animazione; 0 = predefinita (5)
@export var trail := false
@export var split := ""
@export var split_n := 0
@export var death_cloud := false
@export var keep := 0.0          # distanza mantenuta dai lanciatori
@export var charge_spd := 0.0
@export var hop_cd := 0.0
@export var land_ring := 0
@export var shield := false
@export var slam := false
@export var touch := ""
@export var summon := ""
@export var shot: Dictionary = {}   # kind, col, spd, cd, n, spread, ring, burst, aimed, status, arms
