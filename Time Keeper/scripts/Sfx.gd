extends Node
## Autoload. One-shot sound pool plus the urgency tick ladder.
##
## Every station gets its own tick voice at a distinct pitch, and the tick rate
## accelerates as that station approaches failure. Four overlapping ticks is
## the board state told to you without looking -- which is the whole point of
## the ladder, so the pitches are spread far enough apart to be countable.

const AUDIO_DIR := "res://assets/audio/"

## Swap-by-filename, same rule as the art.
const SOUNDS := [
	"tick", "flip", "wind", "snap", "keypad_beep", "keypad_shuffle",
	"safe_open", "launch", "klaxon", "dividend", "mistake", "fired", "unlock",
	"click",
]

## Per-sound trim, applied on top of whatever the caller asks for. Mixing lives
## here rather than at the call sites: how loud a sound sits against the rest is
## a property of the file, so a swapped-in replacement gets rebalanced in one
## place instead of everywhere it is played.
const MIX_DB := {
	# A klaxon that makes you flinch stops being information and starts being a
	# reason to mute the tab.
	"klaxon": -12.0,
}

## Tick pitch per station, low to high in unlock order.
const TICK_PITCH := {
	"hourglass": 0.75,
	"clock": 1.0,
	"safe": 1.35,
	"rocket": 1.8,
}

const TICK_START_URGENCY := 0.75   ## matches the amber warning at 25% remaining
const TICK_SLOW_INTERVAL := 0.5
const TICK_FAST_INTERVAL := 0.11

const POOL_SIZE := 12

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

var _tick_players: Dictionary = {}   ## station_id -> AudioStreamPlayer
var _tick_urgency: Dictionary = {}   ## station_id -> float
var _tick_timers: Dictionary = {}    ## station_id -> float


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name in SOUNDS:
		var path: String = AUDIO_DIR + str(sound_name) + ".wav"
		if ResourceLoader.exists(path):
			_streams[sound_name] = load(path)
		else:
			push_warning("Sfx: missing placeholder audio '%s'" % path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _pool[_next_voice]
	_next_voice = (_next_voice + 1) % POOL_SIZE
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db + float(MIX_DB.get(sound, 0.0))
	p.play()


## Reported every frame by each unlocked station. 0 = fine, 1 = about to fail.
func set_urgency(station_id: String, urgency: float) -> void:
	_tick_urgency[station_id] = urgency


func clear_urgency(station_id: String) -> void:
	_tick_urgency[station_id] = 0.0


func clear_all_urgency() -> void:
	for key in _tick_urgency.keys():
		_tick_urgency[key] = 0.0


func _process(delta: float) -> void:
	for station_id in _tick_urgency.keys():
		var urgency: float = _tick_urgency[station_id]
		if urgency < TICK_START_URGENCY or not GameManager.is_running:
			_tick_timers[station_id] = 0.0
			continue
		var t := inverse_lerp(TICK_START_URGENCY, 1.0, minf(urgency, 1.0))
		var interval: float = lerpf(TICK_SLOW_INTERVAL, TICK_FAST_INTERVAL, t)
		var elapsed: float = float(_tick_timers.get(station_id, interval)) + delta
		if elapsed >= interval:
			elapsed = 0.0
			var pitch: float = float(TICK_PITCH.get(station_id, 1.0))
			# Quiet when merely warning, insistent when critical.
			play("tick", pitch, lerpf(-14.0, -3.0, t))
		_tick_timers[station_id] = elapsed
