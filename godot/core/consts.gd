class_name Consts
extends RefCounted
# Shared constants (from js/core.js).

const VERSION := "godot 0.2.0"
const W := 480
const H := 270
const TS := 16
const RW := 29   # room size in tiles (walls included)
const RH := 15
const RX := 8    # room offset on screen
const RY := 28
const DT := 1.0 / 60.0
# Godot-only restart: R held for RESTART_HOLD, then the lantern flares up for
# RESTART_FADE seconds and the new run fades in from the light
const RESTART_HOLD := 2.0
const RESTART_FADE := 0.5
const RESTART_R := 520.0   # flood radius of the restart light at full flare
const RESTART_DUST_T := 0.35    # seconds for a body to burn down to ash
const RESTART_UNDUST_T := 0.25  # and to reassemble when the light leaves

enum T { FLOOR, WALL, ROCK, CRACK, SPIKE, BARREL, BRAZIER, DOOR, URN }
