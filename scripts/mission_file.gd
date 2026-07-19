extends CanvasLayer
class_name MissionFile

## Full-screen "Mission File" reveal shown after Chip collects every crystal
## (including the level-3 mega crystal) and clears the exit gate. Reveals
## five lines one at a time, then waits for a tap to continue.

signal mission_complete

@export_multiline var custom_message: String = "A TRIP TO THE CHOCOLATE MOUNTAINS"

const ORANGE := Color(1.0, 0.42, 0.10)
const LIGHT_ORANGE := Color(1.0, 0.72, 0.30)
const LINE_DELAY := 0.9

@onready var background: ColorRect = $Background
@onready var envelope_body: ColorRect = $Envelope/Body
@onready var envelope_flap: Polygon2D = $Envelope/Flap
@onready var lines_container: VBoxContainer = $Lines
@onready var tap_hint: Label = $TapHint

var _ready_for_tap := false


func _ready() -> void:
	layer = 20
	visible = false
	background.color = Color(0.10, 0.10, 0.10, 1.0)
	background.size = Vector2(480, 270)

	var texts := [
		"MISSION COMPLETE",
		"TOP SECRET FILE UNLOCKED",
		"YOUR NEXT MISSION:",
		custom_message,
		"PACK YOUR BAGS!",
	]
	for i in range(lines_container.get_child_count()):
		var label: Label = lines_container.get_child(i)
		label.text = texts[i] if i < texts.size() else ""
		label.modulate.a = 0.0
		label.add_theme_color_override("font_color", ORANGE)

	tap_hint.text = "TAP TO CONTINUE"
	tap_hint.add_theme_color_override("font_color", LIGHT_ORANGE)
	tap_hint.modulate.a = 0.0


func play() -> void:
	visible = true
	_ready_for_tap = false
	get_tree().create_timer(0.3).timeout.connect(_reveal_next_line.bind(0))


func _reveal_next_line(index: int) -> void:
	if index >= lines_container.get_child_count():
		_show_tap_hint()
		return
	var label: Label = lines_container.get_child(index)
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.4)
	get_tree().create_timer(LINE_DELAY).timeout.connect(_reveal_next_line.bind(index + 1))


func _show_tap_hint() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(tap_hint, "modulate:a", 1.0, 0.5)
	tw.tween_property(tap_hint, "modulate:a", 0.2, 0.5)
	_ready_for_tap = true


func _input(event: InputEvent) -> void:
	if not visible or not _ready_for_tap:
		return
	if event is InputEventScreenTouch and event.pressed:
		_continue()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_continue()


func _continue() -> void:
	_ready_for_tap = false
	mission_complete.emit()
