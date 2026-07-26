extends Station
## Click and hold the winding key to refill mainspring tension.
##
## The first station that punishes inattention *while* interacting: the
## overwind band means you can't hold the key and stare at something else.

const POINTS := 15
## Tension per second while held. Tension is just the countdown expressed 0-100.
const WIND_RATE := 45.0
## Red band. Holding inside it for SNAP_TIME seconds snaps the spring.
const OVERWIND_MIN := 90.0
const SNAP_TIME := 0.6
const SNAP_LOCKOUT := 3.0
## Crossing up through this is "wound into the green" -- the scoring event.
## Matches the amber warning threshold so the gauge and the bar agree.
const GREEN_TENSION := Station.WARNING_REMAINING * 100.0

var _winding: bool = false
var _overwind_time: float = 0.0
var _in_green: bool = true
## Lowest tension since the last green crossing, so the clutch bonus can pay
## out for a genuine save rather than for the moment you cross 25.
var _lowest_tension: float = 100.0
var _wind_sound_timer: float = 0.0

@onready var key: TextureRect = $Layout/Stack/Body/Gauge/Key
@onready var tension_bar: ProgressBar = $Layout/Stack/Body/Gauge/GaugeFrame/Inner/Tension
@onready var red_band: ColorRect = $Layout/Stack/Body/Gauge/GaugeFrame/Inner/RedBand
@onready var face: TextureRect = $Layout/Stack/Body/Gauge/Face


func _ready() -> void:
	super._ready()
	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR_OK
	tension_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.11)
	tension_bar.add_theme_stylebox_override("background", bg)
	tension_bar.min_value = 0.0
	tension_bar.max_value = 100.0
	tension_bar.show_percentage = false
	key.gui_input.connect(_on_key_gui_input)
	key.mouse_exited.connect(_stop_winding)
	key.pivot_offset = key.size * 0.5
	key.resized.connect(func() -> void: key.pivot_offset = key.size * 0.5)
	face.pivot_offset = face.size * 0.5
	face.resized.connect(func() -> void: face.pivot_offset = face.size * 0.5)
	# The red band is chrome on a themed gauge, not illustration -- it has to
	# line up with OVERWIND_MIN exactly, which a texture can't promise. The
	# translucent band muddies against a green fill, so a hard edge line marks
	# the threshold itself.
	var band_start := OVERWIND_MIN / 100.0
	red_band.anchor_left = band_start
	red_band.color = Color(0.85, 0.24, 0.22, 0.55)
	var band_edge: ColorRect = red_band.get_parent().get_node("BandEdge")
	band_edge.anchor_left = band_start
	band_edge.anchor_right = band_start


func _input(event: InputEvent) -> void:
	# Catches the release when the pointer has already left the key, which is
	# the normal way people let go under pressure.
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_stop_winding()


func _on_key_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and can_interact():
			_winding = true
		else:
			_stop_winding()


func _stop_winding() -> void:
	_winding = false


func _process(delta: float) -> void:
	super._process(delta)
	if not can_interact():
		_winding = false
	if not is_unlocked:
		return

	var d := GameManager.scaled_delta(delta)
	# Winding still works during a Time Dividend freeze: the freeze stops
	# countdowns, not hands.
	if _winding:
		var duration := get_current_duration()
		time_remaining = minf(time_remaining + WIND_RATE / 100.0 * duration * d,
			duration)
		key.rotation += d * 9.0
		_wind_sound_timer -= delta
		if _wind_sound_timer <= 0.0:
			_wind_sound_timer = 0.18
			Sfx.play("wind", randf_range(0.95, 1.15), -6.0)

	_track_tension(d)
	_update_gauge()


func _track_tension(d: float) -> void:
	var tension := get_remaining_fraction() * 100.0
	_lowest_tension = minf(_lowest_tension, tension)

	# Only accumulates while actually holding the key -- drifting into the band
	# from a wind and then letting go is not a snap.
	if _winding and tension >= OVERWIND_MIN:
		_overwind_time += d
		if _overwind_time >= SNAP_TIME:
			_snap()
			return
	else:
		_overwind_time = 0.0

	var green := tension >= GREEN_TENSION
	if green and not _in_green:
		_wound_into_green()
	_in_green = green


func _wound_into_green() -> void:
	var points := POINTS
	if _lowest_tension <= GameManager.CLUTCH_REMAINING * 100.0:
		points *= GameManager.CLUTCH_MULTIPLIER
	# Not routed through service(): winding is a continuous refill, so there is
	# no reset, and the clutch is judged on how low it got rather than on the
	# tension at the instant of crossing.
	GameManager.register_service(station_id, points)
	serviced.emit(station_id, 1.0 - _lowest_tension / 100.0)
	note_progress(true)
	_lowest_tension = 100.0


func _snap() -> void:
	_winding = false
	_overwind_time = 0.0
	Sfx.play("snap")
	# Q4: overwind ships as a full mistake. If playtesters find it cheap, drop
	# the fail() below and keep only begin_lockout(SNAP_LOCKOUT).
	fail(SNAP_LOCKOUT)


func _update_gauge() -> void:
	var tension := get_remaining_fraction() * 100.0
	tension_bar.value = tension
	var fill: StyleBoxFlat = tension_bar.get_theme_stylebox("fill")
	if _winding and tension >= OVERWIND_MIN:
		# Accelerating warning as the snap timer fills. Only while actually
		# holding -- sitting at 95 tension is where a well-wound clock lives,
		# and it must not look like an emergency.
		var t := clampf(_overwind_time / SNAP_TIME, 0.0, 1.0)
		var blink: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001
			* lerpf(12.0, 40.0, t))
		fill.bg_color = COLOR_CRIT.lerp(Color.WHITE, blink * 0.6)
	elif tension <= CRITICAL_REMAINING * 100.0:
		fill.bg_color = COLOR_CRIT
	elif tension <= GREEN_TENSION:
		fill.bg_color = COLOR_WARN
	else:
		fill.bg_color = COLOR_OK
	face.rotation = -get_remaining_fraction() * TAU


## The clock pays on the *crossing* into green, so points only exist while the
## spring is slack. Sitting at 90 tension is safe and worth nothing -- which is
## the whole reason hovering at the amber edge is the high-roller play.
func is_scoring_possible() -> bool:
	return get_remaining_fraction() * 100.0 < GREEN_TENSION


func _status_text() -> String:
	if _winding and get_remaining_fraction() * 100.0 >= OVERWIND_MIN:
		return "OVERWIND!  %.1fs" % maxf(SNAP_TIME - _overwind_time, 0.0)
	return "TENSION  %d" % int(get_remaining_fraction() * 100.0)


func _scoring_hint() -> String:
	# Not while the spring is about to snap. "No points yet" is the wrong thing
	# to be reading in the half second before you lose a heart.
	if _winding and get_remaining_fraction() * 100.0 >= OVERWIND_MIN:
		return ""
	return super._scoring_hint()


func _lockout_text() -> String:
	return "SPRING SNAPPED -- REPAIRING  %.1fs" % maxf(lockout_remaining, 0.0)


func _on_reset() -> void:
	_winding = false
	_overwind_time = 0.0
	_in_green = true
	_lowest_tension = 100.0
