extends PanelContainer
## Built immediately after the Station base class, because everything after it
## is faster with it. Toggled with ` or F1, or by typing `cheat` in the rocket
## box -- which also marks the run, permanently.
##
## Controls are built in code on purpose: this is a tool, it has no art to
## swap, and a hand-maintained .tscn of forty widgets is forty things to keep
## in sync with the game.

const STATIONS := ["hourglass", "clock", "safe", "rocket"]

var _readout: Label
var _difficulty_slider: HSlider
var _difficulty_value: Label
var _time_slider: HSlider
var _time_value: Label
var _cheated_label: Label

@onready var content: VBoxContainer = $Scroll/Content


func _ready() -> void:
	_build()
	GameManager.cheats_enabled_changed.connect(_refresh_cheat_notice)
	_refresh_cheat_notice(GameManager.cheats_enabled)


func _process(_delta: float) -> void:
	if not visible:
		return
	_readout.text = _build_readout()


func _build() -> void:
	_header("DEBUG")
	_cheated_label = _label("")
	_header("Unlock")
	for id in STATIONS:
		var check := CheckBox.new()
		check.text = id
		check.button_pressed = false
		check.toggled.connect(_on_unlock_toggled.bind(id))
		content.add_child(check)
	var auto_button := _button("clear overrides")
	auto_button.pressed.connect(func() -> void:
		GameManager.debug_unlock_overrides.clear()
		for child in content.get_children():
			if child is CheckBox and child.text in STATIONS:
				child.set_pressed_no_signal(false))

	_header("Ramp")
	var diff_row := _row()
	_difficulty_slider = HSlider.new()
	_difficulty_slider.min_value = -0.01
	_difficulty_slider.max_value = 1.0
	_difficulty_slider.step = 0.01
	_difficulty_slider.value = -0.01
	_difficulty_slider.custom_minimum_size = Vector2(150, 0)
	_difficulty_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_difficulty_slider.value_changed.connect(_on_difficulty_changed)
	diff_row.add_child(_make_label("difficulty"))
	diff_row.add_child(_difficulty_slider)
	_difficulty_value = _make_label("auto")
	diff_row.add_child(_difficulty_value)

	var time_row := _row()
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.1
	_time_slider.max_value = 5.0
	_time_slider.step = 0.1
	_time_slider.value = 1.0
	_time_slider.custom_minimum_size = Vector2(150, 0)
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.value_changed.connect(_on_time_scale_changed)
	time_row.add_child(_make_label("time scale"))
	time_row.add_child(_time_slider)
	_time_value = _make_label("1.0x")
	time_row.add_child(_time_value)

	_header("Jump to phase")
	var phase_row := _row()
	for i in GameManager.PHASES.size():
		var b := Button.new()
		b.text = str(i + 1)
		b.pressed.connect(GameManager.jump_to_phase.bind(i))
		phase_row.add_child(b)

	_header("Safe")
	var tier_row := _row()
	tier_row.add_child(_make_label("tier"))
	for tier in [-1, 0, 1, 2]:
		var b := Button.new()
		b.text = "auto" if tier < 0 else str(tier)
		b.pressed.connect(_on_safe_tier.bind(tier))
		tier_row.add_child(b)
	_button("shuffle now").pressed.connect(func() -> void:
		var safe := GameManager.get_station("safe")
		if safe != null and safe.has_method("force_shuffle"):
			safe.force_shuffle())

	_header("Hearts & mistakes")
	var inv := CheckBox.new()
	inv.text = "invincible"
	inv.toggled.connect(func(on: bool) -> void: GameManager.debug_invincible = on)
	content.add_child(inv)
	var heart_row := _row()
	var plus := Button.new()
	plus.text = "+1 heart"
	plus.pressed.connect(func() -> void:
		GameManager.hearts = mini(GameManager.hearts + 1, GameManager.MAX_HEARTS)
		GameManager.mistake_made.emit(GameManager.hearts))
	heart_row.add_child(plus)
	var minus := Button.new()
	minus.text = "-1 heart"
	minus.pressed.connect(func() -> void:
		GameManager.register_mistake("debug"))
	heart_row.add_child(minus)

	_header("Force")
	for id in STATIONS:
		var row := _row()
		row.add_child(_make_label(id))
		var fail_button := Button.new()
		fail_button.text = "fail"
		fail_button.pressed.connect(_on_force_fail.bind(id))
		row.add_child(fail_button)
		var service_button := Button.new()
		service_button.text = "service"
		service_button.pressed.connect(_on_force_service.bind(id))
		row.add_child(service_button)

	_header("Timers")
	var freeze := CheckBox.new()
	freeze.text = "freeze timers"
	freeze.toggled.connect(func(on: bool) -> void:
		GameManager.debug_freeze_timers = on)
	content.add_child(freeze)
	_button("trigger dividend").pressed.connect(func() -> void:
		GameManager.trigger_dividend("debug"))

	_header("Live")
	_readout = _label("")
	_readout.add_theme_font_size_override("font_size", 12)


