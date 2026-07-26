class_name Station
extends PanelContainer
## Base class for every station.
##
## Countdowns live in `_process` as a plain float rather than in `Timer` nodes:
## durations change continuously with difficulty, and freeze / time-scale /
## shuffle-pause all have to apply uniformly. Subclasses override interaction
## handling and the `_on_*` hooks, nothing else.

signal serviced(station_id: String, urgency: float)
signal progress(station_id: String, scored: bool)
signal failed(station_id: String)

@export var station_id: String = ""
@export var display_name: String = ""
@export var base_duration: float = 14.0
@export var floor_duration: float = 5.0
@export var unlock_time: float = 0.0
## Extra seconds past zero before the countdown actually counts as a mistake.
@export var grace_duration: float = 0.0
## Post-failure grace so a drained station can't burn every heart in a second.
@export var lockout_duration: float = 2.0

## Seconds bought back per correct partial input. See grant_time_bonus().
const PROGRESS_TIME_BONUS := 5.0

const WARNING_REMAINING := 0.25
const CRITICAL_REMAINING := 0.10
const FLASH_REMAINING := 0.05
## Slack on the scoring thresholds, so a service at exactly the boundary is not
## decided by float noise.
const THRESHOLD_EPSILON := 0.0005

const COLOR_OK := Color(0.36, 0.75, 0.42)
## Same hue as COLOR_OK, much darker: the bar is healthy *and* servicing it now
## is worth nothing. Bright green means "there are points here".
const COLOR_OK_DIM := Color(0.13, 0.28, 0.16)
const COLOR_WARN := Color(0.92, 0.68, 0.20)
const COLOR_CRIT := Color(0.85, 0.24, 0.22)
const COLOR_LOCKOUT := Color(0.45, 0.45, 0.50)

var is_unlocked: bool = false
var is_locked_out: bool = false
## Per-station pause: shuffle animation, flip tween, safe-open hold.
var is_timer_paused: bool = false
var time_remaining: float = 0.0
var lockout_remaining: float = 0.0

var _bar_fill: StyleBoxFlat
var _pulse_time: float = 0.0

# Every station scene shares this shell so the base class can own the title,
# the urgency bar and the locked board. Only `Body` differs per station.
@onready var background: NinePatchRect = $Background
@onready var layout: MarginContainer = $Layout
@onready var title_label: Label = $Layout/Stack/Title
@onready var body: Control = $Layout/Stack/Body
@onready var status_label: Label = $Layout/Stack/Status
@onready var bar: ProgressBar = $Layout/Stack/Bar
@onready var locked_overlay: Control = $LockedOverlay


func _ready() -> void:
	GameManager.register_station(self)
	GameManager.run_started.connect(reset_for_run)
	title_label.text = display_name.to_upper()
	# The urgency bar is the one visual that stays a themed control rather than
	# a swappable texture: it has to read identically on all four stations.
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = COLOR_OK
	_bar_fill.corner_radius_top_left = 3
	_bar_fill.corner_radius_top_right = 3
	_bar_fill.corner_radius_bottom_left = 3
	_bar_fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", _bar_fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.11, 0.14)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	reset_for_run()


func reset_for_run() -> void:
	is_unlocked = false
	is_locked_out = false
	is_timer_paused = false
	lockout_remaining = 0.0
	time_remaining = get_current_duration()
	_on_reset()
	_apply_unlock_visuals()


## Used by the debug "jump to phase" buttons: the station has to arrive at the
## new phase with a full countdown, not an expiring one.
func sync_to_progression() -> void:
	time_remaining = get_current_duration()
	is_locked_out = false
	lockout_remaining = 0.0
	is_timer_paused = false
	_on_reset()
	_update_unlock()


