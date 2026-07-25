extends PanelContainer
## Shift clock, hearts and score. Listens to GameManager; never drives it.

const HEART_FULL := preload("res://assets/placeholder/heart_full.png")
const HEART_EMPTY := preload("res://assets/placeholder/heart_empty.png")

var _hearts: Array[TextureRect] = []

@onready var shift_label: Label = $Bar/Shift
@onready var phase_label: Label = $Bar/Phase
@onready var score_label: Label = $Bar/Score
@onready var hearts_box: HBoxContainer = $Bar/Hearts
@onready var dividend_label: Label = $Bar/Dividend


func _ready() -> void:
	for i in GameManager.MAX_HEARTS:
		var heart := TextureRect.new()
		heart.texture = HEART_FULL
		heart.custom_minimum_size = Vector2(26, 26)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts_box.add_child(heart)
		_hearts.append(heart)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.mistake_made.connect(_on_mistake_made)
	GameManager.dividend_earned.connect(_on_dividend_earned)
	GameManager.run_started.connect(_on_run_started)
	dividend_label.modulate.a = 0.0
	_on_run_started()


func _process(_delta: float) -> void:
	shift_label.text = "SHIFT  " + GameManager.format_clock(GameManager.elapsed_time)
	phase_label.text = GameManager.get_phase_name()


func _on_run_started() -> void:
	_on_score_changed(GameManager.score)
	_refresh_hearts(GameManager.hearts)


func _on_score_changed(new_score: int) -> void:
	score_label.text = "%s" % _commas(new_score)


func _on_mistake_made(remaining_hearts: int) -> void:
	_refresh_hearts(remaining_hearts)
	if remaining_hearts < _hearts.size():
		var lost := _hearts[remaining_hearts]
		var tween := create_tween()
		tween.tween_property(lost, "scale", Vector2(1.6, 1.6), 0.08)
		tween.tween_property(lost, "scale", Vector2.ONE, 0.22)


func _refresh_hearts(remaining: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = HEART_FULL if i < remaining else HEART_EMPTY
		_hearts[i].pivot_offset = _hearts[i].size * 0.5


func _on_dividend_earned(from_station: String) -> void:
	# An invisible reward teaches nothing, so the switch is named on screen.
	dividend_label.text = "SWITCHED!  +TIME  (%s)" % from_station.to_upper()
	dividend_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_property(dividend_label, "modulate:a", 0.0, 0.35)


static func _commas(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out
