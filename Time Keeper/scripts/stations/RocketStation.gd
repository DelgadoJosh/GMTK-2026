extends Station
## Keyboard-only. Click the box to focus, type each word, press Enter.
##
## The keypad is pointer-driven and this is keyboard-driven, so late game you
## are using both hands on different problems and cannot batch them. It also
## sidesteps the focus collision where pressing 7 for the safe types a 7 in
## here.

signal console_word(command: String)

const POINTS := 100
const WORDS := [
	"ten", "nine", "eight", "seven", "six", "five", "four", "three", "two",
	"one", "we have liftoff",
]

## The launch window is the Station countdown (base_duration/floor_duration).
## The idle gap between windows is its own ramp.
@export var idle_base: float = 35.0
@export var idle_floor: float = 18.0

const COLOR_TYPED := "#e8ecf4"
const COLOR_TYPO := "#e8946a"
const COLOR_GHOST := "#5b6270"
const COLOR_CARET := "#8fd694"

var _is_idle: bool = true
var _word_index: int = 0
var _klaxon_tween: Tween

@onready var input: LineEdit = $Layout/Stack/Body/Console/Field/Input
@onready var ghost: RichTextLabel = $Layout/Stack/Body/Console/Field/Ghost
@onready var next_label: Label = $Layout/Stack/Body/Console/NextLabel
@onready var klaxon_panel: NinePatchRect = $Layout/Stack/Body/Console/Field/Frame
@onready var rocket: TextureRect = $Layout/Stack/Body/Pad/Rocket
@onready var flame: TextureRect = $Layout/Stack/Body/Pad/Rocket/Flame


