class_name LevelData
extends RefCounted

## Static level definitions. Tile legend:
##   '#' = wall (solid, undiggable)
##   '.' = empty space
##   'd' = breakable dirt (walkable; drills away from below)
##   '*' = small crystal (16x16)
##   'C' = Chip start position
##   '^' = exit gate (16x32, occupies two stacked rows at the same column)
##   'B' = block pickup station (grants +3 blocks on touch)
##   'M' = mega crystal (32x32, level 3 only)

const TILE_SIZE := 64

const LEVEL_1 := {
	"name": "Sunny Surface",
	"dark": false,
	"story": "Chip's scanners just found crystal energy nearby!\nDig through the surface and collect every crystal.",
	"rows": [
		"........................",
		"........................",
		".................*......",
		"................####..^.",
		".C.*............####..^.",
		"#########ddd############",
		"..........*.............",
		"########################",
	],
}

const LEVEL_2 := {
	"name": "Block Bridge",
	"dark": false,
	"story": "The crystal trail keeps going, but a rocky gap\nblocks the way. Build a bridge with blocks to cross!",
	"rows": [
		"..............................",
		"..............................",
		"..............................",
		"...........................^..",
		".C.*......B.........*...*..^..",
		"##############...#############",
		"..............................",
		"..............................",
		"##############...#############",
	],
}

const LEVEL_3 := {
	"name": "Chocolate Caverns",
	"dark": true,
	"story": "The trail drops into a dark cave. Somewhere down\nhere is the biggest crystal Chip has ever seen...",
	"rows": [
		"############################",
		"............................",
		"............................",
		"...........................^",
		".........................M.^",
		"....................*...####",
		"...............*...###......",
		"..............###...........",
		"..C.*....###................",
		".######.....................",
		"............................",
		"............................",
	],
}

const LEVELS: Array = [LEVEL_1, LEVEL_2, LEVEL_3]


static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


static func get_level_count() -> int:
	return LEVELS.size()


static func get_width(level: Dictionary) -> int:
	var rows: Array = level["rows"]
	return (rows[0] as String).length()


static func get_height(level: Dictionary) -> int:
	var rows: Array = level["rows"]
	return rows.size()
