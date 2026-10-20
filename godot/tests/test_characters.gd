extends TestCase
# Godot-only: the characters chosen with the lantern before a run (data,
# unlocks, sprite).

func after() -> void:
	Run.reset()

func test_the_wanderer_comes_first_and_is_free() -> void:
	var cs := DB.characters()
	eq(cs.size(), 6)
	eq(cs[0].id, "wanderer")
	check(cs[0].unlocked({}))
	eq(Save.defaults().unlocks.characters, ["wanderer"])

func test_every_character_has_a_turning_sprite() -> void:
	for c in DB.characters():
		check(Spr.has(c.sprite), c.id)
		eq(Spr.frame_count(c.sprite), 10, c.id)
		eq(Spr.size(c.sprite), Spr.size("player"), c.id)

func test_the_run_starts_with_the_chosen_character() -> void:
	U.seed_random(5)
	Flow.start_run("warden", 0, 5, "goblin")
	eq(Run.player.character, "goblin")
	eq(Run.player.sprite_state().name, DB.character("goblin").sprite)
	TH.new_run(5)
	eq(Run.player.character, "wanderer")
	eq(Run.player.sprite_state().name, "player")

func test_kills_unlock_the_goblin() -> void:
	Save.data.unlocks.characters = ["wanderer"]
	Save.data.stats.kills = 100
	TH.new_run(93)
	Flow.check_unlocks()
	check(Save.data.unlocks.characters.has("goblin"))
	check(Run.new_unlocks.has("Goblin"))

func test_unknown_character_falls_back_to_the_wanderer() -> void:
	eq(DB.character("nobody").id, "wanderer")
