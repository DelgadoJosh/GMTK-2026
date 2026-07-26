extends Control
## Score screen. The shareable line is which station fired you.

signal retry_pressed

const STATION_NAMES := {
	"hourglass": "Hourglass",
	"clock": "Wind-up clock",
	"safe": "Safe keypad",
	"rocket": "Rocket launch",
	"debug": "the debug panel",
}

@onready var shift_label: Label = $Center/Panel/Margin/Stack/Shift
@onready var score_label: Label = $Center/Panel/Margin/Stack/Score
@onready var fired_label: Label = $Center/Panel/Margin/Stack/FiredBy
@onready var breakdown_label: Label = $Center/Panel/Margin/Stack/Breakdown
@onready var cheated_label: Label = $Center/Panel/Margin/Stack/Cheated
@onready var retry_button: Button = $Center/Panel/Margin/Stack/Buttons/Retry
@onready var menu_button: Button = $Center/Panel/Margin/Stack/Buttons/Menu


func _ready() -> void:
	retry_button.pressed.connect(func() -> void:
		Sfx.play("click")
		retry_pressed.emit())
	menu_button.pressed.connect(func() -> void:
		Sfx.play("click")
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))


func show_results(final_time: float, final_score: int, cheated: bool) -> void:
	visible = true
	shift_label.text = "SHIFT SURVIVED   " + GameManager.format_clock(final_time)
	if GameManager.difficulty_mode == GameManager.Difficulty.VETERAN:
		# Two runs of the same length are not the same run. Say which this was.
		shift_label.text += "   [VETERAN]"
	score_label.text = "SERVICE POINTS   %d" % final_score
	fired_label.text = "You were fired by: %s" % _station_name(GameManager.fired_by)

	var lines := PackedStringArray()
	for id in ["hourglass", "clock", "safe", "rocket"]:
		var serviced: int = int(GameManager.service_counts.get(id, 0))
		var missed: int = int(GameManager.mistake_counts.get(id, 0))
		lines.append("%-14s serviced %3d   dropped %d" % [
			_station_name(id), serviced, missed])
	lines.append("")
	lines.append("Time Dividends earned: %d" % GameManager.dividend_count)
	breakdown_label.text = "\n".join(lines)

	cheated_label.visible = cheated
	if cheated:
		# The flag never clears. No toggling cheats off to launder a run.
		cheated_label.text = "CHEATED -- not eligible for the high score"
	retry_button.grab_focus()


func _station_name(id: String) -> String:
	return str(STATION_NAMES.get(id, id if id != "" else "nobody, somehow"))
