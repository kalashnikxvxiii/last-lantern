extends Screen
# Title (Scenes.title in js/game.js).

# Game logo (Godot only): a high-res image drawn in place of the static
# "LAST" / "LANTERN" text. LOGO_SRC is the visible content of logo.png, which
# has a transparent border all around; LOGO_W is the on-screen width.
const LOGO_PATH := "res://assets/ui/logo.png"
const LOGO_SRC := Rect2(38, 221, 919, 475)
const LOGO_W := 173.0
const LOGO_CY := 80.5   # vertical centre; the logo stays centred here as LOGO_W changes
# Godot only: the title lantern is dimmed a little (the JS draws it at full
# brightness); other screens keep the ported look. 1.0 = unchanged.
const LANTERN_DIM := 0.6
static var _logo: Texture2D

var confirm_quit := false

# The logo hangs off a layer above the screen bloom (like the HUD in play.tscn):
# it is a bright, saturated image, so the bloom would light it up far more than
# the old flat title text did.
class LogoView extends Node2D:
	var screen
	func _draw() -> void:
		screen._draw_logo(self, Consts.W / 2.0)

func enter() -> void:
	menu = Menu.new([
		{"label": "Descend", "action": func(): Game.set_scene("slots")},
		{"label": "How to play", "action": func(): Game.set_scene("help")},
		{"label": "Archive", "action": func(): Game.set_scene("records")},
		{"label": "Options", "action": func(): Game.set_scene("options")},
		{"label": func(): return "Sure? Press again to quit" if confirm_quit else "Quit the game", "action": func():
			if not confirm_quit:
				confirm_quit = true
				return
			get_tree().quit()},
	])
	Music.play("title")
	Music.set_intensity(0)
	Run.reset()
	_add_logo()

func _add_logo() -> void:
	if _logo == null:
		var t: Texture2D = load(LOGO_PATH)
		if t == null:
			return
		var ct := CanvasTexture.new()
		ct.diffuse_texture = t
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_logo = ct
	var layer := CanvasLayer.new()
	layer.layer = 1
	var view := LogoView.new()
	view.screen = self
	layer.add_child(view)
	add_child(layer)

func update(_dt: float) -> void:
	menu.update()
	if menu.sel != menu.items.size() - 1:
		confirm_quit = false

func paint() -> void:
	var W := Consts.W
	var ga := UiDraw.alpha
	UiDraw.alpha = ga * LANTERN_DIM
	WellBg.big_lantern(self, 60, 50, "#f6cf57", sin(t * 1.3) * 0.12, 3)
	UiDraw.alpha = ga
	if _logo == null:   # fallback: the old title text
		UiDraw.text(self, "LAST", W / 2.0, 92, {"align": "center", "color": "#c8a050", "scale": 3, "shadowColor": "#2a1408"})
		UiDraw.text(self, "LANTERN", W / 2.0, 118, {"align": "center", "color": "#f6cf57", "scale": 4, "shadowColor": "#2a1408"})
	UiDraw.text(self, "a descent into the sunless well", W / 2.0, 160, {"align": "center", "color": "#8a8294"})
	menu.draw(self, W / 2.0, 172, {"lineH": 14})
	var st: Dictionary = Save.data.stats
	if st.runs > 0:
		UiDraw.text(self, Loc.f("Descents: {0}   Deepest depth: {1}   Flames rekindled: {2}", [st.runs, st.bestDepth, st.wins]), W / 2.0, 248, {"align": "center", "color": "#55505e"})
	UiDraw.text(self, "Keyboard and mouse or gamepad", W / 2.0, 259, {"align": "center", "color": "#3b3546"})
	UiDraw.text(self, Consts.VERSION, W - 5, 259, {"align": "right", "color": "#3b3546"})

# Draws the game logo centered on cx, keeping the source aspect ratio. The image
# is a high-res asset scaled well below 1:1, so it is filtered smoothly
# (linear + mipmaps) unlike the nearest-neighbour pixel art around it.
func _draw_logo(ci: CanvasItem, cx: float) -> void:
	var w := U.jround(LOGO_W)
	var h := U.jround(LOGO_W * LOGO_SRC.size.y / LOGO_SRC.size.x)
	var x := U.jround(cx - w / 2.0)
	var y := U.jround(LOGO_CY - h / 2.0)
	# Drawn once, never redrawn: so no UiDraw.alpha, which it would not follow.
	ci.draw_texture_rect_region(_logo, Rect2(x, y, w, h), LOGO_SRC)
