class_name BossDef
extends Resource
# End-of-depth warden (BOSSES in js/data.js).

@export var id := ""
@export var name := ""
@export var title := ""
@export var spr := ""
@export var hp := 0.0
@export var r := 0.0
@export var spd := 0.0
@export var phases: Array = []   # [{at, gap, pats: [{p, ...}]}]
