extends Node
## Layout check: boots the real Main scene with every station unlocked and
## saves a PNG. Not part of the game; run it after touching a station scene.
##   godot res://tools/Screenshot.tscn -- <output.png>

func _ready() -> void:
	var out := "screenshot.png"
	var mode := "shift"
	for arg in OS.get_cmdline_user_args():
		if arg == "gameover":
			mode = arg
		else:
			out = arg
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.debug_unlock_overrides = {
		"hourglass": true, "clock": true, "safe": true, "rocket": true}
	GameManager.debug_difficulty_override = 0.7
	GameManager.elapsed_time = 134.0
	GameManager.add_score(1240)
	GameManager.hearts = 2
	GameManager.mistake_made.emit(2)
	# Frames so the unlock overrides land before the per-station setup, which
	# unlocking would otherwise reset. `process_frame` fires before nodes get
	# their `_process`, so one await is not one full frame of station logic --
	# with only one, the keypad presses below arrive at a station that is still
	# locked, get dropped by can_interact(), and then the unlock wipes the entry.
	for _i in 3:
		await get_tree().process_frame
	var safe = GameManager.get_station("safe")
	safe.set_debug_tier(1)
	safe._rearm()
	safe._on_key_pressed(safe._cells.find("9"))
	safe._on_key_pressed(safe._cells.find("8"))
	safe._on_key_pressed(safe._cells.find("7"))
	var clock = GameManager.get_station("clock")
	clock.time_remaining = clock.get_current_duration() * 0.9
	var rocket = GameManager.get_station("rocket")
	rocket._open_window()
	rocket._word_index = 3
	rocket.input.text = "sevn"
	rocket.input.grab_focus()
	rocket._refresh_ghost()
	var hourglass = GameManager.get_station("hourglass")
	hourglass.time_remaining = hourglass.get_current_duration() * 0.22
	if mode == "gameover":
		GameManager.service_counts = {"hourglass": 21, "clock": 14, "safe": 6,
			"rocket": 3}
		GameManager.mistake_counts = {"clock": 1, "safe": 1, "rocket": 1}
		GameManager.dividend_count = 47
		GameManager.hearts = 1
		GameManager.register_mistake("rocket")
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("wrote ", out)
	get_tree().quit()
