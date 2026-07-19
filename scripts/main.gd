extends Node
class_name Main

## Root of the game: title screen -> Level 1 -> Level 2 -> Level 3 ->
## Mission File. Owns the persistent TouchControls and UIManager layers
## (they survive across level loads) and swaps World instances between
## levels.

const WORLD_SCENE := preload("res://scenes/world.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch_controls.tscn")
const UI_SCENE := preload("res://scenes/ui.tscn")
const MISSION_FILE_SCENE := preload("res://scenes/mission_file.tscn")

const LEVEL_CLEAR_DURATION := 2.0
const TITLE_MIN_DURATION := 3.0

@onready var title_screen: CanvasLayer = $TitleScreen
@onready var title_label: Label = $TitleScreen/TitleLabel
@onready var level_clear_overlay: CanvasLayer = $LevelClearOverlay
@onready var world_container: Node2D = $WorldContainer

var touch_controls: TouchControls
var ui_manager: UIManager
var current_world: WorldGenerator
var _audio_unlocked := false
var _title_touch_ready := false


func _ready() -> void:
	_ensure_generated_assets()

	touch_controls = TOUCH_CONTROLS_SCENE.instantiate()
	add_child(touch_controls)

	ui_manager = UI_SCENE.instantiate()
	add_child(ui_manager)

	level_clear_overlay.visible = false
	title_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.10))
	title_label.text = "CHIP'S DIG & BUILD"

	title_screen.visible = true
	await get_tree().create_timer(TITLE_MIN_DURATION).timeout
	_title_touch_ready = true


func _ensure_generated_assets() -> void:
	var probe_path := "res://generated_assets/chip_idle.png"
	if not FileAccess.file_exists(probe_path):
		# Editor-convenience fallback only: an exported HTML5 build ships
		# with generated_assets/ already baked in by build.sh, since
		# preload() calls elsewhere need the files to exist at export time.
		ProceduralArt.run_all()


func _input(event: InputEvent) -> void:
	if not title_screen.visible:
		return
	if not _title_touch_ready:
		return
	var touched: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if touched:
		_start_game()


func _start_game() -> void:
	if not _audio_unlocked:
		_audio_unlocked = true
		ProceduralAudio.unlock_audio()
	title_screen.visible = false
	_load_level(0)


func _load_level(index: int) -> void:
	GameManager.reset_for_level(index)
	current_world = WORLD_SCENE.instantiate()
	world_container.add_child(current_world)
	current_world.build_level(index)
	ui_manager.bind_world(current_world)
	current_world.level_complete.connect(_on_level_complete.bind(index), CONNECT_ONE_SHOT)


func _on_level_complete(index: int) -> void:
	_show_level_clear()
	await get_tree().create_timer(LEVEL_CLEAR_DURATION).timeout
	_hide_level_clear()

	if current_world:
		current_world.queue_free()
		current_world = null

	if index + 1 < LevelData.get_level_count():
		_load_level(index + 1)
	else:
		_show_mission_file()


func _show_level_clear() -> void:
	level_clear_overlay.visible = true
	var label: Label = level_clear_overlay.get_node("LevelClearLabel")
	label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.3)


func _hide_level_clear() -> void:
	level_clear_overlay.visible = false


func _show_mission_file() -> void:
	var mission := MISSION_FILE_SCENE.instantiate()
	if GameManager.custom_mission_message != "":
		mission.custom_message = GameManager.custom_mission_message
	add_child(mission)
	mission.mission_complete.connect(func():
		mission.queue_free()
		title_screen.visible = true
		_title_touch_ready = true
	)
	mission.play()
