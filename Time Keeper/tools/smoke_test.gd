extends Node
## Headless smoke test for the plan's section 14 edge-case list.
##
## Run from the project root:
##   godot --headless res://tools/SmokeTest.tscn
##
## It drives the real scene with simulated frames rather than mocking, so a
## broken node path or a bad signal wiring fails here rather than in the jam
## build.

var _failures: int = 0
var _checks: int = 0

# Deliberately untyped: the tests reach into subclass state (_cells,
# _word_index) that the Station base class doesn't declare.
var main: Node
var hourglass
var clock
var safe
var rocket


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	main = packed.instantiate()
	# Deferred: the tree is still setting up children during _ready.
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame

	hourglass = GameManager.get_station("hourglass")
	clock = GameManager.get_station("clock")
	safe = GameManager.get_station("safe")
	rocket = GameManager.get_station("rocket")

	_test_boot()
	await _test_unlocks()
	await _test_dividends()
	await _test_hearts()
	await _test_safe()
	await _test_rocket_and_console()
	await _test_scoring()
	await _test_progression()
	await _test_clock()

	print("")
	print("%d checks, %d failures" % [_checks, _failures])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)


func step(seconds: float, frames: int = 1) -> void:
	# The game runs off _process deltas; SceneTree.process_frame doesn't
	# advance a fixed clock headlessly, so time is injected directly.
	for i in frames:
		GameManager.elapsed_time += seconds / frames
	await get_tree().process_frame


func drain(station, seconds: float) -> void:
	station.time_remaining -= seconds
	await get_tree().process_frame


# --- tests -------------------------------------------------------------------

func _test_boot() -> void:
	print("\n-- boot")
	check(hourglass != null and clock != null and safe != null and rocket != null,
		"all four stations registered with GameManager")
	check(GameManager.is_running, "run started automatically")
	check(GameManager.hearts == 3, "three hearts")


func _test_unlocks() -> void:
	print("\n-- unlocks")
	check(hourglass.is_unlocked, "hourglass unlocked at 0s")
	check(not clock.is_unlocked, "clock still locked at 0s")
	# The unlock times on the scenes and the phase table in GameManager are two
	# copies of the same schedule, so check they still agree.
	check(clock.unlock_time == float(GameManager.PHASES[1]["time"])
		and safe.unlock_time == float(GameManager.PHASES[2]["time"])
		and rocket.unlock_time == float(GameManager.PHASES[3]["time"]),
		"station unlock times match the phase table")
	GameManager.elapsed_time = clock.unlock_time + 1.0
	await get_tree().process_frame
	check(clock.is_unlocked, "clock unlocked past its unlock time")
	check(clock.time_remaining > clock.get_current_duration() * 0.99,
		"clock arrives with a full countdown, not an expiring one")

	# Veteran opens with the whole facility live.
	GameManager.elapsed_time = 0.0
	GameManager.difficulty_mode = GameManager.Difficulty.VETERAN
	await get_tree().process_frame
	check(clock.is_unlocked and safe.is_unlocked and rocket.is_unlocked,
		"veteran starts with all four stations at 0s")
	GameManager.difficulty_mode = GameManager.Difficulty.STANDARD
	await get_tree().process_frame
	check(not rocket.is_unlocked, "standard puts the rocket back behind the clock")

	GameManager.elapsed_time = 0.0
	GameManager.debug_unlock_overrides = {
		"clock": true, "safe": true, "rocket": true}
	await get_tree().process_frame
	check(clock.is_unlocked and safe.is_unlocked and rocket.is_unlocked,
		"debug unlock overrides force stations on")


