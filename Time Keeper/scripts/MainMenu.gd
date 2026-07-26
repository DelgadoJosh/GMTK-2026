extends Control
## Title card. The gag assembles each expansion a word at a time and then drops
## the acronym it spells -- the words are the setup, the acronym is the
## punchline, so it lands last.
##
## The Play button also doubles as the first user gesture, which is what
## unblocks audio in a browser.

const GAG := [
	{"acronym": "G M T K", "expansion": "Grand Maestro of Time Keeping"},
	{"acronym": "G A M E   J A M",
		"expansion": "Grandiose Awesome Magnificent/Maintenance Engineer\n"
			+ "who's a Joyfully Amazing Maintainer"},
]

const WORD_DELAY := 0.18
## A beat of silence between the last word and the acronym. Without it the
## payoff arrives on top of the setup and reads as one event.
const ACRONYM_DELAY := 0.45
const HOLD := 2.0

var _gag_index: int = 0

@onready var acronym_label: Label = $Center/Stack/Acronym
@onready var expansion_label: Label = $Center/Stack/Expansion
@onready var play_button: Button = $Center/Stack/Buttons/Play
@onready var quit_button: Button = $Center/Stack/Buttons/Quit
@onready var veteran_check: CheckButton = $Center/Stack/Veteran
@onready var howto_button: Button = $Center/Stack/Buttons/HowTo
@onready var howto_panel: InfoPanel = $HowToPlay
@onready var credits_button: Button = $Center/Stack/Buttons/CreditsButton
@onready var credits_panel: InfoPanel = $Credits


func _ready() -> void:
	_wire_panel(howto_button, howto_panel)
	_wire_panel(credits_button, credits_panel)
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


## Both reading panels behave identically: open on click, and hand focus back to
## the button that opened them on close, so the keyboard never ends up nowhere.
func _wire_panel(button: Button, panel: InfoPanel) -> void:
	button.pressed.connect(func() -> void:
		Sfx.play("click")
		panel.open())


func _run_gag() -> void:
	while is_inside_tree():
		var entry: Dictionary = GAG[_gag_index]
		acronym_label.text = ""
		expansion_label.text = ""
		for prefix in word_prefixes(str(entry["expansion"])):
			expansion_label.text = prefix
			Sfx.play("keypad_beep", 1.4, -18.0)
			await get_tree().create_timer(WORD_DELAY).timeout
			if not is_inside_tree():
				return
		await get_tree().create_timer(ACRONYM_DELAY).timeout
		if not is_inside_tree():
			return
		acronym_label.text = str(entry["acronym"])
		Sfx.play("keypad_beep", 1.9, -14.0)
		await get_tree().create_timer(HOLD).timeout
		if not is_inside_tree():
			return
		_gag_index = (_gag_index + 1) % GAG.size()


## Progressive prefixes of `text`, one per whitespace-delimited word, ending on
## the whole string. Newlines count as boundaries, so the second gag's line
## break arrives with the word after it rather than hanging on its own.
static func word_prefixes(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(1, text.length()):
		var is_break: bool = text[i] == " " or text[i] == "\n"
		var after_break: bool = text[i - 1] == " " or text[i - 1] == "\n"
		# The second guard keeps a run of whitespace from emitting the same
		# prefix twice, which would read as a dropped frame.
		if is_break and not after_break:
			out.append(text.substr(0, i))
	if text != "":
		out.append(text)
	return out


func _on_play() -> void:
	Sfx.play("click")
	GameManager.difficulty_mode = GameManager.Difficulty.VETERAN \
		if veteran_check.button_pressed else GameManager.Difficulty.STANDARD
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
