extends CanvasLayer
class_name TouchControls

## Primary input system for Chip's Dig & Build. Owns the virtual joystick
## (left half of screen) and the two contextual action buttons (right half).
## Player.gd listens to these signals instead of reading InputMap directly.

signal joystick_moved(vector: Vector2)
signal primary_pressed
signal primary_released
signal place_pressed

const JOYSTICK_RADIUS := 232.0
const DEADZONE := 0.15
const ICON_MORPH_TIME := 0.15

@onready var joystick: Control = $Joystick
@onready var joy_base: TextureRect = $Joystick/Base
@onready var joy_thumb: TextureRect = $Joystick/Thumb
@onready var primary_button: TouchButton = $PrimaryButton
@onready var primary_base: TextureRect = $PrimaryButton/ButtonBase
@onready var primary_icon: TextureRect = $PrimaryButton/ButtonIcon
@onready var secondary_button: TouchButton = $SecondaryButton
@onready var secondary_icon: TextureRect = $SecondaryButton/ButtonIcon

var _icon_jump: Texture2D = load("res://generated_assets/icon_jump.png")
var _icon_drill: Texture2D = load("res://generated_assets/icon_drill.png")
var _icon_block: Texture2D = load("res://generated_assets/icon_block.png")

var _joy_touch_index := -2  # -2 = untouched, -1 = mouse
var _joy_center := Vector2.ZERO
var _joy_vector := Vector2.ZERO
var _primary_mode := "jump"  # "jump" | "drill"
var _joy_home_position := Vector2.ZERO


func _ready() -> void:
	add_to_group("touch_controls")
	layer = 10
	joy_base.modulate.a = 0.0
	joy_thumb.modulate.a = 0.0
	_joy_home_position = joy_base.position
	primary_icon.texture = _icon_jump
	secondary_icon.texture = _icon_block
	secondary_button.set_shown(false)

	primary_button.pressed.connect(func(): primary_pressed.emit())
	primary_button.released.connect(func(): primary_released.emit())
	secondary_button.pressed.connect(func(): place_pressed.emit())

	_prevent_browser_scroll()


func _input(event: InputEvent) -> void:
	var vp_width: float = get_viewport().get_visible_rect().size.x
	var half_x: float = vp_width * 0.5

	if event is InputEventScreenTouch:
		if event.position.x < half_x:
			if event.pressed:
				_joystick_start(event.index, event.position)
			elif event.index == _joy_touch_index:
				_joystick_end()
	elif event is InputEventScreenDrag:
		if event.index == _joy_touch_index:
			_joystick_update(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x < half_x:
			if event.pressed:
				_joystick_start(-1, event.position)
			elif _joy_touch_index == -1:
				_joystick_end()
	elif event is InputEventMouseMotion:
		if _joy_touch_index == -1 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_joystick_update(event.position)


func _joystick_start(idx: int, pos: Vector2) -> void:
	_joy_touch_index = idx
	_joy_center = pos
	joy_base.global_position = pos - joy_base.size / 2.0
	joy_thumb.global_position = pos - joy_thumb.size / 2.0
	joy_base.modulate.a = 1.0
	joy_thumb.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(joy_thumb, "scale", Vector2(1.2, 1.2), 0.08)
	_spawn_joy_particles(pos)


func _joystick_update(pos: Vector2) -> void:
	var delta: Vector2 = pos - _joy_center
	var clamped: Vector2 = delta.limit_length(JOYSTICK_RADIUS)
	joy_thumb.global_position = _joy_center + clamped - joy_thumb.size / 2.0

	var norm: Vector2 = clamped / JOYSTICK_RADIUS
	var out := Vector2.ZERO
	if absf(norm.x) > DEADZONE:
		out.x = norm.x
	_joy_vector = out
	joystick_moved.emit(_joy_vector)


func _joystick_end() -> void:
	_joy_touch_index = -2
	_joy_vector = Vector2.ZERO
	joystick_moved.emit(_joy_vector)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(joy_thumb, "global_position", joy_base.global_position + joy_base.size / 2.0 - joy_thumb.size / 2.0, 0.1)
	tw.tween_property(joy_thumb, "scale", Vector2.ONE, 0.1)
	tw.tween_property(joy_base, "modulate:a", 0.0, 0.15).set_delay(0.05)
	tw.tween_property(joy_thumb, "modulate:a", 0.0, 0.15).set_delay(0.05)


func _spawn_joy_particles(pos: Vector2) -> void:
	for i in range(2):
		var p := ColorRect.new()
		p.color = Color(1.0, 0.42, 0.10)
		p.size = Vector2(8, 8)
		p.global_position = pos
		add_child(p)
		var dir := Vector2.from_angle(randf() * TAU)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", pos + dir * 80.0, 0.3)
		tw.tween_property(p, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(p.queue_free)


## Called by player.gd (or game logic) whenever the player's dirt-standing
## state changes, so the Primary button can morph between JUMP and DRILL.
func set_primary_mode(mode: String) -> void:
	if mode == _primary_mode:
		return
	_primary_mode = mode
	var new_icon: Texture2D = _icon_drill if mode == "drill" else _icon_jump
	var tw := create_tween()
	tw.tween_property(primary_icon, "scale", Vector2(0.0, 0.0), ICON_MORPH_TIME * 0.5)
	tw.tween_callback(func(): primary_icon.texture = new_icon)
	tw.tween_property(primary_icon, "scale", Vector2(1.0, 1.0), ICON_MORPH_TIME * 0.5)


## Called by player.gd whenever backpack count or adjacent-empty-tile state
## changes, to show/hide the contextual Secondary (place block) button.
func set_place_available(available: bool) -> void:
	secondary_button.set_shown(available)


## Called after a successful block placement for the "snap" pop feedback.
func play_place_feedback() -> void:
	secondary_button.punch_scale()


func flash_primary() -> void:
	var tw := create_tween()
	primary_base.modulate = Color(2.0, 2.0, 2.0)
	tw.tween_property(primary_base, "modulate", Color(1, 1, 1), 0.15)


func _prevent_browser_scroll() -> void:
	if OS.get_name() != "Web":
		return
	JavaScriptBridge.eval("""
		document.addEventListener('touchmove', function(e) { e.preventDefault(); }, { passive: false });
		document.addEventListener('gesturestart', function(e) { e.preventDefault(); }, { passive: false });
		document.body.style.touchAction = 'none';
	""", true)