func _test_dividends() -> void:
	print("\n-- time dividend")
	GameManager.last_progress_station = ""
	GameManager.dividend_cooldown = 0.0
	GameManager.dividend_count = 0

	GameManager.register_progress("hourglass", true)
	check(GameManager.dividend_count == 1, "first progress point pays a dividend")
	GameManager.register_progress("hourglass", true)
	check(GameManager.dividend_count == 1,
		"two progress points from the same station in a row -> one dividend")

	GameManager.dividend_cooldown = 0.0
	GameManager.register_progress("clock", true)
	GameManager.dividend_cooldown = 0.0
	GameManager.register_progress("hourglass", true)
	check(GameManager.dividend_count == 3, "A -> B -> A gives three dividends")

	GameManager.dividend_cooldown = 0.0
	GameManager.register_progress("safe", false)
	check(GameManager.dividend_count == 3,
		"unscored progress earns no dividend")
	check(GameManager.last_progress_station == "hourglass",
		"unscored progress does not claim the switch slot")

	var before := GameManager.dividend_count
	GameManager.dividend_cooldown = 0.0
	GameManager.register_progress("safe", true)
	GameManager.register_progress("rocket", true)
	check(GameManager.dividend_count == before + 1,
		"cooldown suppresses a second dividend inside 0.75s")

	GameManager.freeze_remaining = 0.0
	GameManager.trigger_dividend("safe")
	var first_freeze := GameManager.freeze_remaining
	GameManager.trigger_dividend("rocket")
	check(is_equal_approx(GameManager.freeze_remaining, first_freeze),
		"overlapping dividends don't stack into a long freeze")

	GameManager.mistake_freeze_remaining = 0.3
	GameManager.dividend_cooldown = 0.0
	GameManager.last_progress_station = "safe"
	var count := GameManager.dividend_count
	GameManager.register_progress("rocket", true)
	check(GameManager.dividend_count == count,
		"no dividend during the post-mistake freeze")
	GameManager.mistake_freeze_remaining = 0.0

	check(GameManager.is_frozen(), "freeze holds station countdowns")
	var remaining: float = hourglass.time_remaining
	await get_tree().process_frame
	check(is_equal_approx(hourglass.time_remaining, remaining),
		"frozen station does not drain")

	# The shift clock is deliberately outside the freeze, so a dividend is pure
	# benefit and can't be farmed for score.
	GameManager.freeze_remaining = 1.0
	var shift_before: float = GameManager.elapsed_time
	await get_tree().process_frame
	check(GameManager.elapsed_time > shift_before,
		"the shift clock keeps running through a freeze")

	# ...and it does reach the rocket's launch window.
	GameManager.debug_unlock_overrides = {"rocket": true}
	await get_tree().process_frame
	rocket._open_window()
	var window_before: float = rocket.time_remaining
	GameManager.freeze_remaining = 1.0
	await get_tree().process_frame
	check(is_equal_approx(rocket.time_remaining, window_before),
		"freeze applies to the rocket launch window too")
	rocket._go_idle()
	GameManager.freeze_remaining = 0.0


func _test_hearts() -> void:
	print("\n-- hearts and mistakes")
	GameManager.start_run()
	GameManager.debug_unlock_overrides = {
		"clock": true, "safe": true, "rocket": true}
	await get_tree().process_frame

	# Two stations expire on the same frame.
	hourglass.time_remaining = -hourglass.grace_duration - 0.01
	clock.time_remaining = -0.01
	await get_tree().process_frame
	check(GameManager.hearts == 1, "two same-frame expiries cost two hearts")
	check(hourglass.is_locked_out and clock.is_locked_out,
		"both offenders take a grace lockout")

	# The lockout has to stop an immediate re-fail.
	hourglass.time_remaining = -hourglass.grace_duration - 0.01
	await get_tree().process_frame
	check(GameManager.hearts == 1, "grace lockout prevents an immediate re-fail")

	hourglass.is_locked_out = false
	hourglass.time_remaining = -hourglass.grace_duration - 0.01
	await get_tree().process_frame
	check(GameManager.hearts == 0, "third mistake lands")
	check(not GameManager.is_running, "run ended")
	check(GameManager.fired_by == "hourglass", "the score screen knows who fired you")

	# Nothing after game over should move.
	var score_before := GameManager.score
	GameManager.register_mistake("clock")
	GameManager.add_score(500)
	check(GameManager.hearts == 0, "hearts don't go negative after game over")
	check(GameManager.score == score_before, "score doesn't tick after game over")

	# Third mistake and a service on the same frame: game over fires once.
	GameManager.start_run()
	await get_tree().process_frame
	var overs := [0]
	var conn := func(_t: float, _s: int, _c: bool) -> void: overs[0] += 1
	GameManager.game_over.connect(conn)
	GameManager.hearts = 1
	hourglass.time_remaining = hourglass.get_current_duration() * 0.05
	hourglass.service(10)
	GameManager.register_mistake("hourglass")
	GameManager.register_mistake("hourglass")
	check(overs[0] == 1, "game over fires exactly once")
	GameManager.game_over.disconnect(conn)

	GameManager.start_run()
	GameManager.debug_invincible = true
	GameManager.register_mistake("safe")
	check(GameManager.hearts == 3, "invincible swallows mistakes")
	GameManager.debug_invincible = false
	check(GameManager.last_progress_station == "",
		"last_progress_station resets on a new run")