func _process(delta: float) -> void:
	var d := GameManager.scaled_delta(delta)
	_update_unlock()

	if is_locked_out:
		lockout_remaining -= d
		if lockout_remaining <= 0.0:
			is_locked_out = false
			lockout_remaining = 0.0
			_on_lockout_ended()

	var live := is_unlocked and GameManager.is_running and not is_locked_out \
		and not is_timer_paused

	if live and not GameManager.is_frozen():
		time_remaining -= d
		_on_drained(d)

	# Expiry is checked outside the freeze guard on purpose. A station already
	# sitting at zero when a freeze begins still has to fail -- otherwise two
	# same-frame expiries quietly collapse into one mistake.
	if live and time_remaining <= -grace_duration:
		_expire()

	if is_unlocked and GameManager.is_running and not is_locked_out:
		Sfx.set_urgency(station_id, get_urgency())
	else:
		Sfx.clear_urgency(station_id)

	_pulse_time += delta
	_update_visuals()


# --- progression -------------------------------------------------------------

func _update_unlock() -> void:
	var should := GameManager.should_be_unlocked(station_id, unlock_time)
	if should == is_unlocked:
		return
	is_unlocked = should
	if is_unlocked:
		time_remaining = get_current_duration()
		is_locked_out = false
		lockout_remaining = 0.0
		_on_reset()
		_on_unlocked()
		GameManager.notify_unlocked(station_id)
		Sfx.play("unlock")
		_slam_in()
	else:
		Sfx.clear_urgency(station_id)
	_apply_unlock_visuals()


func _apply_unlock_visuals() -> void:
	locked_overlay.visible = not is_unlocked
	layout.visible = is_unlocked


func _slam_in() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 1.6, 1.6), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.20)


# --- countdown ---------------------------------------------------------------

func get_current_duration() -> float:
	return lerpf(base_duration, floor_duration, GameManager.get_difficulty())


func get_remaining_fraction() -> float:
	var duration := get_current_duration()
	if duration <= 0.0:
		return 0.0
	return clampf(time_remaining / duration, 0.0, 1.0)


## 0 = comfortable, 1 = about to fail.
func get_urgency() -> float:
	return 1.0 - get_remaining_fraction()


func is_critical() -> bool:
	return get_remaining_fraction() <= CRITICAL_REMAINING


## The anti-spam rule exists to stop a one-click station being mashed for
## points. Stations whose service costs a long, ordered sequence of inputs
## cannot be farmed that way, and zeroing them for being *fast* punishes exactly
## the play the rule was written to encourage.
func is_anti_spam_exempt() -> bool:
	return false


## True when servicing this station *right now* would actually pay out. The
## anti-spam rule is otherwise invisible, and "I serviced it and got nothing"
## is the single most confusing thing about the scoring.
func is_scoring_possible() -> bool:
	if is_anti_spam_exempt():
		return true
	return get_remaining_fraction() <= GameManager.ANTI_SPAM_REMAINING + THRESHOLD_EPSILON


func can_interact() -> bool:
	return is_unlocked and GameManager.is_running and not is_locked_out \
		and not GameManager.modal_open and not GameManager.is_focus_paused()


# --- service / failure -------------------------------------------------------

## Credit one partial-progress input with time back on the clock, capped at a
## full countdown. Stations whose service is a long ordered sequence -- ten
## keypad digits, eleven typed words -- pay as you go rather than demanding the
## whole thing inside a single window. Shared so the two stay in step: tuning
## one of them without the other is almost never what you meant.
func grant_time_bonus() -> void:
	time_remaining = minf(time_remaining + PROGRESS_TIME_BONUS,
		get_current_duration())


