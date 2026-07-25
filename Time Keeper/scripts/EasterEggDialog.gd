extends Control
## Placeholder easter-egg reward. It pauses every countdown while it is open --
## rewarding curiosity with a lost heart is a worse joke than it sounds.

signal closed

@onready var close_button: Button = $Center/Panel/Margin/Stack/Close
@onready var message_label: Label = $Center/Panel/Margin/Stack/Message

var _focus_before: Control = null


func _ready() -> void:
	close_button.pressed.connect(close)
	visible = false


func open(message: String = "You found an easter egg!") -> void:
	if visible:
		return
	message_label.text = message
	visible = true
	GameManager.modal_open = true
	_focus_before = get_viewport().gui_get_focus_owner()
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	GameManager.modal_open = false
	Sfx.play("click")
	# Hand focus back where it was -- usually the rocket box the word was typed
	# into, which is where the player expects to keep typing.
	if is_instance_valid(_focus_before):
		_focus_before.grab_focus()
	_focus_before = null
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
