extends CanvasLayer
class_name UIManager

## Persistent HUD: crystal meter (top-left), block backpack counter
## (top-right), a small MENU button (top-center) to bail out of the
## current level back to the title screen, and an idle hint arrow after
## 5s of no input.

signal menu_requested

const IDLE_HINT_DELAY := 5.0
const BLOCK_SQUARE_SIZE := 12.0
const BLOCK_SQUARE_GAP := 4.0

@onready var meter_fill_clip: Control = $CrystalMeter/FillClip
@onready var meter_fill: TextureRect = $CrystalMeter/FillClip/Fill
@onready var block_squares_root: Control = $BlockCounter
@onready var idle_hint: TextureRect = $IdleHint
@onready var menu_button: Button = $MenuButton

var world: WorldGenerator
var _block_squares: Array[ColorRect] = []
var _idle_timer := 0.0
var _hint_visible := false
var _hint_tween: Tween


func _ready() -> void:
	layer = 5
	meter_fill_clip.clip_contents = true
	_build_block_squares()
	GameManager.blocks_changed.connect(_on_blocks_changed)
	_on_blocks_changed(GameManager.block_count)
	idle_hint.texture = load("res://generated_assets/icon_arrow_hint.png")
	idle_hint.modulate.a = 0.0

	menu_button.pressed.connect(func(): menu_requested.emit())

	var tc: TouchControls = get_tree().get_first_node_in_group("touch_controls")
	if tc:
		tc.joystick_moved.connect(func(v: Vector2): if absf(v.x) > 0.05: _reset_idle())
		tc.primary_pressed.connect(_reset_idle)
		tc.place_pressed.connect(_reset_idle)


func bind_world(w: WorldGenerator) -> void:
	world = w
	world.crystal_collected.connect(_on_crystal_progress)
	_on_crystal_progress(world.collected_crystals, maxi(world.total_crystals, 1))
	_reset_idle()


func _on_crystal_progress(collected: int, total: int) -> void:
	var ratio: float = float(collected) / float(maxi(total, 1))
	var full_width: float = meter_fill.size.x
	var tw := create_tween()
	tw.tween_property(meter_fill_clip, "size:x", full_width * ratio, 0.25)


func _build_block_squares() -> void:
	for i in range(GameManager.MAX_BLOCKS):
		var sq := ColorRect.new()
		sq.size = Vector2(BLOCK_SQUARE_SIZE, BLOCK_SQUARE_SIZE)
		sq.position = Vector2(-(i + 1) * (BLOCK_SQUARE_SIZE + BLOCK_SQUARE_GAP), 0)
		block_squares_root.add_child(sq)
		_block_squares.append(sq)


func _on_blocks_changed(count: int) -> void:
	for i in range(_block_squares.size()):
		var filled: bool = i < count
		_block_squares[i].color = Color(1.0, 0.42, 0.10, 1.0) if filled else Color(0.48, 0.55, 0.6, 0.35)


func _process(delta: float) -> void:
	if not world or not world.player:
		return
	_idle_timer += delta
	if _idle_timer >= IDLE_HINT_DELAY and not _hint_visible:
		_show_hint()
	if _hint_visible:
		_update_hint_position()


func _reset_idle() -> void:
	_idle_timer = 0.0
	if _hint_visible:
		_hide_hint()


func _show_hint() -> void:
	_hint_visible = true
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	_hint_tween.tween_property(idle_hint, "modulate:a", 1.0, 0.4)
	_hint_tween.tween_property(idle_hint, "modulate:a", 0.15, 0.4)


func _hide_hint() -> void:
	_hint_visible = false
	if _hint_tween:
		_hint_tween.kill()
	idle_hint.modulate.a = 0.0


func _update_hint_position() -> void:
	var crystals := get_tree().get_nodes_in_group("crystal")
	if crystals.is_empty() or not world.camera:
		idle_hint.visible = false
		return
	idle_hint.visible = true

	var player_pos: Vector2 = world.player.global_position
	var nearest: Node2D = crystals[0]
	var nearest_dist := player_pos.distance_squared_to(nearest.global_position)
	for c in crystals:
		var d := player_pos.distance_squared_to(c.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = c

	var dir: Vector2 = (nearest.global_position - player_pos)
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var screen_player: Vector2 = world.camera.unproject_position(player_pos)
	idle_hint.position = screen_player + dir * 24.0 - idle_hint.size / 2.0
	idle_hint.rotation = dir.angle() + PI / 2.0
