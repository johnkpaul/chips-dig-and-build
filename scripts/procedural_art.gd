extends SceneTree
class_name ProceduralArt

## Generates every game texture at runtime/editor-time and saves PNGs to
## res://generated_assets/. Callable two ways:
##   1. Headless CLI: `godot --headless --path . --script scripts/procedural_art.gd`
##      (this script is the SceneTree main loop; _initialize() runs run_all() then quits)
##   2. From game code: `ProceduralArt.run_all()` (pure static call, no instancing needed)

const OUT_DIR := "res://generated_assets/"

## Every _make_* function below still thinks and draws in the "classic"
## logical pixel-art coordinates (16x16 tiles, 24x24 sprites, etc.) - the
## primitive draw helpers (_new_image, _fill_rect, _fill_circle, ...)
## transparently multiply everything by SCALE before touching real pixels.
## This is what actually reduces the "way too pixelated" look on a
## high-DPI phone: it's not enough to just report a bigger resolution
## number, the generated PNGs need genuinely more distinct pixels of
## detail (a circle drawn at 4x the radius has 4x the points around its
## circumference, so the stair-stepped edge is proportionally much finer).
const SCALE := 4

const HERO_ORANGE := Color8(0xFF, 0x6B, 0x1A)
const LIGHT_ORANGE := Color8(0xFF, 0xB8, 0x4D)
const DARK_ORANGE := Color8(0xCC, 0x44, 0x00)
const SKY_CYAN := Color8(0x4D, 0xE6, 0xFF)
const DIRT_BROWN := Color8(0x8B, 0x5E, 0x3C)
const DIRT_DARK := Color8(0x4A, 0x30, 0x20)
const CLOUD_WHITE := Color8(0xF0, 0xF0, 0xF0)
const ROBOT_GREY := Color8(0x7A, 0x8B, 0x99)
const VOID_BLACK := Color8(0x1A, 0x1A, 0x1A)

const TRANSPARENT := Color(0, 0, 0, 0)


func _initialize() -> void:
	run_all()
	quit()


static func run_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_save(_make_chip_idle(), "chip_idle")
	_save(_make_chip_walk(0), "chip_walk1")
	_save(_make_chip_walk(1), "chip_walk2")
	_save(_make_chip_drill(), "chip_drill")

	_save(_make_dirt_block(), "dirt_block")
	_save(_make_breakable_dirt(), "breakable_dirt")
	_save(_make_placed_block(), "placed_block")

	_save(_make_crystal(16), "crystal_small")
	_save(_make_crystal(32), "crystal_mega")

	_save(_make_background_sky(), "background_sky")
	_save(_make_cloud(32, 16), "cloud_1")
	_save(_make_cloud(48, 24), "cloud_2")

	_save(_make_meter_frame(), "ui_meter_frame")
	_save(_make_meter_fill(), "ui_meter_fill")

	_save(_make_joystick_base(), "joystick_base")
	_save(_make_joystick_thumb(), "joystick_thumb")
	_save(_make_button_base(), "button_base")

	_save(_make_icon_jump(), "icon_jump")
	_save(_make_icon_drill(), "icon_drill")
	_save(_make_icon_block(), "icon_block")
	_save(_make_icon_arrow_hint(), "icon_arrow_hint")

	_save(_make_mission_scene(), "mission_scene")

	print("ProceduralArt: all textures generated in ", OUT_DIR)


static func _save(img: Image, name: String) -> void:
	var path := OUT_DIR + name + ".png"
	var err := img.save_png(path)
	if err != OK:
		push_error("ProceduralArt: failed to save %s (err %d)" % [path, err])


static func _new_image(w: int, h: int) -> Image:
	var img := Image.create(w * SCALE, h * SCALE, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	return img


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	x *= SCALE
	y *= SCALE
	w *= SCALE
	h *= SCALE
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, color)


static func _fill_circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	r *= SCALE
	var minx := int(max(0, cx - r))
	var maxx := int(min(img.get_width() - 1, cx + r))
	var miny := int(max(0, cy - r))
	var maxy := int(min(img.get_height() - 1, cy + r))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx := px + 0.5 - cx
			var dy := py + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(px, py, color)


