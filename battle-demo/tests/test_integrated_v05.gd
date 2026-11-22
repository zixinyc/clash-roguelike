extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const Setup = preload("res://battle_setup.tscn")
const TeamSynergy = preload("res://scripts/team_synergy.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")
const RelicSystem = preload("res://scripts/relic_system.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	# 1. Roster & 10 characters
	var roster := Rules.create_roster()
	check(roster.size() == 10, "roster has all 10 characters (including pufufu and ZiWu)")
	check(roster[Rules.PUFUFU_ID].name == "pufufu", "pufufu is registered at PUFUFU_ID")
	check(roster[Rules.ZIWU_ID].name == "ZiWu", "ZiWu is registered at ZIWU_ID")
	check(Rules.card_owner("ziwu_cold_edge") == Rules.ZIWU_ID, "ziwu_cold_edge belongs to ZiWu")
	check(Rules.card_owner("pufufu_soft_guard") == Rules.PUFUFU_ID, "pufufu_soft_guard belongs to pufufu")

	# 2. ZiWu end-to-end in DemoBattleRules (solo run)
	var b := Rules.new()
	b.start(73129, 0, false, false, [Rules.ZIWU_ID], null, false, ["dawn_amber"], ["whetstone", "echo_pendulum"], {"synergy_enabled": true})
	check(b.heroes.size() == 1 and b.heroes[0].character_id == Rules.ZIWU_ID, "ZiWu solo battle initializes")
	check(int(b.heroes[0].missing_allies) == 2 and bool(b.heroes[0].is_solo), "ZiWu solo round context computed")
	check(int(b.heroes[0].shield) == 12, "dawn_amber (+6) + lone_wolf synergy (+6) stack to 12 shield")
	var whet := b.use_item("whetstone")
	check(bool(whet.ok) and b.round_clash_bonus == 2, "whetstone grants +2 round clash bonus")
	var pend := b.use_item("echo_pendulum")
	check(bool(pend.ok) and b.cost == Rules.START_COST + 3 and int(b.heroes[0].shield) == 16, "echo_pendulum grants +3 cost and +4 shield in battle")
	check(b.assign(b.hand.find("ziwu_cold_edge"), 0, 0).is_empty(), "ZiWu can assign cold_edge")
	var events := b.lock_and_resolve()
	check(not events.is_empty(), "ZiWu solo battle resolves cleanly")

	# 3. TeamSynergy evaluations
	check(TeamSynergy.evaluate([Rules.ASH_ID, Rules.BLADE_ID, Rules.WEAVER_ID])[0].id == "ember_watch", "ember_watch synergy triggers")
	check(TeamSynergy.evaluate([Rules.REIMU_ID, Rules.MARISA_ID])[0].id == "gensokyo_barrier", "gensokyo_barrier synergy triggers")
	check(TeamSynergy.evaluate([Rules.ZIXI_ID, Rules.ZIXINGYC_ID])[0].id == "rational_deduction", "rational_deduction synergy triggers")
	check(TeamSynergy.evaluate([Rules.ASH_ID, Rules.PUFUFU_ID])[0].id == "fluff_bastion", "fluff_bastion synergy triggers")
	check(TeamSynergy.evaluate([Rules.ASH_ID, Rules.ZIWU_ID])[0].id == "insulated_edge", "insulated_edge synergy triggers")

	# 4. ForestRun time_hourglass + contracts
	var run := ForestRun.new()
	var fmap := ForestRandomGenerator.generate(2026)
	run.initialize(fmap, 0, ["time_hourglass"], ["echo_pendulum"], 2026, [Rules.ASH_ID, Rules.PUFUFU_ID, Rules.ZIWU_ID], [])
	run.apply_contract("bountiful_woods")
	check(run.carried_cost == ForestRun.START_COST + 6, "bountiful_woods grants +6 starting cost")
	var roll_res := run.roll_action_dice(1)
	check(bool(roll_res.ok) and int(roll_res.steps) == 2, "time_hourglass upgrades dice roll 1 to 2 steps")

	# 5. BattleSetup UI mode switching + screenshot capture
	var setup := Setup.instantiate()
	root.add_child(setup)
	await process_frame
	check(setup.role_buttons.size() == 10, "setup UI renders all 10 character buttons")
	check(setup.single_view.visible and not setup.multi_view.visible, "opens in singleplayer mode by default")
	check(setup.explore_pane.visible and not setup.skirmish_pane.visible, "opens in explore pane without duplicate card wall")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://test-output")
		check(root.get_texture().get_image().save_png("res://test-output/setup-v05-single.png") == OK, "saved singleplayer screenshot")
	setup._switch_top_mode("multi")
	await process_frame
	check(setup.multi_view.visible and not setup.single_view.visible, "switches cleanly to multiplayer lobby")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-output/setup-v05-multi.png") == OK, "saved multiplayer screenshot")
	setup.queue_free()
	await process_frame

	print("INTEGRATED_V05 checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
