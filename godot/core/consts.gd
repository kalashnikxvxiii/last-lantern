class_name Consts
extends RefCounted
# Shared constants (from js/core.js).

const VERSION := "godot 0.1.0"
const W := 480
const H := 270
const TS := 16
const RW := 29   # room size in tiles (walls included)
const RH := 15
const RX := 8    # room offset on screen
const RY := 28
const DT := 1.0 / 60.0

enum T { FLOOR, WALL, ROCK, CRACK, SPIKE, BARREL, BRAZIER, DOOR, URN }
