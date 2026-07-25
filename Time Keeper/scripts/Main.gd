extends Control
## Wires the shift together: HUD, the station grid, the debug panel, the
## easter-egg dialog and the score screen. Owns the global feedback overlays.

@onready var station_grid: GridContainer = $Root/StationGrid
@onready var dividend_pulse: TextureRect = $Overlays/DividendPulse
@onready var mistake_vignette: TextureRect = $Overlays/MistakeVignette
@onready var mistake_stamp: Label = $Overlays/MistakeStamp
@onready var pause_overlay: Control = $Overlays/PauseOverlay
@onready var debug_panel: Control = $DebugPanel
@onready var easter_egg_dialog: Control = $DialogLayer/EasterEggDialog
@onready var game_over_screen: Control = $GameOverLayer/GameOver


func _ready() -> void:
	dividend_pulse.modulate.a = 0.0
	mistake_vignette.modulate.a = 0.0
	mistake_stamp.modulate.a = 0.0
	pause_overlay.visible = false
	game_over_screen.visible = false
	easter_egg_dialog.visible = false
	debug_panel.visible = false

	GameManager.dividend_earned.connect(_on_dividend_earned)
	GameManager.mistake_made.connect(_on_mistake_made)
	GameManager.game_over.connect(_on_game_over)
	GameManager.focus_pause_changed.connect(_on_focus_pause_changed)

	for station in station_grid.get_children():
		if station is Station and station.has_signal("console_word"):
			station.console_word.connect(_on_console_word)

	game_over_screen.retry_pressed.connect(_start_run)
	easter_egg_dialog.closed.connect(_on_dialog_closed)

	_start_run()


func _start_run() -> void:
	game_over_screen.visible = false
	GameManager.start_run()


func _input(event: InputEvent) -> void:
	# Handled here, before any LineEdit sees it -- otherwise typing a backtick
	# into the rocket box would open the debug panel, or worse, wouldn't.
	if event.is_action_pressed("debug_toggle"):
		debug_panel.visible = not debug_panel.visible
		get_viewport().set_input_as_handled()


func _on_console_word(command: String) -> void:
	match command:
		"easter_egg":
			easter_egg_dialog.open()
		"cheat":
			GameManager.enable_cheats()
			debug_panel.visible = true


func _on_dialog_closed() -> void:
	pass


func _on_dividend_earned(_from_station: String) -> void:
	Sfx.play("dividend")
	dividend_pulse.modulate = Color(0.72, 0.86, 1.0, 0.85)
	var tween := create_tween()
	tween.tween_property(dividend_pulse, "modulate:a", 0.0, 0.45)


func _on_mistake_made(_remaining_hearts: int) -> void:
	Sfx.play("mistake")
	mistake_vignette.modulate = Color(0.85, 0.18, 0.16, 0.9)
	mistake_stamp.modulate.a = 1.0
	mistake_stamp.scale = Vector2(1.4, 1.4)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mistake_vignette, "modulate:a", 0.0, 0.55)
	tween.tween_property(mistake_stamp, "scale", Vector2.ONE, 0.18)
	tween.chain().tween_interval(0.25)
	tween.chain().tween_property(mistake_stamp, "modulate:a", 0.0, 0.3)


func _on_game_over(final_time: float, final_score: int, cheated: bool) -> void:
	Sfx.play("fired")
	game_over_screen.show_results(final_time, final_score, cheated)


func _on_focus_pause_changed(paused: bool) -> void:
	# Browsers keep the canvas ticking in a background tab; without this the
	# facility drains while nobody is watching.
	pause_overlay.visible = paused and GameManager.is_running
