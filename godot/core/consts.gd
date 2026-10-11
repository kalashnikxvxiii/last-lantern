class_name Consts
extends RefCounted
# Costanti condivise (da js/core.js).

const VERSION := "godot 0.1.0"
const W := 480
const H := 270
const TS := 16
const RW := 29   # dimensioni stanza in tile (muri inclusi)
const RH := 15
const RX := 8    # offset della stanza sullo schermo
const RY := 28
const DT := 1.0 / 60.0

enum T { FLOOR, WALL, ROCK, CRACK, SPIKE, BARREL, BRAZIER, DOOR, URN }