func _test_safe() -> void:
	print("\n-- safe keypad")
	GameManager.start_run()
	GameManager.debug_unlock_overrides = {
		"clock": true, "safe": true, "rocket": true}
	await get_tree().process_frame

	var keys: Array = safe.get_node("Layout/Stack/Body/Console/Keypad").get_children()
	check(keys.size() == 12, "12 cells for 10 digits and 2 dead keys")

	var dead_cell: int = safe._cells.find("*")
	var hearts_before := GameManager.hearts
	safe._on_key_pressed(dead_cell)
	check(GameManager.hearts == hearts_before, "a dead key costs no heart")
	check(safe._miskey_freeze > 0.0, "a dead key deadens the pad")
	var frozen_entry: int = safe._entry_index
	safe._on_key_pressed(safe._cells.find("9"))
	check(safe._entry_index == frozen_entry,
		"presses during the miskey freeze register as nothing")
	safe._end_miskey_freeze()

	# Each correct digit buys the re-lock countdown back up, capped at full.
	safe.time_remaining = 4.0
	safe._on_key_pressed(safe._cells.find("9"))
	check(safe.time_remaining > 8.99, "a correct digit buys back five seconds")
	safe.time_remaining = safe.get_current_duration()
	safe._on_key_pressed(safe._cells.find("8"))
	check(safe.time_remaining <= safe.get_current_duration() + 0.001,
		"the refill is capped at a full re-lock timer")
	safe._on_reset()
	safe._state = 0

	# Walk the whole descending code. Ten correct digits in a row is ten
	# progress points from one station, which is one switch and one dividend.
	GameManager.last_progress_station = ""
	GameManager.dividend_cooldown = 0.0
	GameManager.dividend_count = 0
	for digit in SafeStationCode.code_of(safe):
		GameManager.dividend_cooldown = 0.0
		safe._on_key_pressed(safe._cells.find(digit))
	check(GameManager.dividend_count == 1,
		"ten safe digits in a row -> one dividend, even with no cooldown")
	check(safe._state == 1, "pressing 0 opens the safe")
	var entry_after_open: int = safe._entry_index
	safe._on_key_pressed(safe._cells.find("9"))
	check(safe._entry_index == entry_after_open,
		"presses after opening don't restart an entry")
	check(safe.is_timer_paused, "re-lock timer paused while the door is open")

	# Wrong digit mid-entry: the entry survives now, the pad goes dead instead.
	safe._on_reset()
	safe._state = 0
	safe._on_key_pressed(safe._cells.find("9"))
	safe._on_key_pressed(safe._cells.find("8"))
	var kept: int = safe._entry_index
	safe._on_key_pressed(safe._cells.find("4"))
	check(safe._entry_index == kept, "a wrong digit keeps the entry so far")
	check(safe._miskey_freeze > 0.0, "a wrong digit deadens the pad instead")
	safe._end_miskey_freeze()

	# Shuffle: input-locked, timer paused, never identical.
	safe.set_debug_tier(1)
	var before: Array = safe._cells.duplicate()
	safe.force_shuffle()
	check(safe._state == 2, "shuffle enters the input-locked state")
	check(safe.is_timer_paused, "re-lock timer is paused for the shuffle")
	var idx: int = safe._entry_index
	safe._on_key_pressed(0)
	check(safe._entry_index == idx, "clicks during the shuffle register as nothing")
	check(safe._cells != before, "shuffle never reproduces the previous layout")

	# Crossing a tier threshold mid-entry must not shuffle under the player.
	safe.set_debug_tier(0)
	safe._rearm()
	safe._on_key_pressed(safe._cells.find("9"))
	safe._on_key_pressed(safe._cells.find("8"))
	var mid_entry: Array = safe._cells.duplicate()
	safe.set_debug_tier(1)
	await get_tree().process_frame
	await get_tree().process_frame
	check(safe._cells == mid_entry,
		"crossing a tier threshold mid-entry doesn't shuffle the pad")
	check(safe._entry_index == 2, "the attempt in progress is undisturbed")
	check(safe._active_tier == 0, "the new tier waits for the re-lock")

	safe.set_debug_tier(2)
	safe._rearm()
	check(safe.get_node("Layout/Stack/Body/Codex").visible,
		"tier 2 shows the codex")
	safe.set_debug_tier(-1)


