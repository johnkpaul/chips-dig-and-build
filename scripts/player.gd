extends CharacterBody2D
class_name Player

## Chip. All input arrives via TouchControls signals (joystick_moved,
## primary_pressed/released, place_pressed) — never through InputMap, since
## this game is touch-native. Mouse events are translated into the same
## signals upstream by TouchControls for desktop testing.

enum State { IDLE, WALK, JUMP, DRILL, PLACE, REBOOT }

## Scaled 4x alongside everything else in the 4x resolution pass (see
## procedural_art.gd's SCALE constant) so Chip still crosses the same
## number of tiles per second and jumps the same proportional height -
## only the pixel-art detail density changed, not the game's feel.
const SPEED := 360.0
const JUMP_VELOCITY := -960.0
const GRAVITY := 3200.0
const DRILL_TIME := 0.4
const REBOOT_Y_THRESHOLD := 1200.0
const WALK_FRAME_TIME := 0.18

const TILE_SIZE := 64

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

const TEX_IDLE := preload("res://generated_assets/chip_idle.png")
const TEX_WALK1 := preload("res://generated_assets/chip_walk1.png")
const TEX_WALK2 := preload("res://generated_assets/chip_walk2.png")
const TEX_DRILL := preload("res://generated_assets/chip_drill.png")

var world: WorldGenerator
var touch_controls: TouchControls

var state: State = State.IDLE
var move_input := 0.0
var facing := 1
var last_safe_position := Vector2.ZERO

var _drill_timer := 0.0
var _walk_timer := 0.0
var _walk_frame := 0
var _rebooting := false
var _last_primary_mode := ""


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	sprite.texture = TEX_IDLE

	touch_controls = get_tree().get_first_node_in_group("touch_controls")
	if touch_controls:
		touch_controls.joystick_moved.connect(_on_joystick_moved)
		touch_controls.primary_pressed.connect(_on_primary_pressed)
		touch_controls.place_pressed.connect(_on_place_pressed)


func set_world(w: WorldGenerator) -> void:
	world = w


func set_safe_position(pos: Vector2) -> void:
	last_safe_position = pos


func _on_joystick_moved(vec: Vector2) -> void:
	move_input = vec.x


func _on_primary_pressed() -> void:
	if _rebooting or state == State.DRILL:
		return
	if is_on_dirt():
		_start_drill()
	elif is_on_floor():
		_jump()


func _on_place_pressed() -> void:
	if _rebooting:
		return
	place_block()


func _physics_process(delta: float) -> void:
	if _rebooting:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if state != State.DRILL:
		velocity.x = move_input * SPEED
		if absf(move_input) > 0.05:
			facing = 1 if move_input > 0.0 else -1
	else:
		velocity.x = 0.0

	move_and_slide()

	if state == State.DRILL:
		_drill_timer -= delta
		if _drill_timer <= 0.0:
			_finish_drill()
	else:
		_update_locomotion_state(delta)

	if is_on_floor() and state in [State.IDLE, State.WALK]:
		last_safe_position = global_position

	if global_position.y > REBOOT_Y_THRESHOLD:
		reboot()

	_update_touch_ui()


func _update_locomotion_state(delta: float) -> void:
	if not is_on_floor():
		state = State.JUMP
		sprite.texture = TEX_IDLE
		sprite.scale.x = facing
		return

	if absf(velocity.x) > 1.0:
		state = State.WALK
		_walk_timer += delta
		if _walk_timer >= WALK_FRAME_TIME:
			_walk_timer = 0.0
			_walk_frame = 1 - _walk_frame
		sprite.texture = TEX_WALK1 if _walk_frame == 0 else TEX_WALK2
	else:
		state = State.IDLE
		sprite.texture = TEX_IDLE
	sprite.scale.x = facing


func _jump() -> void:
	velocity.y = JUMP_VELOCITY
	state = State.JUMP
	ProceduralAudio.play_sfx("jump")


