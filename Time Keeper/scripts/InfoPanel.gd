class_name InfoPanel
extends PanelContainer
## Base class for the title card's full-screen reading panels -- the rules and
## the credits. Owns the modal behaviour; subclasses supply the text.
##
## Both scenes share the node layout below. A subclass overrides `_build()` and
## nothing else.

signal closed

const GOLD := "c79e4a"
const DIM := "8d93a1"
const GREEN := "5cbf6b"
const AMBER := "ebad33"
const RED := "d93d38"

var _focus_before: Control = null

@onready var body: RichTextLabel = $Center/Panel/Margin/Stack/Scroll/Body
@onready var scroll: ScrollContainer = $Center/Panel/Margin/Stack/Scroll
@onready var close_button: Button = $Center/Panel/Margin/Stack/Close


func _ready() -> void:
	close_button.pressed.connect(close)
	body.text = _build()
	visible = false


func open() -> void:
	if visible:
		return
	visible = true
	# Reopening should start at the top rather than wherever the last read
	# happened to end.
	scroll.scroll_vertical = 0
	_focus_before = get_viewport().gui_get_focus_owner()
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play("click")
	if is_instance_valid(_focus_before):
		_focus_before.grab_focus()
	_focus_before = null
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- helpers for subclasses ---------------------------------------------------

func _build() -> String:
	return ""


func _heading(text: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [GOLD, text]


## Text that did not come from us -- a pasted licence, a URL -- must not be read
## as BBCode. An unbalanced bracket in an attribution would otherwise swallow
## the rest of the panel.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")