func _test_rocket_and_console() -> void:
	print("\n-- rocket and console words")
	GameManager.start_run()
	GameManager.debug_unlock_overrides = {
		"clock": true, "safe": true, "rocket": true}
	await get_tree().process_frame

	var egg_seen := [false]
	rocket.console_word.connect(func(cmd: String) -> void:
		if cmd == "easter_egg":
			egg_seen[0] = true)

	check(rocket._is_idle, "rocket starts idle with no launch scheduled")
	rocket._on_submitted("  Easter Egg  ")
	check(egg_seen[0], "console words work while idle, case and space insensitive")

	rocket._expire()
	check(not rocket._is_idle, "the idle countdown opens a launch window")
	check(rocket._word_index == 0, "the window starts at 'ten'")

	rocket._on_submitted("")
	check(rocket._word_index == 0, "Enter on an empty box is a no-op")

	rocket._on_submitted("nine")
	check(rocket._word_index == 0, "a wrong word costs time, not the target word")
	check(GameManager.hearts == 3, "a wrong word costs no heart")

	rocket._on_submitted("easter egg")
	check(rocket._word_index == 0,
		"a console word during a launch doesn't consume the target word")
	# That opened the modal, which is supposed to hold the whole facility
	# still -- including this station. Close it before typing on.
	check(GameManager.modal_open, "the easter-egg dialog pauses every countdown")
	main.get_node("DialogLayer/EasterEggDialog").close()
	check(not GameManager.modal_open, "closing the dialog resumes the shift")

	rocket._on_submitted("TEN")
	check(rocket._word_index == 1, "correct word advances, case insensitive")

	for i in range(1, 10):
		rocket._on_submitted(rocket.WORDS[i])
	check(rocket._word_index == 10, "nine more words accepted")
	rocket._on_submitted("  we have liftoff  ")
	check(rocket._is_idle and rocket._word_index == 0,
		"'we have liftoff' launches; internal spaces and padding tolerated")

	# A scrubbed launch.
	rocket._expire()
	rocket._word_index = 10
	rocket.time_remaining = -0.01
	await get_tree().process_frame
	check(GameManager.hearts == 2, "window expiring on the final word is a mistake")
	check(rocket._is_idle, "a scrub returns the rocket to idle")
	check(rocket.time_remaining > rocket.idle_floor,
		"a scrubbed rocket resets to the idle gap, not another window")

	# A window opening while the box still holds text from a previous one.
	rocket._go_idle()
	rocket._expire()
	rocket._on_submitted("ten")
	rocket.input.text = "nin"
	rocket._go_idle()
	rocket._expire()
	check(rocket._word_index == 0 and rocket.input.text == "",
		"a fresh window clears leftover text and restarts at 'ten'")

	GameManager.start_run()
	rocket._on_submitted("cheat")
	await get_tree().process_frame
	check(GameManager.run_was_cheated, "'cheat' marks the run")
	GameManager.cheats_enabled = false
	check(GameManager.run_was_cheated,
		"the cheated flag survives switching cheats back off")


func _test_scoring() -> void:
	print("\n-- scoring")
	GameManager.start_run()
	await get_tree().process_frame

	hourglass.time_remaining = hourglass.get_current_duration()
	var awarded: int = hourglass.service(10)
	check(awarded == 0, "servicing a full station is worth nothing")

	hourglass.time_remaining = hourglass.get_current_duration() * 0.80
	awarded = hourglass.service(10)
	check(awarded == 10, "exactly 80% remaining still scores")

	hourglass.time_remaining = hourglass.get_current_duration() * 0.10
	awarded = hourglass.service(10)
	check(awarded == 20, "clutch doubles at the critical threshold")

	hourglass.time_remaining = hourglass.get_current_duration() * 0.5
	awarded = hourglass.service(10)
	check(awarded == 10, "a normal service pays face value")

	hourglass.time_remaining = hourglass.get_current_duration() * 0.5
	check(hourglass.is_scoring_possible(), "a half-drained station can pay")
	hourglass.time_remaining = hourglass.get_current_duration()
	check(not hourglass.is_scoring_possible(),
		"a full one-click station reports no points available")
	check(not clock.is_scoring_possible(),
		"a fully wound clock reports no points available")

	# The safe and the rocket can't be mashed -- ten ordered clicks and eleven
	# typed words -- so the anti-spam rule must not zero a fast clean run.
	for station in [safe, rocket]:
		station.time_remaining = station.get_current_duration()
		check(station.service(10, false) == 10,
			"%s pays in full at a full bar" % station.station_id)
		check(station.is_scoring_possible(),
			"%s never claims points are unavailable" % station.station_id)


