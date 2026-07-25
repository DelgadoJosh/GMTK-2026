extends Node
## Autoload. Owns the shift clock, the difficulty ramp, hearts, score and the
## Time Dividend bookkeeping.
##
## Signals up, calls down: stations emit, this listens. Stations never talk to
## each other. The three pause concepts are kept deliberately separate --
## freeze (global, dividend/mistake), pause (per-station, e.g. shuffle) and
## lockout (per-station, post-failure grace).

signal mistake_made(remaining_hearts: int)
signal station_unlocked(station_id: String)
signal score_changed(new_score: int)
signal dividend_earned(from_station: String)
signal game_over(final_time: float, final_score: int, cheated: bool)
signal run_started()
signal cheats_enabled_changed(enabled: bool)
signal focus_pause_changed(paused: bool)

const RAMP_SECONDS := 240.0

const DIVIDEND_FREEZE := 0.4
const DIVIDEND_COOLDOWN := 0.75
const MISTAKE_FREEZE := 0.4

## Servicing with more than this fraction of the countdown left is worth no
## points and no dividend. Exactly at the threshold still scores -- the test
## list asks for a side to be picked, and generosity on the boundary is the
## kinder read.
const ANTI_SPAM_REMAINING := 0.80
## At or below this fraction remaining the station is critical, and a service
## lands the clutch bonus.
const CLUTCH_REMAINING := 0.10
const CLUTCH_MULTIPLIER := 2

const STARTING_HEARTS := 3
const MAX_HEARTS := 3

## Phase boundaries, used by the HUD label and the debug jump buttons.
const PHASES := [
	{"name": "ORIENTATION", "time": 0.0},
	{"name": "TWO HANDS", "time": 25.0},
	{"name": "THREE-BODY", "time": 60.0},
	{"name": "FULL SHIFT", "time": 100.0},
	{"name": "OVERTIME", "time": 240.0},
]

var hearts: int = STARTING_HEARTS
var score: int = 0
var elapsed_time: float = 0.0
var is_running: bool = false

# Time Dividend
var last_progress_station: String = ""
var dividend_cooldown: float = 0.0
var dividend_count: int = 0
var freeze_remaining: float = 0.0        ## dividend freeze; stations skip draining
var mistake_freeze_remaining: float = 0.0

# Run stats, for the score screen.
var service_counts: Dictionary = {}
var mistake_counts: Dictionary = {}
var fired_by: String = ""

# Debug / cheat
var cheats_enabled: bool = false
var run_was_cheated: bool = false        ## sticky for the run, kills the high score
var debug_invincible: bool = false
var debug_difficulty_override: float = -1.0
var debug_time_scale: float = 1.0
var debug_freeze_timers: bool = false
var debug_unlock_overrides: Dictionary = {}   ## station_id -> bool, absent = auto

## True while a modal (the easter-egg dialog) is up. Everything holds still --
## rewarding curiosity with a lost heart is a worse joke than it sounds.
var modal_open: bool = false

var _stations: Dictionary = {}           ## station_id -> Station
var _focus_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# Browsers keep running the canvas in a background tab; without this the
	# whole facility drains while the player is reading their email.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_focus_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_focus_paused(false)


func _set_focus_paused(paused: bool) -> void:
	if _focus_paused == paused:
		return
	_focus_paused = paused
	focus_pause_changed.emit(paused)


func _process(delta: float) -> void:
	if not is_running or _focus_paused or modal_open:
		return
	var d := scaled_delta(delta)
	elapsed_time += d
	dividend_cooldown = maxf(dividend_cooldown - d, 0.0)
	freeze_remaining = maxf(freeze_remaining - d, 0.0)
	mistake_freeze_remaining = maxf(mistake_freeze_remaining - d, 0.0)


## Every timed thing in the game runs through here so the debug time scale
## applies uniformly.
func scaled_delta(delta: float) -> float:
	return delta * debug_time_scale


func is_focus_paused() -> bool:
	return _focus_paused


# --- run lifecycle -----------------------------------------------------------

func start_run() -> void:
	hearts = STARTING_HEARTS
	score = 0
	elapsed_time = 0.0
	last_progress_station = ""
	dividend_cooldown = 0.0
	dividend_count = 0
	freeze_remaining = 0.0
	mistake_freeze_remaining = 0.0
	service_counts = {}
	mistake_counts = {}
	fired_by = ""
	run_was_cheated = false
	cheats_enabled = false
	debug_invincible = false
	debug_difficulty_override = -1.0
	debug_time_scale = 1.0
	debug_freeze_timers = false
	debug_unlock_overrides = {}
	modal_open = false
	is_running = true
	run_started.emit()
	score_changed.emit(score)
	cheats_enabled_changed.emit(cheats_enabled)


