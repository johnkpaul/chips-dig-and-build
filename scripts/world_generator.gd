extends Node2D
class_name WorldGenerator

## Builds a playable level from LevelData: renders/colliders for walls and
## breakable dirt via a runtime-built TileMapLayer, and instances crystals,
## the exit gate, and block stations as lightweight Area2D pickups.
## Placed blocks (from the player's backpack) are separate Block.tscn
## instances tracked in `_placed_blocks`, since they don't exist in the
## authored level data.

signal all_crystals_collected
signal level_complete
signal crystal_collected(collected: int, total: int)
signal blocks_granted(amount: int)

const TILE_SIZE := LevelData.TILE_SIZE
const ATLAS_WALL := 0
const ATLAS_DIRT := 1
const ATLAS_BLOCK := 2

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BLOCK_SCENE := preload("res://scenes/block.tscn")
const DIRT_BREAK_SCENE := preload("res://scenes/dirt.tscn")
const CRYSTAL_SCENE := preload("res://scenes/crystal.tscn")

var tile_map: TileMapLayer
var player: CharacterBody2D
@onready var camera: CameraFollow = $Camera2D

var level_index := 0
var level: Dictionary
var level_width := 0
var level_height := 0

var total_crystals := 0
var collected_crystals := 0

var _placed_blocks: Dictionary = {}  # Vector2i -> Node2D
var _dirt_cells: Dictionary = {}     # Vector2i -> true (still-breakable dirt)
var _wall_cells: Dictionary = {}     # Vector2i -> true (permanent solid)


func _ready() -> void:
	add_to_group("world")


func build_level(index: int) -> void:
	if not camera:
		camera = get_node_or_null("Camera2D")
	level_index = index
	level = LevelData.get_level(index)
	level_width = LevelData.get_width(level)
	level_height = LevelData.get_height(level)

	_clear_previous()
	_build_tile_layer()
	_parse_rows()

	if level.get("dark", false):
		var dim := CanvasModulate.new()
		dim.color = Color(0.55, 0.55, 0.65)
		dim.name = "DarkTint"
		add_child(dim)

	camera.set_level_bounds(level_width * TILE_SIZE, level_height * TILE_SIZE)
	camera.set_target(player)
	if camera.is_inside_tree():
		camera.make_current()
	else:
		camera.call_deferred("make_current")


func _clear_previous() -> void:
	for child in get_children():
		if child == camera:
			continue
		child.queue_free()
	_placed_blocks.clear()
	_dirt_cells.clear()
	_wall_cells.clear()
	total_crystals = 0
	collected_crystals = 0
	player = null


func _build_tile_layer() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	var physics_layer_index := tile_set.get_physics_layers_count() - 1
	tile_set.set_physics_layer_collision_layer(physics_layer_index, 1)
	tile_set.set_physics_layer_collision_mask(physics_layer_index, 0)

	_add_solid_source(tile_set, ATLAS_WALL, load("res://generated_assets/dirt_block.png"))
	_add_solid_source(tile_set, ATLAS_DIRT, load("res://generated_assets/breakable_dirt.png"))
	_add_solid_source(tile_set, ATLAS_BLOCK, load("res://generated_assets/placed_block.png"))

	tile_map = TileMapLayer.new()
	tile_map.name = "TileMapLayer"
	tile_map.tile_set = tile_set
	add_child(tile_map)


func _add_solid_source(tile_set: TileSet, source_id: int, texture: Texture2D) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i.ZERO)
	# The source must already belong to the TileSet before its TileData
	# knows about the TileSet's physics layers, so add it first.
	tile_set.add_source(source, source_id)
	var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	tile_data.add_collision_polygon(0)
	var half := TILE_SIZE / 2.0
	var polygon := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	tile_data.set_collision_polygon_points(0, 0, polygon)