func _test_progression() -> void:
	print("\n-- progression")
	GameManager.start_run()
	GameManager.debug_difficulty_override = 1.0
	await get_tree().process_frame
	check(is_equal_approx(hourglass.get_current_duration(), hourglass.floor_duration),
		"difficulty override reaches the duration calc")
	check(safe.get_tier() == 2, "difficulty override reaches the safe tier")
	GameManager.debug_difficulty_override = -1.0

	GameManager.jump_to_phase(4)
	await get_tree().process_frame
	check(hourglass.is_unlocked and clock.is_unlocked and safe.is_unlocked
		and rocket.is_unlocked, "jump to phase 5 unlocks everything")
	var sane := true
	for station in [hourglass, clock, safe, rocket]:
		if station.time_remaining < station.get_current_duration() * 0.9:
			sane = false
	check(sane, "jump to phase 5 leaves sane starting timers")

	# A large delta (5x time scale, or a browser tab hitching) overshoots zero
	# by a lot. The expiry test is a threshold, not an equality, so a station
	# can never end up sitting at negative time without having failed.
	GameManager.start_run()
	GameManager.debug_time_scale = 5.0
	await get_tree().process_frame
	hourglass.time_remaining = -40.0
	await get_tree().process_frame
	check(GameManager.hearts == 2 and hourglass.is_locked_out,
		"a countdown overshooting zero still fails exactly once")
	check(hourglass.time_remaining > 0.0,
		"no station is left sitting on negative time")
	GameManager.debug_time_scale = 1.0


func _test_clock() -> void:
	print("\n-- wind-up clock")
	GameManager.start_run()
	GameManager.debug_unlock_overrides = {"clock": true}
	await get_tree().process_frame

	# Winding up through the band from below.
	clock.time_remaining = clock.get_current_duration() * 0.5
	clock._winding = true
	for i in 200:
		clock._process(0.02)
		if clock.is_locked_out:
			break
	check(clock.is_locked_out, "winding up through the red band snaps the spring")
	check(GameManager.hearts == 2, "a snapped spring costs a heart")
	check(clock.lockout_remaining > clock.lockout_duration,
		"a snap takes the longer repair lockout, not the standard grace")

	# Starting already inside the band.
	GameManager.start_run()
	GameManager.debug_unlock_overrides = {"clock": true}
	await get_tree().process_frame
	clock.is_locked_out = false
	clock.time_remaining = clock.get_current_duration() * 0.95
	clock._winding = true
	for i in 200:
		clock._process(0.02)
		if clock.is_locked_out:
			break
	check(clock.is_locked_out, "starting inside the red band also snaps")

	# Releasing inside the band must not snap.
	GameManager.start_run()
	GameManager.debug_unlock_overrides = {"clock": true}
	await get_tree().process_frame
	clock.is_locked_out = false
	clock.time_remaining = clock.get_current_duration() * 0.95
	clock._winding = false
	for i in 100:
		clock._process(0.02)
	check(not clock.is_locked_out,
		"sitting in the band without holding the key never snaps")

	# Winding into the green scores once per crossing, not per frame.
	GameManager.start_run()
	GameManager.debug_unlock_overrides = {"clock": true}
	await get_tree().process_frame
	clock.is_locked_out = false
	clock.time_remaining = clock.get_current_duration() * 0.05
	clock._on_reset()
	var services_before: int = int(GameManager.service_counts.get("clock", 0))
	clock._winding = true
	for i in 60:
		clock._process(0.02)
		if clock.get_remaining_fraction() > 0.5:
			break
	clock._winding = false
	var gained: int = int(GameManager.service_counts.get("clock", 0)) \
		- services_before
	check(gained == 1, "one wind into the green scores exactly once")
	check(GameManager.score >= 30,
		"a save from the red zone pays the clutch bonus")


class SafeStationCode:
	static func code_of(safe_station) -> Array:
		return safe_station.CODE
