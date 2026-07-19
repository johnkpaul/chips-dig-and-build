extends StaticBody2D
class_name PlacedBlock

## A block placed by the player from their backpack. Solid, permanent for
## the rest of the level, with a quick "pop-in" scale animation.


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("placed_blocks")
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
