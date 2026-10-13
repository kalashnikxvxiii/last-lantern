class_name Quality
extends RefCounted
# Godot-only quality presets: Low, Medium, High or Ultra set bloom, shadows,
# ambient occlusion and particles together. Color grading, screen effects and the
# CRT filter stay apart: they cost almost nothing and are a matter of taste.
# On the first boot the preset is picked from the graphics card.

const LEVELS := ["low", "medium", "high", "ultra"]
const PRESETS := {
	"low": {"bloom": "off", "shadows": "off", "ao": false, "particles": "low"},
	"medium": {"bloom": "low", "shadows": "low", "ao": true, "particles": "low"},
	"high": {"bloom": "medium", "shadows": "high", "ao": true, "particles": "high"},
	"ultra": {"bloom": "high", "shadows": "ultra", "ao": true, "particles": "ultra"},
}

static func _s() -> Dictionary:
	return Save.data.settings

# the preset the settings match, or "custom"
static func current() -> String:
	for level in LEVELS:
		var p: Dictionary = PRESETS[level]
		var same := true
		for k in p:
			if _s().get(k) != p[k]:
				same = false
		if same:
			return level
	return "custom"

static func apply(level: String) -> void:
	var p: Dictionary = PRESETS[level]
	for k in p:
		_s()[k] = p[k]

# next preset left or right; from Custom it starts as if on High
static func step(d: int) -> String:
	var cur := current()
	var i := LEVELS.find("high" if cur == "custom" else cur)
	return LEVELS[clampi(i + d, 0, LEVELS.size() - 1)]

static func auto_pick(device_type: int) -> String:
	match device_type:
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: return "high"
		RenderingDevice.DEVICE_TYPE_CPU: return "low"
	return "medium"

# once per save: the preset that suits the graphics card
static func first_boot(device_type: int) -> void:
	if _s().qualityPicked:
		return
	apply(auto_pick(device_type))
	_s().qualityPicked = true
	Save.write()