func _feet_probe_offset() -> float:
	# Distance from global_position straight down to just past the bottom
	# of the collision shape, so a sample at that offset actually lands
	# inside the tile Chip is standing on (not still inside his own body).
	var half_height := 32.0
	var shape_bottom := 0.0
	if collision and collision.shape is RectangleShape2D:
		half_height = (collision.shape as RectangleShape2D).size.y / 2.0
		shape_bottom = collision.position.y
	return shape_bottom + half_height + 8.0


func is_on_dirt() -> bool:
	if not world or not is_on_floor():
		return false
	var below := world.world_to_cell(global_position + Vector2(0, _feet_probe_offset()))
	return world.is_breakable_dirt(below)


func _start_drill() -> void:
	state = State.DRILL
	_drill_timer = DRILL_TIME
	velocity.x = 0.0
	sprite.texture = TEX_DRILL
	sprite.scale.x = facing
	ProceduralAudio.play_sfx("drill")


func _finish_drill() -> void:
	if world:
		var below := world.world_to_cell(global_position + Vector2(0, _feet_probe_offset()))
		world.break_tile(below)
	state = State.IDLE


func can_place_block() -> bool:
	if not world or GameManager.block_count <= 0:
		return false
	return _find_place_cell() != null


func _find_place_cell() -> Variant:
	if not world:
		return null
	# Anchor candidates to the floor row Chip is actually standing on
	# (same probe used for drilling), not his body-center row. Otherwise
	# "facing direction" lands at chest height in open air instead of at
	# floor level where a bridge gap actually is.
	var feet_cell := world.world_to_cell(global_position + Vector2(0, _feet_probe_offset()))
	var left_cell := feet_cell + Vector2i(-1, 0)
	var right_cell := feet_cell + Vector2i(1, 0)
	var left_open := world.is_in_bounds(left_cell) and not world.is_solid(left_cell)
	var right_open := world.is_in_bounds(right_cell) and not world.is_solid(right_cell)

	# Only ever offer a floor-level bridge placement, left or right.
	# Deliberately NOT falling back to "underfoot" or "above your head"
	# when neither side is open: the backpack is scarce (exactly enough
	# blocks for the gaps that need them), so a tap that can't usefully
	# extend a bridge should do nothing rather than waste a block on a
	# spot that can never help - e.g. tapping place again before walking
	# onto the block you just placed, with solid ground on both sides now.
	if left_open and not right_open:
		return left_cell
	if right_open and not left_open:
		return right_cell
	if left_open and right_open:
		# Both sides open (e.g. standing over a wide gap already) - use
		# facing only as a tiebreaker.
		return right_cell if facing >= 0 else left_cell
	return null


func place_block() -> void:
	if not can_place_block():
		return
	var cell = _find_place_cell()
	if cell == null:
		return
	if world.try_place_block(cell):
		GameManager.use_block()
		if touch_controls:
			touch_controls.play_place_feedback()
		_screen_shake()


func add_blocks(amount: int) -> void:
	GameManager.add_blocks(amount)


func _screen_shake() -> void:
	if world and world.camera:
		world.camera.shake(8.0)


func reboot() -> void:
	if _rebooting:
		return
	_rebooting = true
	state = State.REBOOT
	velocity = Vector2.ZERO
	ProceduralAudio.play_sfx("reboot")

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.size = Vector2(1920, 1080)
	flash.position = -Vector2(960, 540)
	flash.z_index = 100
	add_child(flash)

	var tw := create_tween()
	tw.tween_property(flash, "color:a", 1.0, 0.1)
	tw.tween_callback(func():
		global_position = last_safe_position
		velocity = Vector2.ZERO
	)
	tw.tween_property(flash, "color:a", 0.0, 0.25)
	tw.tween_callback(func():
		flash.queue_free()
		_rebooting = false
		state = State.IDLE
	)


func _update_touch_ui() -> void:
	if not touch_controls:
		return
	var mode := "drill" if is_on_dirt() else "jump"
	if mode != _last_primary_mode:
		_last_primary_mode = mode
		touch_controls.set_primary_mode(mode)
	touch_controls.set_place_available(can_place_block())