func _end_run(source_station: String) -> void:
	if not is_running:
		return
	is_running = false
	fired_by = source_station
	Sfx.clear_all_urgency()
	game_over.emit(elapsed_time, score, run_was_cheated)


# --- difficulty --------------------------------------------------------------

func get_difficulty() -> float:
	if debug_difficulty_override >= 0.0:
		return clampf(debug_difficulty_override, 0.0, 1.0)
	return clampf(elapsed_time / RAMP_SECONDS, 0.0, 1.0)


func get_phase_index() -> int:
	var idx := 0
	for i in PHASES.size():
		if elapsed_time >= float(PHASES[i]["time"]):
			idx = i
	return idx


func get_phase_name() -> String:
	return str(PHASES[get_phase_index()]["name"])


func jump_to_phase(index: int) -> void:
	index = clampi(index, 0, PHASES.size() - 1)
	elapsed_time = float(PHASES[index]["time"])
	# Unlocks are driven off elapsed_time, so the stations catch up on their
	# own -- but they must arrive with full countdowns, not expiring ones.
	for station in _stations.values():
		station.sync_to_progression()


# --- stations ----------------------------------------------------------------

func register_station(station: Node) -> void:
	_stations[station.station_id] = station


func get_station(station_id: String) -> Node:
	return _stations.get(station_id)


func get_stations() -> Array:
	return _stations.values()


func should_be_unlocked(station_id: String, unlock_time: float) -> bool:
	if debug_unlock_overrides.has(station_id):
		return bool(debug_unlock_overrides[station_id])
	return elapsed_time >= unlock_time


func notify_unlocked(station_id: String) -> void:
	station_unlocked.emit(station_id)


# --- freeze ------------------------------------------------------------------

## True while station countdowns should hold still, for any global reason.
func is_frozen() -> bool:
	return debug_freeze_timers or _focus_paused or modal_open \
		or freeze_remaining > 0.0 or mistake_freeze_remaining > 0.0


func trigger_dividend(from_station: String) -> void:
	# maxf rather than += so overlapping dividends can never stack into a long
	# freeze.
	freeze_remaining = maxf(freeze_remaining, DIVIDEND_FREEZE)
	dividend_cooldown = DIVIDEND_COOLDOWN
	dividend_count += 1
	dividend_earned.emit(from_station)


# --- progress / scoring ------------------------------------------------------

## Called for every progress point: a flip, a wind into the green, a correct
## digit, an accepted word. `scored` is false for progress that was not worth
## points, which also makes it worth no dividend.
func register_progress(station_id: String, scored: bool) -> void:
	if not is_running:
		return
	if not scored:
		return
	var switched := station_id != last_progress_station
	last_progress_station = station_id
	if not switched:
		return
	if mistake_freeze_remaining > 0.0:
		return
	if dividend_cooldown > 0.0:
		return
	trigger_dividend(station_id)


func register_service(station_id: String, points: int) -> void:
	if not is_running:
		return
	service_counts[station_id] = int(service_counts.get(station_id, 0)) + 1
	if points > 0:
		add_score(points)


func add_score(points: int) -> void:
	if not is_running:
		return
	score += points
	score_changed.emit(score)


func register_mistake(source_station: String) -> void:
	if not is_running:
		return
	if debug_invincible:
		print("[debug] invincible: mistake from '%s' ignored" % source_station)
		return
	hearts = maxi(hearts - 1, 0)
	mistake_counts[source_station] = int(mistake_counts.get(source_station, 0)) + 1
	# A mistake freeze replaces any dividend freeze rather than extending it,
	# so the two can't be chained into a long safe window.
	freeze_remaining = 0.0
	mistake_freeze_remaining = MISTAKE_FREEZE
	mistake_made.emit(hearts)
	if hearts <= 0:
		_end_run(source_station)


# --- cheats ------------------------------------------------------------------

func enable_cheats() -> void:
	cheats_enabled = true
	# Sticky for the whole run. There is no laundering a cheated score by
	# switching the debug panel back off.
	run_was_cheated = true
	cheats_enabled_changed.emit(true)


# --- formatting --------------------------------------------------------------

static func format_clock(seconds: float) -> String:
	var total := int(floor(maxf(seconds, 0.0)))
	return "%02d:%02d" % [total / 60, total % 60]
