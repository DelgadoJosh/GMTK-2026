extends PanelContainer
## The rules panel, opened from the title card.
##
## Every number in here is read off the constant that actually drives it, so the
## instructions cannot quietly start lying after a balance pass. If a value below
## looks wrong, the fix is in the station, not in this file.

signal closed

const HOURGLASS := preload("res://scripts/stations/HourglassStation.gd")
const CLOCK := preload("res://scripts/stations/ClockStation.gd")
const SAFE := preload("res://scripts/stations/SafeStation.gd")
const ROCKET := preload("res://scripts/stations/RocketStation.gd")

const GOLD := "c79e4a"
const DIM := "8d93a1"
const GREEN := "5cbf6b"
const AMBER := "ebad33"
const RED := "d93d38"

var _focus_before: Control = null

@onready var body: RichTextLabel = $Center/Panel/Margin/Stack/Scroll/Body
@onready var close_button: Button = $Center/Panel/Margin/Stack/Close


func _ready() -> void:
	close_button.pressed.connect(close)
	body.text = _build()
	visible = false


func open() -> void:
	if visible:
		return
	visible = true
	$Center/Panel/Margin/Stack/Scroll.scroll_vertical = 0
	_focus_before = get_viewport().gui_get_focus_owner()
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play("click")
	if is_instance_valid(_focus_before):
		_focus_before.grab_focus()
	_focus_before = null
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- content -----------------------------------------------------------------

func _build() -> String:
	var out := PackedStringArray()

	out.append(_heading("THE JOB"))
	# Note the parentheses around every concatenation that is then formatted:
	# in GDScript `%` binds tighter than `+`, so without them the arguments
	# would be applied to the last fragment alone.
	out.append(("Every station in the facility runs a countdown. Keep all of them"
		+ " off zero. Let one hit zero and that is a mistake —"
		+ " [color=%s]%d mistakes and you are fired[/color].")
		% [RED, GameManager.STARTING_HEARTS])
	out.append("Stations unlock one at a time as your shift goes on, and every"
		+ " countdown gets shorter the longer you last. There is no winning, only"
		+ " lasting.")

	out.append(_station("HOURGLASS", "mouse", HOURGLASS.POINTS))
	out.append("Click anywhere on the panel to flip it. The sand resets. That is"
		+ " the entire station, and it will still be demanding your attention at"
		+ " minute four.")

	out.append(_station("WIND-UP CLOCK", "click and hold", CLOCK.POINTS))
	out.append(("Hold the winding key to raise the mainspring tension. You score"
		+ " each time you wind it [i]up[/i] out of the amber and into the green"
		+ " (past %d tension) — so letting it fall and catching it is worth more"
		+ " than topping it up constantly.") % int(CLOCK.GREEN_TENSION))
	out.append(("[color=%s]Careful:[/color] holding inside the red band (%d+) for"
		+ " %.1fs snaps the spring. That costs a heart and %ds of repairs.")
		% [RED, int(CLOCK.OVERWIND_MIN), CLOCK.SNAP_TIME, int(CLOCK.SNAP_LOCKOUT)])

	out.append(_station("SAFE KEYPAD", "mouse", SAFE.POINTS))
	out.append("Press 9, 8, 7 … 1, 0 in order before the vault re-locks. The code"
		+ " is always the descending count, so there is nothing to memorise — the"
		+ " difficulty is in [i]finding[/i] the digits.")
	out.append(("Every correct digit adds [color=%s]%ds[/color] back to the"
		+ " re-lock timer.") % [GREEN, int(Station.PROGRESS_TIME_BONUS)])
	out.append(("A wrong key — including the dead * and # keys — costs no heart"
		+ " and does [i]not[/i] wipe the digits you already got. It kills the pad"
		+ " for %ds while the timer keeps running, so guessing is still a bad"
		+ " idea.") % int(SAFE.MISKEY_FREEZE))
	out.append(("[color=%s]Later in the shift the keys shuffle position on every"
		+ " re-lock, and later still they turn into symbols with a codex to read"
		+ " off.[/color]") % DIM)

	out.append(_station("ROCKET LAUNCH", "keyboard", ROCKET.POINTS))
	out.append("Launch windows open on their own schedule — a klaxon and a"
		+ " flashing panel announce them. Between windows there is nothing to do"
		+ " here.")
	out.append("Click the box, then type each word of the countdown and press"
		+ " Enter after each one: [i]ten, nine, eight … one, we have liftoff[/i]."
		+ " The box keeps focus until you click away, so you only click once.")
	out.append(("Every accepted word adds [color=%s]%ds[/color] back to the"
		+ " window. If the window closes mid-sequence the launch is scrubbed, and"
		+ " that is a mistake.") % [GREEN, int(Station.PROGRESS_TIME_BONUS)])

	out.append(_heading("POINTS"))
	out.append(("Hourglass [b]%d[/b]  ·  Wind-up clock [b]%d[/b]  ·  Safe"
		+ " [b]%d[/b]  ·  Rocket [b]%d[/b]")
		% [HOURGLASS.POINTS, CLOCK.POINTS, SAFE.POINTS, ROCKET.POINTS])
	out.append(("[color=%s]Clutch bonus — ×%d[/color] for servicing a station"
		+ " while it is already in the red (under %d%% left). Cutting it fine"
		+ " pays.") % [AMBER, GameManager.CLUTCH_MULTIPLIER,
			int(GameManager.CLUTCH_REMAINING * 100.0)])
	out.append(("Servicing a station that is still over %d%% full is worth"
		+ " [b]nothing[/b] — no farming an hourglass you just flipped. When that"
		+ " is the case the station's fill bar goes [color=%s]dark green[/color]"
		+ " and its status line reads NO POINTS YET, so you never have to guess.")
		% [int(GameManager.ANTI_SPAM_REMAINING * 100.0), GREEN])
	out.append(("[color=%s]The safe and the rocket are exempt — ten ordered clicks"
		+ " and eleven typed words are far too slow to farm, so those two always"
		+ " pay in full.[/color]") % DIM)

	out.append(_heading("TIME DIVIDEND"))
	out.append("Working one station in peace should feel worse than juggling four."
		+ " So: [b]every time you make progress on a station you were not just"
		+ " working on, every countdown in the facility freezes for a"
		+ " moment.[/b]")
	out.append("Switching [i]is[/i] the reward. Bouncing between stations buys you"
		+ " time that camping one never will, and the banner across the top of the"
		+ " screen names the station each time you earn one.")
	out.append("It only pays for progress that was worth points, and there is a"
		+ " short cooldown between them — so you cannot farm it by tapping two"
		+ " stations back and forth.")

	return "\n\n".join(out)


func _heading(text: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [GOLD, text]


## Station headings carry the input device as well as the name. Which hand a
## station wants is what makes four at once hard, and it is the one thing you
## cannot tell by looking at the panel.
func _station(title: String, input_kind: String, points: int) -> String:
	return "[color=%s][b]%s[/b][/color]   [color=%s]%s  ·  %d points[/color]" % [
		GOLD, title, DIM, input_kind, points]
