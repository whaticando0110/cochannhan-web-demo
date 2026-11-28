extends RefCounted

const JADE = preload("res://assets/gu-review/ngoc-bi-co.png")
const LEAF = preload("res://assets/gu-review/sinh-co-diep.png")
const WHITE_JADE = preload("res://assets/rank2-review/bach-ngoc-co.png")
const MOON_EDGE = preload("res://assets/rank2-review/nguyet-mang-co.png")
const BREW = preload("res://assets/thunder-ford-review/tuu-trung-co.png")
const FOUR_FLAVORS = preload("res://assets/thunder-ford-review/tu-vi-tuu-trung.png")
const STONE_VEIL = preload("res://assets/ambush-veil-review/an-thach-co.png")
const SCALE_VEIL = preload("res://assets/ambush-veil-review/an-lan-co.png")
const FORD = preload("res://assets/thunder-ford-review/wet-stone-tiles.png")
const WATER = preload("res://assets/thunder-ford-review/water-mask-16.png")
const FLOOD = preload("res://assets/thunder-ford-review/water-electric-telegraph.png")
const CANYON = preload("res://assets/ambush-veil-review/ambush-canyon-tiles.png")
const ROCKFALL = preload("res://assets/ambush-veil-review/rockfall-telegraph.png")
const TELEGRAPHS = preload("res://assets/terrain-telegraphs-review/terrain-telegraphs.png")

const ICONS := {
	"jade_skin": preload("res://assets/gu-review/ngoc-bi-co-icon.png"),
	"vital_leaf": preload("res://assets/gu-review/sinh-co-diep-icon.png"),
	"white_jade": preload("res://assets/rank2-review/bach-ngoc-co-icon.png"),
	"moon_edge": preload("res://assets/rank2-review/nguyet-mang-co-icon.png"),
	"brew": preload("res://assets/thunder-ford-review/tuu-trung-co-icon.png"),
	"four_flavors": preload("res://assets/thunder-ford-review/tu-vi-tuu-trung-icon.png"),
	"stone_veil": preload("res://assets/ambush-veil-review/an-thach-co-icon.png"),
	"scale_veil": preload("res://assets/ambush-veil-review/an-lan-co-icon.png"),
}

# Runtime timings come from the review manifests. Cues without a manifest marker use a frame boundary.
const CASTS := {
	"jade_skin": {"texture": JADE, "row": 0, "ms": [80, 80, 90, 90, 85, 85], "cue": 250},
	"white_jade": {"texture": WHITE_JADE, "row": 0, "ms": [75, 80, 90, 95, 100, 100], "cue": 245},
	"white_light": {"texture": WHITE_JADE, "row": 0, "ms": [75, 80, 90, 95, 100, 100], "cue": 245},
	"vital_leaf": {"texture": LEAF, "row": 0, "ms": [75, 80, 85, 95, 95, 90, 80, 80], "cue": 240},
	"brew": {"texture": BREW, "row": 0, "ms": [80, 85, 90, 95, 95, 95], "cue": 255},
	"four_flavors": {"texture": FOUR_FLAVORS, "row": 0, "ms": [80, 85, 90, 95, 95, 95], "cue": 255},
	"stone_veil": {"texture": STONE_VEIL, "row": 0, "ms": [90, 90, 90, 90, 90, 90], "cue": 270},
	"scale_veil": {"texture": SCALE_VEIL, "row": 0, "ms": [120, 160, 180, 180], "cue": 280},
}

const LOOPS := {
	"jade_skin": {"texture": JADE, "row": 1, "ms": [110, 110, 110, 110, 110, 110]},
	"white_jade": {"texture": WHITE_JADE, "row": 1, "ms": [110, 110, 110, 110, 110, 110]},
	"brew": {"texture": BREW, "row": 1, "ms": [100, 100, 100, 100, 100, 100]},
	"stack_one": {"texture": FOUR_FLAVORS, "row": 1, "ms": [110, 110, 110, 110, 110, 110]},
	"stack_two": {"texture": FOUR_FLAVORS, "row": 2, "ms": [100, 100, 100, 100, 100, 100]},
	"stone_veil": {"texture": STONE_VEIL, "row": 1, "ms": [110, 110, 110, 110, 110, 110]},
	"scale_veil": {"texture": SCALE_VEIL, "row": 1, "ms": [100, 100, 100, 100, 100, 100, 100, 100]},
	"moon_mark": {"texture": MOON_EDGE, "row": 4, "ms": [100, 100, 100, 100, 100, 100], "size": 64, "pivot": .5},
}

const CONTACTS := {
	"jade_skin": {"texture": JADE, "row": 2, "ms": [50, 65, 80, 85, 90, 90]},
	"white_jade": {"texture": WHITE_JADE, "row": 2, "ms": [45, 60, 75, 85, 90, 95]},
	"moon_edge": {"texture": MOON_EDGE, "row": 1, "ms": [40, 45, 45, 45, 45, 45, 45, 50], "size": 64},
	"marked_edge": {"texture": MOON_EDGE, "row": 3, "ms": [45, 55, 55, 55, 60, 60, 55, 55], "size": 64},
	"step_reveal": {"texture": STONE_VEIL, "row": 2, "ms": [70, 70, 70, 70, 70, 70]},
	"uncloak": {"texture": SCALE_VEIL, "row": 2, "ms": [90, 110, 140, 180]},
	"lost_target": {"texture": SCALE_VEIL, "row": 3, "ms": [140, 140, 140, 140], "pivot": .5},
}


static func length_ms(clip: Dictionary) -> int:
	var length := 0
	for ms in clip.ms:
		length += int(ms)
	return length


static func frame_region(clip: Dictionary, elapsed: float, loop: bool = false) -> Rect2:
	if loop:
		elapsed = fposmod(elapsed, length_ms(clip))
	var frame := 0
	while frame < clip.ms.size() - 1 and elapsed >= float(clip.ms[frame]):
		elapsed -= float(clip.ms[frame])
		frame += 1
	var cell: float = clip.get("size", 128)
	return Rect2(frame * cell, clip.row * cell, cell, cell)
