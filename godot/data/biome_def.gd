class_name BiomeDef
extends Resource
# Depth and its look (BIOMES in js/data.js).

@export var id := ""
@export var name := ""
@export var music := ""
@export var boss := ""
@export var dark := 0.7
@export_multiline var lore := ""
@export var floor: Array = []       # three floor colors
@export var floor_d := ""
@export var wall := ""
@export var wall_d := ""
@export var wall_l := ""
@export var accent := ""
@export var pool: Array = []        # [type, cost, weight]
@export var deco := ""
@export var urns := false
@export var barrels := false
