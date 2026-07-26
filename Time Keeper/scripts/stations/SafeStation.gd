extends Station
## Mouse-only. Press 9, 8, 7 ... 1, 0 in order before the vault re-locks.
##
## The code is never arbitrary -- it is always the descending count, which ties
## the station to the theme and lets all the difficulty live in *where* the
## digits are rather than in what they are.

const POINTS := 40
const CODE := ["9", "8", "7", "6", "5", "4", "3", "2", "1", "0"]
## 12 cells, 10 digits, 2 dead keys. The dead keys exist to fill the grid and,
## once the pad shuffles, to sit where you expected a digit.
## Plain ASCII on purpose: the default font has no U+2731, and a dead key that
## renders as a tofu box is a different puzzle than the one intended.
const DEFAULT_CELLS := ["1", "2", "3", "4", "5", "6", "7", "8", "9",
	"*", "0", "#"]
const DEAD_KEYS := ["*", "#"]

const TIER_SHUFFLE_AT := 0.33
const TIER_ARCANE_AT := 0.66

const OPEN_HOLD := 1.1
const SHUFFLE_DURATION := 1.0

## A miskey no longer wipes the entry. Instead the pad goes dead for a second,
## which costs strictly more than reading the keys does -- guessing stays bad
## without a single slip throwing away nine correct presses.
const MISKEY_FREEZE := 1.0

const KEY_SCENE := preload("res://scenes/stations/KeypadKey.tscn")
const SYMBOL_PATH := "res://assets/placeholder/safe_symbol_%s.png"

enum State { ARMED, OPEN, SHUFFLING }

var _state: int = State.ARMED
var _entry_index: int = 0
var _cells: Array = DEFAULT_CELLS.duplicate()
## Applied only at the re-lock transition, never mid-entry.
var _active_tier: int = 0
var _pending_tier: int = 0
var _debug_tier_override: int = -1
var _symbols: Dictionary = {}
var _keys: Array[TextureButton] = []
## Seconds left on the post-miskey pad lockout. The re-lock countdown keeps
## draining through it -- freezing that would make guessing a way to buy time.
var _miskey_freeze: float = 0.0
var _flash_tween: Tween

@onready var lcd_label: Label = $Layout/Stack/Body/Console/Lcd/Value
@onready var keypad: GridContainer = $Layout/Stack/Body/Console/Keypad
@onready var door: TextureRect = $Layout/Stack/Body/Door
@onready var codex: PanelContainer = $Layout/Stack/Body/Codex
@onready var codex_rows: GridContainer = $Layout/Stack/Body/Codex/Margin/Rows


func _ready() -> void:
	super._ready()
	for digit in CODE:
		var path := SYMBOL_PATH % digit
		if ResourceLoader.exists(path):
			_symbols[digit] = load(path)
	_build_keypad()
	_build_codex()
	door.visible = false
	_refresh_keys()
	_refresh_lcd()


func _build_keypad() -> void:
	keypad.columns = 3
	for i in DEFAULT_CELLS.size():
		var key: TextureButton = KEY_SCENE.instantiate()
		keypad.add_child(key)
		key.pressed.connect(_on_key_pressed.bind(i))
		_keys.append(key)


func _build_codex() -> void:
	codex_rows.columns = 2
	for digit in CODE:
		var symbol := TextureRect.new()
		symbol.custom_minimum_size = Vector2(22, 22)
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.texture = _symbols.get(digit)
		codex_rows.add_child(symbol)
		var label := Label.new()
		label.text = "= " + digit
		label.add_theme_font_size_override("font_size", 14)
		codex_rows.add_child(label)
	codex.visible = false


# --- tiers -------------------------------------------------------------------

func get_tier() -> int:
	if _debug_tier_override >= 0:
		return _debug_tier_override
	var difficulty := GameManager.get_difficulty()
	if difficulty >= TIER_ARCANE_AT:
		return 2
	if difficulty >= TIER_SHUFFLE_AT:
		return 1
	return 0


func set_debug_tier(tier: int) -> void:
	_debug_tier_override = tier
	_pending_tier = get_tier()


func _process(delta: float) -> void:
	super._process(delta)
	if not is_unlocked:
		return
	# Crossing a tier threshold mid-entry must not disturb the attempt in
	# progress; the new tier is picked up at the next re-lock.
	_pending_tier = get_tier()
	if _miskey_freeze > 0.0:
		_miskey_freeze = maxf(_miskey_freeze - GameManager.scaled_delta(delta), 0.0)
		if _miskey_freeze <= 0.0:
			_end_miskey_freeze()


# --- entry -------------------------------------------------------------------

func _on_key_pressed(cell: int) -> void:
	if not can_interact():
		return
	# During the shuffle -- and during the miskey freeze -- the pad is
	# input-locked: clicks register as nothing at all, not as wrong presses.
	if _state != State.ARMED or _miskey_freeze > 0.0:
		return
	var value: String = _cells[cell]
	if value == CODE[_entry_index]:
		_entry_index += 1
		Sfx.play("keypad_beep", 1.0 + 0.05 * _entry_index)
		_flash(_keys[cell], COLOR_OK)
		# Every correct digit is a progress point, which makes the safe the
		# cheapest place to earn a Time Dividend. Watched, per plan 13.7.
		note_progress(true)
		_refresh_lcd()
		if _entry_index >= CODE.size():
			# Not on the digit that opens the vault: service() grades the clutch
			# bonus on the timer as it stood, and a refill an instant before
			# scoring would erase a genuine save.
			_open()
		else:
			grant_time_bonus()
	else:
		_wrong(cell)


