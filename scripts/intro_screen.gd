extends CanvasLayer
class_name IntroScreen

## A short, icon-only tutorial shown once before a player's very first
## level, so the game doesn't drop them straight into gameplay with no
## explanation. No reading required - each card is a picture, held briefly,
## auto-advancing on its own, or tap the dedicated NEXT button to move on
## sooner. Deliberately NOT a whole-screen tap target: a kid poking around
## the screen (e.g. trying the joystick area out of curiosity) shouldn't
## accidentally blow through the whole tutorial. Skippable instantly since
## repeat players never see it again (GameManager.has_seen_intro persists
## across sessions).

signal intro_complete

const CARD_HOLD := 2.3
const FADE_TIME := 0.3
const BG_COLOR := Color(0.101961, 0.101961, 0.101961, 1)
const CAPTION_COLOR := Color(1.0, 0.42, 0.10)
const HINT_COLOR := Color(1.0, 0.72, 0.30, 0.55)

var _cards: Array[Dictionary] = [
	{
		"icons": ["res://generated_assets/chip_idle.png", "res://generated_assets/crystal_small.png"],
		"text": "COLLECT THE CRYSTALS",
	},
	{
		"icons": ["res://generated_assets/joystick_base.png", "res://generated_assets/joystick_thumb.png"],
		"text": "DRAG TO MOVE",
	},
	{
		"icons": ["res://generated_assets/icon_jump.png", "res://generated_assets/icon_drill.png"],
		"text": "TAP TO JUMP OR DIG",
	},
]

var _icon_rects: Array[TextureRect] = []
var _caption: Label
var _next_button: Button
var _index := -1
var _advancing := false
var _visible_now := false


func _ready() -> void:
	layer = 18
	visible = false

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(480, 270)
	add_child(bg)

	for i in range(2):
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2(48, 48)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.position = Vector2(150 + i * 110, 90)
		rect.modulate.a = 0.0
		add_child(rect)
		_icon_rects.append(rect)

	_caption = Label.new()
	_caption.offset_left = 40
	_caption.offset_top = 175
	_caption.offset_right = 440
	_caption.offset_bottom = 205
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", CAPTION_COLOR)
	_caption.modulate.a = 0.0
	add_child(_caption)

	# A real button, not a whole-screen tap zone: advancing the tutorial
	# should only happen from a deliberate tap on this specific control.
	_next_button = Button.new()
	_next_button.offset_left = 190
	_next_button.offset_top = 240
	_next_button.offset_right = 290
	_next_button.offset_bottom = 264
	_next_button.add_theme_font_size_override("font_size", 11)
	_next_button.add_theme_color_override("font_color", HINT_COLOR)
	_next_button.flat = true
	_next_button.text = "NEXT ▶"
	_next_button.pressed.connect(_try_advance)
	add_child(_next_button)


func play() -> void:
	visible = true
	_visible_now = true
	_index = -1
	_next_card()


func _next_card() -> void:
	_advancing = false
	_index += 1
	if _index >= _cards.size():
		_finish()
		return

	var card: Dictionary = _cards[_index]
	var icons: Array = card["icons"]
	for i in range(_icon_rects.size()):
		_icon_rects[i].texture = load(icons[i]) if i < icons.size() else null
		_icon_rects[i].modulate.a = 0.0
	_caption.text = card["text"]
	_caption.modulate.a = 0.0
	_next_button.text = "START ▶" if _index == _cards.size() - 1 else "NEXT ▶"

	var tw := create_tween()
	tw.set_parallel(true)
	for rect in _icon_rects:
		tw.tween_property(rect, "modulate:a", 1.0, FADE_TIME)
	tw.tween_property(_caption, "modulate:a", 1.0, FADE_TIME)

	get_tree().create_timer(CARD_HOLD).timeout.connect(_try_advance)


func _try_advance() -> void:
	if _advancing or not _visible_now:
		return
	_advancing = true
	_next_card()


func _finish() -> void:
	_visible_now = false
	visible = false
	intro_complete.emit()