func _ready() -> void:
	super._ready()
	input.text_submitted.connect(_on_submitted)
	input.gui_input.connect(_on_input_gui_input)
	input.text_changed.connect(func(_t: String) -> void: _refresh_ghost())
	input.focus_entered.connect(_refresh_ghost)
	input.focus_exited.connect(_refresh_ghost)
	# The real text is invisible; the ghost overlay draws every character, so
	# typed and untyped can be coloured differently in the same box.
	input.add_theme_color_override("font_color", Color.TRANSPARENT)
	input.add_theme_color_override("font_uneditable_color", Color.TRANSPARENT)
	input.add_theme_color_override("caret_color", Color.TRANSPARENT)
	input.focus_mode = Control.FOCUS_CLICK
	flame.visible = false
	_go_idle(false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and input.has_focus():
		input.release_focus()
		get_viewport().set_input_as_handled()


func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_V \
			and (event.ctrl_pressed or event.meta_pressed):
		# Paste is blocked. Pasting "we have liftoff" is not a countdown.
		input.accept_event()


# --- window lifecycle --------------------------------------------------------

## While idle the countdown measures the gap to the next launch window, so the
## duration has to switch with the state.
func get_current_duration() -> float:
	if _is_idle:
		return lerpf(idle_base, idle_floor, GameManager.get_difficulty())
	return super.get_current_duration()


func _expire() -> void:
	if _is_idle:
		_open_window()
	else:
		_scrub()


func _open_window() -> void:
	_is_idle = false
	_word_index = 0
	input.text = ""
	time_remaining = get_current_duration()
	Sfx.play("klaxon")
	# The klaxon and the flashing panel are the announcement. Focus is not
	# stolen -- walking over to click the box is part of the cost.
	_stop_klaxon()
	_klaxon_tween = create_tween()
	_klaxon_tween.set_loops(6)
	_klaxon_tween.tween_property(klaxon_panel, "modulate", COLOR_CRIT, 0.12)
	_klaxon_tween.tween_property(klaxon_panel, "modulate", Color.WHITE, 0.12)
	_refresh_ghost()


func _stop_klaxon() -> void:
	# Killed explicitly: a live tween would keep repainting the frame after the
	# window has closed, leaving an idle station flashing for attention.
	if _klaxon_tween != null and _klaxon_tween.is_valid():
		_klaxon_tween.kill()
	_klaxon_tween = null


func _go_idle(reset_timer: bool = true) -> void:
	_is_idle = true
	_word_index = 0
	input.text = ""
	if input.has_focus():
		input.release_focus()
	if reset_timer:
		time_remaining = get_current_duration()
	_stop_klaxon()
	klaxon_panel.modulate = Color.WHITE
	_refresh_ghost()


func _scrub() -> void:
	# Idle first: begin_lockout inside fail() resets the countdown, and it has
	# to reset to the idle gap rather than to another launch window.
	_go_idle(false)
	fail()


func _launch() -> void:
	Sfx.play("launch")
	service(POINTS)
	_animate_launch()
	_go_idle()


func _animate_launch() -> void:
	flame.visible = true
	var start := rocket.position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(rocket, "position:y", start.y - 320.0, 0.9)
	tween.tween_callback(func() -> void:
		flame.visible = false
		rocket.position = start)


# --- submission --------------------------------------------------------------

func _on_submitted(raw: String) -> void:
	var text := raw.strip_edges()
	# Console words are matched before the launch-word matcher, and are always
	# consumed -- they never count as a typo and never eat the target word.
	var command := ConsoleWords.match_word(text)
	if command != "":
		input.text = ""
		_refresh_ghost()
		console_word.emit(command)
		return
	if text == "":
		return                      # Enter on an empty box is a no-op
	if not can_interact() or _is_idle:
		input.text = ""
		_refresh_ghost()
		return
	if text.to_lower() == _current_word():
		_accept_word()
	else:
		_reject_word()


func _accept_word() -> void:
	_word_index += 1
	input.text = ""
	Sfx.play("keypad_beep", 1.0 + 0.04 * _word_index, -4.0)
	note_progress(true)
	if _word_index >= WORDS.size():
		_launch()
	else:
		_refresh_ghost()


func _reject_word() -> void:
	# Wrong word costs time, never a heart. Q1/13.1: the box clears rather than
	# keeping the text to fix -- the cheapest thing here to flip after a
	# playtest is this one line.
	input.text = ""
	Sfx.play("keypad_beep", 0.5, -2.0)
	_refresh_ghost()
	var start := input.position.x
	var tween := create_tween()
	for offset in [8.0, -6.0, 4.0, 0.0]:
		tween.tween_property(input, "position:x", start + offset, 0.04)


func _current_word() -> String:
	if _word_index >= WORDS.size():
		return ""
	return WORDS[_word_index]


# --- ghost text --------------------------------------------------------------

func _refresh_ghost() -> void:
	if _is_idle:
		next_label.text = "NO LAUNCH SCHEDULED"
		# Typed text has to be visible while idle too. This is exactly when a
		# console word gets typed, and a box that swallows what you type is
		# indistinguishable from one that isn't listening.
		if input.text != "":
			ghost.text = "[color=%s]%s[/color]%s" % [COLOR_TYPED,
				_escape(input.text), _caret()]
		elif input.has_focus():
			ghost.text = "[color=%s]standing by[/color]%s" % [COLOR_GHOST,
				_caret()]
		else:
			ghost.text = "[color=%s]standing by  (click to focus)[/color]" % \
				COLOR_GHOST
		return
	var target := _current_word()
	next_label.text = "SAY: %s   (%d/%d)" % [target.to_upper(), _word_index + 1,
		WORDS.size()]
	var typed := input.text
	var out := ""
	for i in maxi(typed.length(), target.length()):
		if i < typed.length():
			var ch := typed[i]
			var ok: bool = i < target.length() and ch.to_lower() == target[i]
			out += "[color=%s]%s[/color]" % [COLOR_TYPED if ok else COLOR_TYPO,
				_escape(ch)]
		else:
			out += "[color=%s]%s[/color]" % [COLOR_GHOST, _escape(target[i])]
	out += _caret() if input.has_focus() \
		else "[color=%s]  (click to focus)[/color]" % COLOR_GHOST
	ghost.text = out


func _caret() -> String:
	return "[color=%s]_[/color]" % COLOR_CARET


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


# --- station overrides -------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if _is_idle:
		# An idle rocket is not an emergency; it must not join the tick ladder.
		Sfx.clear_urgency(station_id)


func _update_visuals() -> void:
	super._update_visuals()
	if not is_unlocked or not _is_idle:
		return
	# While idle the bar fills toward the next window instead of draining
	# toward a failure, and the panel stays calm.
	bar.value = 1.0 - get_remaining_fraction()
	_bar_fill.bg_color = Color(0.35, 0.52, 0.78)
	if not is_locked_out:
		background.modulate = Color.WHITE


func _status_text() -> String:
	if _is_idle:
		return "NEXT WINDOW  %.1fs" % maxf(time_remaining, 0.0)
	return "LAUNCH WINDOW  %.1fs" % maxf(time_remaining, 0.0)


func _lockout_text() -> String:
	return "LAUNCH SCRUBBED  %.1fs" % maxf(lockout_remaining, 0.0)


func _on_reset() -> void:
	_go_idle(false)