func _wrong(cell: int) -> void:
	# A wrong key -- digit or dead key -- costs a dead second, never a heart and
	# no longer the entry so far.
	_miskey_freeze = MISKEY_FREEZE
	Sfx.play("keypad_beep", 0.5, -2.0)
	# A green flash from the previous digit is still fading; left alive it would
	# hand one key back its white halfway through a dead pad.
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	# No tween back to white: the whole pad has to stay visibly dead for the
	# full second, with the offending key called out in red.
	for i in _keys.size():
		_keys[i].modulate = COLOR_CRIT if i == cell else COLOR_LOCKOUT
	lcd_label.modulate = COLOR_CRIT
	_refresh_lcd()


func _end_miskey_freeze() -> void:
	_miskey_freeze = 0.0
	lcd_label.modulate = Color.WHITE
	if _state == State.ARMED:
		_refresh_keys()


func _flash(key: TextureButton, color: Color) -> void:
	key.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(key, "modulate", Color.WHITE, 0.25)


func _open() -> void:
	_state = State.OPEN
	is_timer_paused = true
	Sfx.play("safe_open")
	service(POINTS)
	door.visible = true
	door.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(door, "modulate:a", 1.0, 0.2)
	tween.tween_interval(OPEN_HOLD)
	tween.tween_property(door, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_begin_relock)


func _begin_relock() -> void:
	door.visible = false
	_entry_index = 0
	_refresh_lcd()
	if _pending_tier >= 1:
		_shuffle()
	else:
		_rearm()


# --- shuffle -----------------------------------------------------------------

func _shuffle() -> void:
	_state = State.SHUFFLING
	# The re-lock timer stays paused for the whole animation. You never lose
	# time to a shuffle.
	is_timer_paused = true
	_cells = _rolled_layout()
	Sfx.play("keypad_shuffle")
	for i in _keys.size():
		var key: TextureButton = _keys[i]
		key.pivot_offset = key.size * 0.5
		# Greyed out for the duration, so "input-locked" is visible and not
		# just a rule you learn by having a click swallowed.
		key.modulate = Color(0.45, 0.45, 0.5)
		# Keys tumble into their new faces so the movement is legible rather
		# than an instant swap.
		var sub := create_tween()
		sub.tween_interval(SHUFFLE_DURATION * 0.3 * (float(i) / _keys.size()))
		sub.tween_property(key, "scale", Vector2(0.05, 1.0), 0.22)
		sub.tween_callback(_apply_key_face.bind(i))
		sub.tween_property(key, "scale", Vector2.ONE, 0.22)
	var master := create_tween()
	master.tween_interval(SHUFFLE_DURATION)
	master.tween_callback(_finish_shuffle)


func _rolled_layout() -> Array:
	var previous: Array = _cells.duplicate()
	var next: Array = DEFAULT_CELLS.duplicate()
	# A shuffle that visibly does nothing reads as a bug. There are 12! layouts
	# and one of them is excluded, so this terminates immediately in practice.
	for _attempt in 16:
		next.shuffle()
		if next != previous:
			return next
	return next


func _apply_key_face(index: int) -> void:
	_set_key_face(_keys[index], _cells[index], _pending_tier)


func _finish_shuffle() -> void:
	for key in _keys:
		key.scale = Vector2.ONE
		key.modulate = Color.WHITE
	_rearm()


func _rearm() -> void:
	_active_tier = _pending_tier
	if _active_tier == 0:
		# Dropping back to tier 0 (usually the debug panel) restores the phone
		# layout rather than leaving a shuffled pad with no shuffles coming.
		_cells = DEFAULT_CELLS.duplicate()
	_state = State.ARMED
	is_timer_paused = false
	time_remaining = get_current_duration()
	_entry_index = 0
	_end_miskey_freeze()
	_refresh_keys()
	_refresh_lcd()


# --- key faces ---------------------------------------------------------------

func _refresh_keys() -> void:
	for i in _keys.size():
		_set_key_face(_keys[i], _cells[i], _active_tier)
	codex.visible = _active_tier >= 2


func _set_key_face(key: TextureButton, value: String, tier: int) -> void:
	var label: Label = key.get_node("Label")
	var symbol: TextureRect = key.get_node("Symbol")
	var arcane: bool = tier >= 2 and _symbols.has(value)
	symbol.visible = arcane
	label.visible = not arcane
	if arcane:
		symbol.texture = _symbols[value]
	else:
		label.text = value
	# Dead keys look exactly like live ones. That is the point of them.
	key.modulate = Color.WHITE


func _refresh_lcd() -> void:
	var parts := PackedStringArray()
	for i in CODE.size():
		parts.append(CODE[i] if i < _entry_index else "_")
	lcd_label.text = " ".join(parts)


## Ten ordered presses per open, and each one refills the countdown -- so a
## clean fast entry lands with the bar near full. Under the anti-spam rule that
## would score nothing, which is backwards.
func is_anti_spam_exempt() -> bool:
	return true


func _status_text() -> String:
	match _state:
		State.OPEN:
			return "OPEN"
		State.SHUFFLING:
			return "RE-KEYING..."
		_:
			if _miskey_freeze > 0.0:
				return "MISKEY -- PAD DEAD  %.1fs" % _miskey_freeze
			return "RE-LOCK  %.1fs   TIER %d" % [maxf(time_remaining, 0.0), _active_tier]


func _on_reset() -> void:
	_entry_index = 0
	_state = State.ARMED
	is_timer_paused = false
	door.visible = false
	_end_miskey_freeze()
	for key in _keys:
		key.scale = Vector2.ONE
		key.modulate = Color.WHITE
	_refresh_lcd()


func _on_unlocked() -> void:
	_cells = DEFAULT_CELLS.duplicate()
	_active_tier = get_tier()
	_pending_tier = _active_tier
	_refresh_keys()


## Debug panel hook.
func force_shuffle() -> void:
	if _state == State.ARMED:
		_shuffle()
