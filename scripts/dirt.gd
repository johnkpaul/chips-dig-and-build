extends Node2D
class_name DirtBreakEffect

## Spawned by WorldGenerator.break_tile() at the moment a breakable-dirt
## cell is drilled away. Bursts 4 small orange particles and frees itself.

const PARTICLE_COLOR := Color(1.0, 0.42, 0.10)
const PARTICLE_COUNT := 4
const PARTICLE_LIFETIME := 0.35


func _ready() -> void:
	for i in range(PARTICLE_COUNT):
		var p := ColorRect.new()
		p.color = PARTICLE_COLOR
		p.size = Vector2(2, 2)
		p.position = Vector2(-1, -1)
		add_child(p)
		var angle := (TAU / PARTICLE_COUNT) * i + randf_range(-0.3, 0.3)
		var dir := Vector2.from_angle(angle)
		var target := dir * randf_range(10.0, 16.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", target, PARTICLE_LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, PARTICLE_LIFETIME)

	var cleanup_timer := get_tree().create_timer(PARTICLE_LIFETIME + 0.05)
	cleanup_timer.timeout.connect(queue_free)