func _build_readout() -> String:
	var lines := PackedStringArray()
	lines.append("difficulty %.2f   phase %s   t %.1f" % [
		GameManager.get_difficulty(), GameManager.get_phase_name(),
		GameManager.elapsed_time])
	lines.append("last progress: '%s'   cooldown %.2f   freeze %.2f" % [
		GameManager.last_progress_station, GameManager.dividend_cooldown,
		GameManager.freeze_remaining])
	lines.append("dividends %d   hearts %d   score %d" % [
		GameManager.dividend_count, GameManager.hearts, GameManager.score])
	for id in STATIONS:
		var station: Station = GameManager.get_station(id)
		if station == null:
			continue
		var flags := ""
		if not station.is_unlocked:
			flags += " LOCKED"
		if station.is_locked_out:
			flags += " LOCKOUT"
		if station.is_timer_paused:
			flags += " PAUSED"
		lines.append("%-9s %6.2f / %5.2f   urg %.2f%s" % [
			id, station.time_remaining, station.get_current_duration(),
			station.get_urgency(), flags])
	return "\n".join(lines)


# --- handlers ----------------------------------------------------------------

func _on_unlock_toggled(pressed: bool, station_id: String) -> void:
	GameManager.debug_unlock_overrides[station_id] = pressed


func _on_difficulty_changed(value: float) -> void:
	if value < 0.0:
		GameManager.debug_difficulty_override = -1.0
		_difficulty_value.text = "auto"
	else:
		GameManager.debug_difficulty_override = value
		_difficulty_value.text = "%.2f" % value


func _on_time_scale_changed(value: float) -> void:
	GameManager.debug_time_scale = value
	_time_value.text = "%.1fx" % value


func _on_safe_tier(tier: int) -> void:
	var safe := GameManager.get_station("safe")
	if safe != null and safe.has_method("set_debug_tier"):
		safe.set_debug_tier(tier)


func _on_force_fail(station_id: String) -> void:
	var station: Station = GameManager.get_station(station_id)
	if station != null:
		station.fail()


func _on_force_service(station_id: String) -> void:
	var station: Station = GameManager.get_station(station_id)
	if station == null:
		return
	# Drive it to the wire first, so "force service" exercises the clutch path
	# rather than the anti-spam path.
	station.time_remaining = station.get_current_duration() * 0.05
	station.service(10)


func _refresh_cheat_notice(_enabled: bool) -> void:
	if GameManager.run_was_cheated:
		_cheated_label.text = "RUN FLAGGED AS CHEATED"
		_cheated_label.modulate = Color(0.95, 0.55, 0.3)
	else:
		_cheated_label.text = "run is clean"
		_cheated_label.modulate = Color(0.6, 0.65, 0.72)


# --- tiny widget helpers -----------------------------------------------------

func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(0.55, 0.78, 0.95)
	content.add_child(label)
	return label


## Unparented, for callers that put it in a row.
func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	return label


func _label(text: String) -> Label:
	var label := _make_label(text)
	content.add_child(label)
	return label


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	content.add_child(row)
	return row


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	content.add_child(button)
	return button
