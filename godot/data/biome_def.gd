class_name BiomeDef
extends Resource
# Profondità e suo aspetto (BIOMES in js/data.js).

@export var id := ""
@export var name := ""
@export var music := ""
@export var boss := ""
@export var dark := 0.7
@export_multiline var lore := ""
@export var floor: Array = []       # tre colori del pavimento
@export var floor_d := ""
@export var wall := ""
@export var wall_d := ""
@export var wall_l := ""
@export var accent := ""
@export var pool: Array = []        # [tipo, costo, peso]
@export var deco := ""
@export var urns := false
@export var barrels := false
