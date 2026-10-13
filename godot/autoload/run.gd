extends Node
# State of the current run (the run object in js/game.js and js/entities.js).
# active replaces the JS "run !== null" check.

var active := false
var seed := 0
var rng: RNG
var depth := 1
var ardor := 0
var player: Player
var floor: Dictionary = {}
var room: Dictionary = {}
var bullets: Array = []
var ebullets: Array = []
var enemies: Array = []
var fx: Array = []
var kills := 0
var time := 0.0
var dmg_dealt := 0.0
var dmg_taken := 0.0
var coins_total := 0
var pending_levels := 0
var reroll_cost := 5
var offered_relics: Dictionary = {}
var oil_fx: Array = []
var flash_light: Variant = null
var toasts: Array = []
var banners: Array = []
var focus: Variant = null
var pull: Variant = null
var won := false
var endless := false
var rooms_cleared := 0
var new_unlocks: Array = []
var trans: Variant = null
var intro: Variant = null
var boss_intro: Variant = null
var flow_t := 0.0
var level_delay := 0.0
var lock_msg_t := 0.0
var death_t := 0.0
var victory_t := 0.0
var flow: PackedInt32Array = PackedInt32Array()
var boss_ref: Variant = null
var lock_fire := false
var forced_choices: Variant = null
var blood_paid := 0
var abandoned := false
var win_recorded := false
var slot := -1   # save slot of the run (RunSave), -1 = not saved
var actors: Node2D = null   # game scene node that hosts the actors

# on quit: frees the actors the game scene let go and the rooms' circular references
func _exit_tree() -> void:
	reset()

func reset() -> void:
	if player != null and is_instance_valid(player):
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		player.free()
	for e in enemies:
		if is_instance_valid(e):
			e.free()
	# breaks circular references between the rooms of the previous floor
	for r in floor.get("rooms", []):
		r.doors.clear()
	active = false
	seed = 0
	rng = null
	depth = 1
	ardor = 0
	player = null
	floor = {}
	room = {}
	bullets = []
	ebullets = []
	enemies = []
	fx = []
	kills = 0
	time = 0.0
	dmg_dealt = 0.0
	dmg_taken = 0.0
	coins_total = 0
	pending_levels = 0
	reroll_cost = 5
	offered_relics = {}
	oil_fx = []
	flash_light = null
	toasts = []
	banners = []
	focus = null
	pull = null
	won = false
	endless = false
	rooms_cleared = 0
	new_unlocks = []
	trans = null
	intro = null
	boss_intro = null
	flow_t = 0.0
	level_delay = 0.0
	lock_msg_t = 0.0
	death_t = 0.0
	victory_t = 0.0
	flow = PackedInt32Array()
	boss_ref = null
	lock_fire = false
	forced_choices = null
	blood_paid = 0
	abandoned = false
	win_recorded = false
	slot = -1

# notifications (toast and banner in js/ui.js)
func toast(text: String, col: Variant = "#ece6d8", sub: String = "") -> void:
	if not active:
		return
	toasts.append({"text": text, "col": col, "sub": sub, "t": 0.0, "life": 3.2 if sub != "" else 2.4})
	if toasts.size() > 4:
		toasts.pop_front()

func banner(title: String, desc: String, col: Variant, icon: String) -> void:
	if not active:
		return
	banners.append({"title": title, "desc": desc, "col": col, "icon": icon, "t": 0.0, "life": 3.6})
	if banners.size() > 2:
		banners.pop_front()

func update_notices(dt: float) -> void:
	for t in toasts:
		t.t += dt
	toasts = toasts.filter(func(t): return t.t < t.life)
	if not banners.is_empty():
		banners[0].t += dt
		if banners[0].t > banners[0].life:
			banners.pop_front()

func add_enemy(e) -> void:
	enemies.append(e)
	if actors != null:
		actors.add_child(e)

func clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			_free_node(e)
	enemies = []

# run.enemies = run.enemies.filter(e => !e.dead), freeing the nodes
func prune_enemies() -> void:
	var alive: Array = []
	for e in enemies:
		if e.dead:
			_free_node(e)
		else:
			alive.append(e)
	enemies = alive

static func _free_node(n: Node) -> void:
	if n.is_inside_tree():
		n.queue_free()
	else:
		n.free()