func _parse_rows() -> void:
	var rows: Array = level["rows"]
	var start_cell := Vector2i(1, 1)
	var gate_cells: Array[Vector2i] = []

	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var ch := row[x]
			var cell := Vector2i(x, y)
			match ch:
				"#":
					tile_map.set_cell(cell, ATLAS_WALL, Vector2i.ZERO)
					_wall_cells[cell] = true
				"d":
					tile_map.set_cell(cell, ATLAS_DIRT, Vector2i.ZERO)
					_dirt_cells[cell] = true
				"*":
					_spawn_crystal(cell, false)
				"M":
					_spawn_crystal(cell, true)
				"C":
					start_cell = cell
				"^":
					gate_cells.append(cell)
				"B":
					_spawn_block_station(cell)
				_:
					pass

	if not gate_cells.is_empty():
		_spawn_exit_gate(gate_cells)

	_spawn_player(start_cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)


func _spawn_player(start_cell: Vector2i) -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = cell_to_world(start_cell)
	player.set_world(self)
	player.set_safe_position(player.global_position)


func _spawn_crystal(cell: Vector2i, mega: bool) -> void:
	var crystal := CRYSTAL_SCENE.instantiate()
	add_child(crystal)
	crystal.global_position = cell_to_world(cell)
	crystal.set_mega(mega)
	crystal.collected.connect(_on_crystal_collected)
	total_crystals += 1


func _on_crystal_collected(mega: bool) -> void:
	collected_crystals += 1
	crystal_collected.emit(collected_crystals, total_crystals)
	ProceduralAudio.play_sfx("crystal")
	if collected_crystals >= total_crystals:
		all_crystals_collected.emit()


func _spawn_block_station(cell: Vector2i) -> void:
	var station := Area2D.new()
	station.name = "BlockStation"
	station.global_position = cell_to_world(cell)
	station.collision_layer = 0
	station.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	shape.shape = rect
	station.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://generated_assets/placed_block.png")
	sprite.modulate = Color(1.0, 0.72, 0.30)
	station.add_child(sprite)
	add_child(station)
	station.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and station.is_inside_tree():
			# Grant a full backpack rather than exactly the minimum a gap
			# needs: the placement button only ever offers useful spots
			# now, but a couple of spare blocks still gives forgiving
			# margin against fumbled taps instead of a razor-thin exact
			# fit.
			var amount := GameManager.MAX_BLOCKS
			if body.has_method("add_blocks"):
				body.add_blocks(amount)
			blocks_granted.emit(amount)
			ProceduralAudio.play_sfx("place")
			station.queue_free()
	)


func _spawn_exit_gate(cells: Array[Vector2i]) -> void:
	var gate := Area2D.new()
	gate.name = "ExitGate"
	var top_cell: Vector2i = cells[0]
	for c in cells:
		if c.y < top_cell.y:
			top_cell = c
	var center := cell_to_world(top_cell) + Vector2(0, TILE_SIZE * 0.5 * (cells.size() - 1))
	gate.global_position = center
	gate.collision_layer = 0
	gate.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE * cells.size())
	shape.shape = rect
	gate.add_child(shape)
	var sprite := ColorRect.new()
	sprite.color = Color(1.0, 0.42, 0.10, 0.55)
	sprite.size = rect.size
	sprite.position = -rect.size / 2.0
	gate.add_child(sprite)
	add_child(gate)
	gate.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and collected_crystals >= total_crystals:
			level_complete.emit()
	)


# ---------------------------------------------------------------------------
# Grid queries used by player.gd
# ---------------------------------------------------------------------------

func is_solid(cell: Vector2i) -> bool:
	return _wall_cells.has(cell) or _dirt_cells.has(cell) or _placed_blocks.has(cell)


func is_breakable_dirt(cell: Vector2i) -> bool:
	return _dirt_cells.has(cell)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < level_width and cell.y < level_height


func break_tile(cell: Vector2i) -> void:
	if not _dirt_cells.has(cell):
		return
	_dirt_cells.erase(cell)
	tile_map.erase_cell(cell)
	var burst := DIRT_BREAK_SCENE.instantiate()
	add_child(burst)
	burst.global_position = cell_to_world(cell)
	ProceduralAudio.play_sfx("drill")
	if camera:
		camera.shake(1.5)


func try_place_block(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if is_solid(cell):
		return false
	var block := BLOCK_SCENE.instantiate()
	add_child(block)
	block.global_position = cell_to_world(cell)
	_placed_blocks[cell] = block
	ProceduralAudio.play_sfx("place")
	return true


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE_SIZE), floori(pos.y / TILE_SIZE))