static func _stroke_circle(img: Image, cx: float, cy: float, r: float, thickness: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	r *= SCALE
	thickness *= SCALE
	var minx := int(max(0, cx - r - 1))
	var maxx := int(min(img.get_width() - 1, cx + r + 1))
	var miny := int(max(0, cy - r - 1))
	var maxy := int(min(img.get_height() - 1, cy + r + 1))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx := px + 0.5 - cx
			var dy := py + 0.5 - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= r and dist >= r - thickness:
				img.set_pixel(px, py, color)


static func _fill_diamond(img: Image, cx: float, cy: float, w: float, h: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	w *= SCALE
	h *= SCALE
	var minx := int(max(0, cx - w / 2.0))
	var maxx := int(min(img.get_width() - 1, cx + w / 2.0))
	var miny := int(max(0, cy - h / 2.0))
	var maxy := int(min(img.get_height() - 1, cy + h / 2.0))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx: float = absf(px + 0.5 - cx) / (w / 2.0)
			var dy: float = absf(py + 0.5 - cy) / (h / 2.0)
			if dx + dy <= 1.0:
				img.set_pixel(px, py, color)


static func _fill_triangle_up(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	x *= SCALE
	y *= SCALE
	w *= SCALE
	h *= SCALE
	for py in range(h):
		var t := float(py) / float(h - 1) if h > 1 else 0.0
		var half_w := (t * w) / 2.0
		var cx := x + w / 2.0
		var minx := int(round(cx - half_w))
		var maxx := int(round(cx + half_w))
		for px in range(minx, maxx + 1):
			if px >= 0 and (y + py) >= 0 and px < img.get_width() and (y + py) < img.get_height():
				img.set_pixel(px, y + py, color)


# ---------------------------------------------------------------------------
# Chip the robot (24x24)
# ---------------------------------------------------------------------------

static func _make_chip_idle() -> Image:
	var img := _new_image(24, 24)
	_draw_chip_body(img, 0)
	return img


static func _make_chip_walk(frame: int) -> Image:
	var img := _new_image(24, 24)
	_draw_chip_body(img, 0)
	# Leg shift: draw two small feet, offset per frame.
	var leg_color := DARK_ORANGE
	if frame == 0:
		_fill_rect(img, 5, 20, 4, 3, leg_color)
		_fill_rect(img, 15, 21, 4, 2, leg_color)
	else:
		_fill_rect(img, 5, 21, 4, 2, leg_color)
		_fill_rect(img, 15, 20, 4, 3, leg_color)
	return img


static func _make_chip_drill() -> Image:
	var img := _new_image(24, 24)
	_draw_chip_body(img, -2)
	# Extended drill arm, angled forward/down.
	_fill_rect(img, 16, 12, 7, 4, ROBOT_GREY)
	_fill_rect(img, 21, 13, 3, 2, LIGHT_ORANGE)
	_fill_rect(img, 5, 20, 4, 3, DARK_ORANGE)
	_fill_rect(img, 15, 20, 4, 3, DARK_ORANGE)
	return img


static func _draw_chip_body(img: Image, tilt_x: int) -> void:
	# Body block
	_fill_rect(img, 4 + tilt_x, 6, 16, 14, HERO_ORANGE)
	_fill_rect(img, 4 + tilt_x, 6, 16, 3, LIGHT_ORANGE)
	# Head/dome
	_fill_rect(img, 6 + tilt_x, 2, 12, 5, LIGHT_ORANGE)
	# Eyes (white squares)
	_fill_rect(img, 8 + tilt_x, 4, 3, 3, CLOUD_WHITE)
	_fill_rect(img, 13 + tilt_x, 4, 3, 3, CLOUD_WHITE)
	_fill_rect(img, 9 + tilt_x, 5, 1, 1, VOID_BLACK)
	_fill_rect(img, 14 + tilt_x, 5, 1, 1, VOID_BLACK)
	# Chest plate detail
	_fill_rect(img, 9 + tilt_x, 12, 6, 4, DARK_ORANGE)
	# Grey drill arm (idle, at side)
	_fill_rect(img, 18 + tilt_x, 10, 4, 8, ROBOT_GREY)
	_fill_rect(img, 21 + tilt_x, 11, 2, 2, LIGHT_ORANGE)
	# Left arm
	_fill_rect(img, 2 + tilt_x, 10, 3, 7, ROBOT_GREY)
	# Feet baseline
	_fill_rect(img, 5 + tilt_x, 20, 4, 3, DARK_ORANGE)
	_fill_rect(img, 15 + tilt_x, 20, 4, 3, DARK_ORANGE)


# ---------------------------------------------------------------------------
# Tiles (16x16)
# ---------------------------------------------------------------------------

static func _make_dirt_block() -> Image:
	var img := _new_image(16, 16)
	_fill_rect(img, 0, 0, 16, 16, DIRT_BROWN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1001
	for i in range(18):
		var x := rng.randi_range(0, 15)
		var y := rng.randi_range(0, 15)
		_fill_rect(img, x, y, 1, 1, DARK_ORANGE if i % 3 == 0 else DIRT_DARK)
	return img


static func _make_breakable_dirt() -> Image:
	var img := _make_dirt_block()
	# Crack pattern: jagged diagonal lines.
	var crack_pts := [
		Vector2i(2, 2), Vector2i(4, 4), Vector2i(3, 6), Vector2i(5, 8),
		Vector2i(9, 3), Vector2i(10, 5), Vector2i(9, 7), Vector2i(11, 9),
		Vector2i(6, 10), Vector2i(7, 12), Vector2i(6, 14),
	]
	for p in crack_pts:
		_fill_rect(img, p.x, p.y, 1, 1, VOID_BLACK)
	return img


static func _make_placed_block() -> Image:
	var img := _new_image(16, 16)
	_fill_rect(img, 0, 0, 16, 16, ROBOT_GREY)
	_fill_rect(img, 1, 1, 14, 14, ROBOT_GREY)
	# Lego-like studs with orange highlight
	_fill_circle(img, 4, 4, 2, LIGHT_ORANGE)
	_fill_circle(img, 12, 4, 2, LIGHT_ORANGE)
	_fill_circle(img, 4, 12, 2, LIGHT_ORANGE)
	_fill_circle(img, 12, 12, 2, LIGHT_ORANGE)
	# Border shading
	_fill_rect(img, 0, 0, 16, 1, CLOUD_WHITE.lerp(ROBOT_GREY, 0.5))
	_fill_rect(img, 0, 15, 16, 1, VOID_BLACK)
	_fill_rect(img, 0, 0, 1, 16, CLOUD_WHITE.lerp(ROBOT_GREY, 0.5))
	_fill_rect(img, 15, 0, 1, 16, VOID_BLACK)
	return img


# ---------------------------------------------------------------------------
# Crystals
# ---------------------------------------------------------------------------

static func _make_crystal(size: int) -> Image:
	var img := _new_image(size, size)
	var c := size / 2.0
	_fill_diamond(img, c, c, size * 0.75, size * 0.9, HERO_ORANGE)
	_fill_diamond(img, c, c - size * 0.05, size * 0.4, size * 0.5, LIGHT_ORANGE)
	# Crisp dark outline band. Works directly in physical pixels (unlike
	# the helpers above) since it needs sub-logical-pixel precision for a
	# clean band at any SCALE; lx/ly convert back to the same logical
	# space "c" and the diamond calls above are already expressed in.
	for y in range(size * SCALE):
		for x in range(size * SCALE):
			var lx: float = (x + 0.5) / SCALE
			var ly: float = (y + 0.5) / SCALE
			var dx: float = absf(lx - c) / (size * 0.375)
			var dy: float = absf(ly - c) / (size * 0.45)
			var d: float = dx + dy
			if d <= 1.0 and d > 0.85:
				img.set_pixel(x, y, DARK_ORANGE)
	return img


# ---------------------------------------------------------------------------
# Background / environment
# ---------------------------------------------------------------------------

static func _make_background_sky() -> Image:
	var img := _new_image(480, 270)
	var h := img.get_height()
	var w := img.get_width()
	for y in range(h):
		var t := float(y) / float(h - 1)
		var col := SKY_CYAN.lerp(LIGHT_ORANGE, t)
		for x in range(w):
			img.set_pixel(x, y, col)
	return img


static func _make_cloud(w: int, h: int) -> Image:
	var img := _new_image(w, h)
	var c := Vector2(w / 2.0, h * 0.6)
	_fill_circle(img, c.x - w * 0.25, c.y, h * 0.4, CLOUD_WHITE)
	_fill_circle(img, c.x, c.y - h * 0.15, h * 0.5, CLOUD_WHITE)
	_fill_circle(img, c.x + w * 0.25, c.y, h * 0.4, CLOUD_WHITE)
	_fill_rect(img, int(w * 0.15), int(c.y), int(w * 0.7), int(h * 0.35), CLOUD_WHITE)
	return img


static func _draw_line(img: Image, x0: float, y0: float, x1: float, y1: float, thickness: float, color: Color) -> void:
	x0 *= SCALE
	y0 *= SCALE
	x1 *= SCALE
	y1 *= SCALE
	thickness *= SCALE
	var dist := Vector2(x0, y0).distance_to(Vector2(x1, y1))
	var steps := int(maxi(1, ceili(dist)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := lerpf(x0, x1, t)
		var py := lerpf(y0, y1, t)
		var r := thickness / 2.0
		for oy in range(-ceili(r), ceili(r) + 1):
			for ox in range(-ceili(r), ceili(r) + 1):
				if Vector2(ox, oy).length() <= r:
					var ix := int(px) + ox
					var iy := int(py) + oy
					if ix >= 0 and iy >= 0 and ix < img.get_width() and iy < img.get_height():
						img.set_pixel(ix, iy, color)


## Fills solid below a jagged ridge-line defined by (x,height) points, down
## to the bottom of the image - used for the mission-scene mountain range.
static func _fill_ridge(img: Image, points: PackedVector2Array, color: Color) -> void:
	# `points` are in the same logical space as everything else this
	# script draws in; convert to/from physical pixels internally so
	# callers don't need to think about SCALE.
	var w := img.get_width()
	var h := img.get_height()
	var logical_h := float(h) / SCALE
	for x in range(w):
		var lx: float = float(x) / SCALE
		var ridge_y := logical_h
		for i in range(points.size() - 1):
			var ax: float = points[i].x
			var bx: float = points[i + 1].x
			if lx >= ax and lx <= bx:
				var t := 0.0 if bx == ax else (lx - ax) / (bx - ax)
				ridge_y = lerpf(points[i].y, points[i + 1].y, t)
				break
		for y in range(int(ridge_y * SCALE), h):
			img.set_pixel(x, y, color)


# ---------------------------------------------------------------------------
# Mission File reveal scene: chocolate mountains + a winding roller coaster
# ---------------------------------------------------------------------------

static func _make_mission_scene() -> Image:
	var img := _new_image(480, 270)
	var scene_h := img.get_height()
	var scene_w := img.get_width()

	# Warm dusk sky gradient - distinct from the daytime overworld sky, to
	# make this reveal feel like a different, special moment.
	for y in range(scene_h):
		var t: float = float(y) / float(scene_h - 1)
		var col: Color = LIGHT_ORANGE.lerp(Color(0.25, 0.1, 0.08), t)
		for x in range(scene_w):
			img.set_pixel(x, y, col)

	# Back mountain layer (hazier/lighter, further away).
	var back_color: Color = DIRT_BROWN.lerp(Color(0.25, 0.1, 0.08), 0.35)
	_fill_ridge(img, PackedVector2Array([
		Vector2(0, 170), Vector2(60, 120), Vector2(140, 160),
		Vector2(220, 100), Vector2(300, 150), Vector2(380, 110),
		Vector2(480, 165),
	]), back_color)

	# Front mountain layer (darker, closer).
	_fill_ridge(img, PackedVector2Array([
		Vector2(0, 220), Vector2(90, 175), Vector2(180, 215),
		Vector2(260, 160), Vector2(340, 205), Vector2(420, 170),
		Vector2(480, 210),
	]), DIRT_DARK)

	# Roller coaster track winding across the front peaks - a light,
	# hand-drawn-looking zigzag with support struts down to the ground.
	var track: Array[Vector2] = [
		Vector2(20, 200), Vector2(80, 150), Vector2(130, 210),
		Vector2(180, 170), Vector2(230, 140), Vector2(280, 195),
		Vector2(330, 155), Vector2(390, 185), Vector2(450, 145),
	]
	for i in range(track.size() - 1):
		_draw_line(img, track[i].x, track[i].y, track[i + 1].x, track[i + 1].y, 2.0, LIGHT_ORANGE)
	for p in track:
		if p.y < 250:
			_draw_line(img, p.x, p.y, p.x, 250, 1.0, ROBOT_GREY.lerp(VOID_BLACK, 0.3))

	# A tiny coaster cart riding the track, for scale and charm.
	var cart_pt: Vector2 = track[4]
	_fill_rect(img, int(cart_pt.x - 4), int(cart_pt.y - 5), 8, 5, HERO_ORANGE)
	_fill_rect(img, int(cart_pt.x - 3), int(cart_pt.y - 7), 3, 3, LIGHT_ORANGE)

	return img


# ---------------------------------------------------------------------------
# UI meters
# ---------------------------------------------------------------------------

static func _make_meter_frame() -> Image:
	var img := _new_image(128, 16)
	_fill_rect(img, 0, 0, 128, 16, ROBOT_GREY)
	_fill_rect(img, 2, 2, 124, 12, VOID_BLACK)
	return img


static func _make_meter_fill() -> Image:
	var img := _new_image(124, 12)
	_fill_rect(img, 0, 0, 124, 12, HERO_ORANGE)
	_fill_rect(img, 0, 0, 124, 3, LIGHT_ORANGE)
	return img


# ---------------------------------------------------------------------------
# Touch controls
# ---------------------------------------------------------------------------

static func _make_joystick_base() -> Image:
	var img := _new_image(120, 120)
	var c := 60.0
	var col := ROBOT_GREY
	col.a = 0.5
	_fill_circle(img, c, c, 58, col)
	var border := CLOUD_WHITE
	border.a = 0.6
	_stroke_circle(img, c, c, 58, 3, border)
	return img


static func _make_joystick_thumb() -> Image:
	var img := _new_image(60, 60)
	var c := 30.0
	_fill_circle(img, c, c, 28, HERO_ORANGE)
	_stroke_circle(img, c, c, 20, 3, CLOUD_WHITE)
	return img


static func _make_button_base() -> Image:
	var img := _new_image(100, 100)
	var c := 50.0
	var fill := DARK_ORANGE
	fill.a = 0.75
	_fill_circle(img, c, c, 48, fill)
	_stroke_circle(img, c, c, 48, 4, LIGHT_ORANGE)
	return img


# ---------------------------------------------------------------------------
# Icons (32x32, except hint 16x16)
# ---------------------------------------------------------------------------

static func _make_icon_jump() -> Image:
	var img := _new_image(32, 32)
	_fill_triangle_up(img, 4, 4, 24, 18, CLOUD_WHITE)
	_fill_rect(img, 13, 22, 6, 6, CLOUD_WHITE)
	return img


static func _make_icon_drill() -> Image:
	var img := _new_image(32, 32)
	# Drill body
	_fill_rect(img, 10, 4, 12, 14, CLOUD_WHITE)
	# Drill bit (triangle pointing down). Drawn directly in physical
	# pixels (like the crystal outline) rather than through _fill_rect,
	# since it needs a smooth per-scanline taper.
	for py in range(14 * SCALE):
		var t := float(py) / float(13 * SCALE)
		var half_w := (1.0 - t) * 6.0 * SCALE
		var cx := 16.0 * SCALE
		var minx := int(round(cx - half_w))
		var maxx := int(round(cx + half_w))
		for px in range(minx, maxx + 1):
			if px >= 0 and px < img.get_width():
				img.set_pixel(px, 18 * SCALE + py, CLOUD_WHITE)
	return img


static func _make_icon_block() -> Image:
	var img := _new_image(32, 32)
	_fill_rect(img, 4, 10, 24, 16, CLOUD_WHITE)
	_fill_rect(img, 4, 10, 24, 2, CLOUD_WHITE)
	_fill_circle(img, 10, 7, 3, CLOUD_WHITE)
	_fill_circle(img, 22, 7, 3, CLOUD_WHITE)
	return img


static func _make_icon_arrow_hint() -> Image:
	var img := _new_image(16, 16)
	_fill_triangle_up(img, 2, 1, 12, 9, HERO_ORANGE)
	_fill_rect(img, 6, 10, 4, 5, HERO_ORANGE)
	return img
