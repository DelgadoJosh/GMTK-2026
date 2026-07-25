extends Station
## The tutorial station. Click anywhere on the panel to flip it.
##
## Deliberately trivial -- it teaches "watch the bar, click the thing" before
## anything else exists. It is kept through the late game on the theory that a
## station this dumb still demanding attention at minute four is the joke.

const POINTS := 10
const FLIP_DURATION := 0.25

## Source-texture geometry of hourglass_frame.png. The frame is an opaque plate
## with the two bulbs punched out, so a plain stretched sand quad behind it is
## shaped by the holes. Keep these in sync with tools/gen_placeholders.py.
const FRAME_SIZE := Vector2(440.0, 520.0)
const TOP_BULB := Rect2(48.0, 44.0, 344.0, 216.0)
const BOTTOM_BULB := Rect2(48.0, 260.0, 344.0, 216.0)

var _flipping: bool = false

@onready var glass: Control = $Layout/Stack/Body/Glass
@onready var top_chamber: Control = $Layout/Stack/Body/Glass/TopChamber
@onready var top_sand: TextureRect = $Layout/Stack/Body/Glass/TopChamber/Sand
@onready var bottom_chamber: Control = $Layout/Stack/Body/Glass/BottomChamber
@onready var bottom_sand: TextureRect = $Layout/Stack/Body/Glass/BottomChamber/Sand


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_try_flip()
		accept_event()


func _try_flip() -> void:
	if not can_interact():
		return
	# Clicks during the tween are dropped rather than queued: stacked rotations
	# and double resets are the failure mode here.
	if _flipping:
		return
	_flipping = true
	# The countdown holds for the flip, so the sand can't run out inside the
	# animation and the service is scored at the fraction you clicked at.
	is_timer_paused = true
	Sfx.play("flip")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(glass, "rotation", PI, FLIP_DURATION)
	tween.tween_callback(_finish_flip)


func _finish_flip() -> void:
	# The plate is symmetric, so landing on PI and snapping back to 0 is
	# invisible -- and it keeps the sand maths the right way up.
	glass.rotation = 0.0
	_flipping = false
	is_timer_paused = false
	service(POINTS)


func _on_serviced(points: int, _remaining_fraction: float) -> void:
	if points > 0:
		_pop_label(points)


func _pop_label(points: int) -> void:
	var label := Label.new()
	label.text = "+%d" % points
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", COLOR_OK)
	label.position = body.size * Vector2(0.5, 0.4)
	body.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


func _on_reset() -> void:
	_flipping = false
	glass.rotation = 0.0


func _status_text() -> String:
	if time_remaining <= 0.0:
		return "DRAINED -- FLIP IT  %.1fs" % maxf(grace_duration + time_remaining, 0.0)
	return "SAND  %.1fs" % time_remaining


func _update_visuals() -> void:
	super._update_visuals()
	if not is_unlocked:
		return
	_layout_glass()


func _layout_glass() -> void:
	var avail := glass.size
	if avail.x <= 1.0 or avail.y <= 1.0:
		return
	glass.pivot_offset = avail * 0.5
	# Match the frame's KEEP_ASPECT_CENTERED stretch so the sand lands inside
	# the drawn bulbs at any panel size.
	var s: float = minf(avail.x / FRAME_SIZE.x, avail.y / FRAME_SIZE.y)
	var origin := (avail - FRAME_SIZE * s) * 0.5
	var frac := get_remaining_fraction()
	_place_sand(top_chamber, top_sand, TOP_BULB, origin, s, frac)
	_place_sand(bottom_chamber, bottom_sand, BOTTOM_BULB, origin, s, 1.0 - frac)


func _place_sand(chamber: Control, sand: TextureRect, bulb: Rect2,
		origin: Vector2, s: float, fill: float) -> void:
	chamber.position = origin + bulb.position * s
	chamber.size = bulb.size * s
	var h: float = chamber.size.y * clampf(fill, 0.0, 1.0)
	sand.position = Vector2(0.0, chamber.size.y - h)
	sand.size = Vector2(chamber.size.x, h)
