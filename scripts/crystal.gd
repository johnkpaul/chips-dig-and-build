extends Area2D
class_name Crystal

## Collectible crystal. Small crystals (16x16) count toward level completion;
## the level-3 mega crystal (32x32) is the "final crystal" that leads into
## the Mission File after the exit gate is reached.

signal collected(mega: bool)

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

var _mega := false
var _collected := false

const TEX_SMALL := preload("res://generated_assets/crystal_small.png")
const TEX_MEGA := preload("res://generated_assets/crystal_mega.png")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_start_pulse()


func set_mega(mega: bool) -> void:
	_mega = mega
	if sprite:
		sprite.texture = TEX_MEGA if mega else TEX_SMALL
	if shape and shape.shape is RectangleShape2D:
		var size := 32.0 if mega else 16.0
		(shape.shape as RectangleShape2D).size = Vector2(size, size)


func _start_pulse() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	collected.emit(_mega)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)
