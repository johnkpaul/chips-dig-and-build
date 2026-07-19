extends Node

## Autoload: small shared state that survives scene changes between levels
## (current level index, block backpack count). Gameplay entities read/write
## this instead of passing state through scene-instantiation arguments.

signal blocks_changed(count: int)
signal level_index_changed(index: int)

const MAX_BLOCKS := 5

## Bumped by hand on every deploy so the on-screen build tag (see main.gd)
## makes it obvious whether a device is showing a stale cached build.
const BUILD_VERSION := "2026-07-19.5"

const SAVE_PATH := "user://progress.save"

var current_level_index := 0
var block_count := 0
var custom_mission_message := ""

## Highest level index Chip has ever reached (0-based). Level 0 is always
## playable. Persisted across sessions so the title screen's level-select
## can offer replaying any level already unlocked.
var highest_unlocked_level := 0


func _ready() -> void:
	load_progress()


func unlock_level(index: int) -> void:
	if index > highest_unlocked_level:
		highest_unlocked_level = index
		save_progress()


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var(highest_unlocked_level)


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var value = f.get_var()
		if typeof(value) == TYPE_INT:
			highest_unlocked_level = value


func reset_for_level(index: int) -> void:
	current_level_index = index
	block_count = 0
	level_index_changed.emit(current_level_index)
	blocks_changed.emit(block_count)


func add_blocks(amount: int) -> void:
	block_count = clampi(block_count + amount, 0, MAX_BLOCKS)
	blocks_changed.emit(block_count)


func use_block() -> bool:
	if block_count <= 0:
		return false
	block_count -= 1
	blocks_changed.emit(block_count)
	return true


func can_place_block() -> bool:
	return block_count > 0
