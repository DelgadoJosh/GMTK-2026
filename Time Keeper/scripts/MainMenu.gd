extends Control
## Title card. The acronym gag spells both expansions out letter by letter --
## the joke does double duty, since the theme is countdown and every failure
## state is a countdown hitting zero.
##
## The Play button also doubles as the first user gesture, which is what
## unblocks audio in a browser.

const GAG := [
	{"acronym": "G M T K", "expansion": "Grand Maestro of Time Keeping"},
	{"acronym": "G A M E   J A M",
		"expansion": "Grandiose Awesome Magnificent/Maintenance Engineer\n"
			+ "who's a Joyfully Amazing Maintainer"},
]

const LETTER_DELAY := 0.09
const HOLD := 1.1

var _gag_index: int = 0

@onready var acronym_label: Label = $Center/Stack/Acronym
@onready var expansion_label: Label = $Center/Stack/Expansion
@onready var play_button: Button = $Center/Stack/Buttons/Play
@onready var quit_button: Button = $Center/Stack/Buttons/Quit
@onready var veteran_check: CheckButton = $Center/Stack/Veteran
@onready var howto_button: Button = $Center/Stack/Buttons/HowTo
@onready var howto_panel: Control = $HowToPlay


func _ready() -> void:
	howto_button.pressed.connect(func() -> void:
		Sfx.play("click")
		howto_panel.open())
	# The autoload outlives this scene, so the box remembers the last choice
	# when you come back to the title after being fired.
	veteran_check.button_pressed = \
		GameManager.difficulty_mode == GameManager.Difficulty.VETERAN
	play_button.pressed.connect(_on_play)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	# Browser builds have no meaningful quit.
	quit_button.visible = OS.get_name() != "Web"
	play_button.grab_focus()
	_run_gag()


func _run_gag() -> void:
	while is_inside_tree():
		var entry: Dictionary = GAG[_gag_index]
		var acronym: String = entry["acronym"]
		acronym_label.text = ""
		expansion_label.text = ""
		for i in acronym.length():
			acronym_label.text += acronym[i]
			if acronym[i] != " ":
				Sfx.play("keypad_beep", 1.4, -18.0)
			await get_tree().create_timer(LETTER_DELAY).timeout
			if not is_inside_tree():
				return
		expansion_label.text = str(entry["expansion"])
		await get_tree().create_timer(HOLD).timeout
		if not is_inside_tree():
			return
		_gag_index = (_gag_index + 1) % GAG.size()


func _on_play() -> void:
	Sfx.play("click")
	GameManager.difficulty_mode = GameManager.Difficulty.VETERAN \
		if veteran_check.button_pressed else GameManager.Difficulty.STANDARD
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