## Award points for a successful service and file the progress point.
## Returns the points actually awarded, after anti-spam and the clutch bonus.
func service(points: int, reset: bool = true) -> int:
	var frac := get_remaining_fraction()
	# The epsilon matters: both thresholds are documented as "exactly at the
	# threshold still counts", and duration * 0.8 / duration lands a hair above
	# 0.8 in floating point often enough to make that a lie.
	var scored := is_anti_spam_exempt() \
		or frac <= GameManager.ANTI_SPAM_REMAINING + THRESHOLD_EPSILON
	var awarded := 0
	if scored:
		awarded = points
		if frac <= GameManager.CLUTCH_REMAINING + THRESHOLD_EPSILON:
			awarded *= GameManager.CLUTCH_MULTIPLIER
	if reset:
		time_remaining = get_current_duration()
	GameManager.register_service(station_id, awarded)
	serviced.emit(station_id, 1.0 - frac)
	note_progress(scored)
	_on_serviced(awarded, frac)
	return awarded


## A progress point that is not a full service -- a correct digit, an accepted
## word, a wind into the green.
func note_progress(scored: bool = true) -> void:
	GameManager.register_progress(station_id, scored)
	progress.emit(station_id, scored)


func fail(lockout_override: float = -1.0) -> void:
	if is_locked_out or not GameManager.is_running:
		return
	failed.emit(station_id)
	GameManager.register_mistake(station_id)
	begin_lockout(lockout_override if lockout_override >= 0.0 else lockout_duration)
	_on_failed()


func begin_lockout(duration: float) -> void:
	is_locked_out = true
	lockout_remaining = duration
	time_remaining = get_current_duration()
	_on_reset()


# --- visuals -----------------------------------------------------------------

func _update_visuals() -> void:
	if not is_unlocked:
		return
	var frac := get_remaining_fraction()
	bar.value = frac
	var color := COLOR_OK
	if is_locked_out:
		color = COLOR_LOCKOUT
	elif frac <= CRITICAL_REMAINING:
		color = COLOR_CRIT
	elif frac <= WARNING_REMAINING:
		color = COLOR_WARN
	elif not is_scoring_possible():
		color = COLOR_OK_DIM
	if not is_locked_out and frac <= FLASH_REMAINING:
		# Under 5% the bar flashes rather than just sitting red.
		var blink: float = 0.55 + 0.45 * sin(_pulse_time * 22.0)
		color = color.lerp(Color.WHITE, 1.0 - blink)
	_bar_fill.bg_color = color

	var tint := Color.WHITE
	if is_locked_out:
		tint = Color(0.55, 0.55, 0.60)
	elif frac <= CRITICAL_REMAINING:
		tint = Color.WHITE.lerp(COLOR_CRIT, 0.35 + 0.25 * sin(_pulse_time * 9.0))
	elif frac <= WARNING_REMAINING:
		tint = Color.WHITE.lerp(COLOR_WARN, 0.20 + 0.15 * sin(_pulse_time * 5.0))
	background.modulate = tint

	_update_status()


func _update_status() -> void:
	if is_locked_out:
		status_label.text = _lockout_text()
		status_label.modulate = COLOR_CRIT
	else:
		var hint := _scoring_hint()
		status_label.text = _status_text() + hint
		status_label.modulate = Color(0.48, 0.55, 0.50) if hint != "" \
			else Color(0.75, 0.78, 0.86)


func _lockout_text() -> String:
	return "REPAIRING  %.1fs" % maxf(lockout_remaining, 0.0)


## Suffix appended to the status line. Spelled out rather than left to the dim
## bar: the bar teaches the rule once you have noticed it, this is what makes
## you notice it.
func _scoring_hint() -> String:
	return "" if is_scoring_possible() else "   NO POINTS YET"


# --- subclass hooks ----------------------------------------------------------

func _status_text() -> String:
	return "%.1fs" % maxf(time_remaining, 0.0)

func _expire() -> void:
	fail()

func _on_drained(_delta: float) -> void:
	pass

func _on_unlocked() -> void:
	pass

func _on_serviced(_points: int, _remaining_fraction: float) -> void:
	pass

func _on_failed() -> void:
	pass

func _on_lockout_ended() -> void:
	pass

func _on_reset() -> void:
	pass
