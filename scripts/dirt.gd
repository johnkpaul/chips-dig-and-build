extends Node2D
class_name DirtBreakEffect

## Spawned by WorldGenerator.break_tile() at the moment a breakable-dirt
## cell is drilled away. Bursts a handful of debris chunks that actually
## arc and fall under gravity (rather than just fading outward in place),
## so a broken tile reads as crumbling rubble instead of a clean, flat
## rectangle disappearing.

const CHUNK_COLORS := [
	Color(0.545, 0.369, 0.235),  # dirt brown
	Color(0.290, 0.188, 0.125),  # dirt dark
	Color(0.800, 0.267, 0.0),    # dark orange (kicked-up highlight bits)
]
const CHUNK_COUNT := 7
const GRAVITY := 500.0
const LIFETIME := 0.45

var _particles: Array[Dictionary] = []
var _age := 0.0


func _ready() -> void:
	for i in range(CHUNK_COUNT):
		var p := ColorRect.new()
		var size: float = randf_range(1.5, 3.5)
		p.size = Vector2(size, size)
		p.position = -p.size / 2.0
		p.color = CHUNK_COLORS[randi() % CHUNK_COLORS.size()]
		add_child(p)

		var angle := randf_range(-PI * 0.85, -PI * 0.15)  # mostly upward burst
		var speed := randf_range(30.0, 65.0)
		_particles.append({
			"node": p,
			"velocity": Vector2.from_angle(angle) * speed,
		})

	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	for particle in _particles:
		var node: ColorRect = particle["node"]
		var vel: Vector2 = particle["velocity"]
		vel.y += GRAVITY * delta
		particle["velocity"] = vel
		node.position += vel * delta

	var fade_start := LIFETIME * 0.6
	if _age > fade_start:
		var t: float = clampf((_age - fade_start) / (LIFETIME - fade_start), 0.0, 1.0)
		modulate.a = 1.0 - t

	if _age >= LIFETIME:
		queue_free()
