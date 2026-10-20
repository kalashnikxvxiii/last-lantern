class_name CharacterDef
extends Resource
# Godot-only: the character chosen with the lantern before a run. It gives
# the look; the stats come from the lantern.

@export var id := ""
@export var name := ""
@export var sprite := "player"
@export_multiline var desc := ""
@export var unlock_stat := ""    # key of Save.data.stats; "" = always available
@export var unlock_min := 0
@export var unlock_text := ""

func unlocked(st: Dictionary) -> bool:
	return unlock_stat == "" or st.get(unlock_stat, 0) >= unlock_min

# 0..1 toward the unlock
func progress(st: Dictionary) -> float:
	return 1.0 if unlock_stat == "" else clampf(float(st.get(unlock_stat, 0)) / unlock_min, 0.0, 1.0)
