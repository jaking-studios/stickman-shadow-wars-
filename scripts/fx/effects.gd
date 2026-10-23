class_name Effects
extends RefCounted
## Small self-drawing, self-freeing effect nodes. Factory functions keep call
## sites short: Effects.spark(parent, pos, color, size).


static func spark(parent: Node, pos: Vector2, color: Color, size := 1.0) -> void:
	var node := HitSpark.new()
	node.position = pos
	node.color = color
	node.size = size
	parent.add_child(node)


static func dust(parent: Node, pos: Vector2, big := false) -> void:
	var node := Dust.new()
	node.position = pos
	node.big = big
	parent.add_child(node)


static func ring(parent: Node, pos: Vector2, color: Color) -> void:
	var node := Ring.new()
	node.position = pos
	node.color = color
	parent.add_child(node)


static func popup(parent: Node, pos: Vector2, text: String, color: Color, font_size := 34) -> void:
	var node := FloatText.new()
	node.position = pos
	node.text = text
	node.color = color
	node.font_size = font_size
	parent.add_child(node)


## Starburst + shock ring + white core.
class HitSpark extends Node2D:
	const DURATION := 0.24
	var color := Color.WHITE
	var size := 1.0
	var _life := 0.0
	var _rays: Array = []

	func _ready() -> void:
		rotation = randf() * TAU
		for i in 9:
			_rays.append([randf() * TAU, randf_range(0.6, 1.3)])

	func _process(delta: float) -> void:
		_life += delta
		if _life >= DURATION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _life / DURATION
		var r := lerpf(10.0, 52.0, ease(k, 0.35)) * size
		var a := 1.0 - k
		draw_circle(Vector2.ZERO, r * 0.5 * (1.0 - k), Color(1, 1, 1, a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(color, a), 3.0 * size)
		for ray in _rays:
			var d := Vector2.from_angle(ray[0])
			draw_line(d * r * 0.3, d * r * float(ray[1]) * 1.5, Color(color, a), (4.0 * (1.0 - k) + 1.0) * size)


## Puffs that spread sideways along the floor.
class Dust extends Node2D:
	const DURATION := 0.4
	var big := false
	var _life := 0.0
	var _puffs: Array = []

	func _ready() -> void:
		var n := 9 if big else 5
		for i in n:
			var side := -1.0 if i % 2 == 0 else 1.0
			_puffs.append([Vector2(side * randf_range(30.0, 120.0) * (1.6 if big else 1.0), randf_range(-40.0, -10.0)), randf_range(5.0, 11.0)])

	func _process(delta: float) -> void:
		_life += delta
		if _life >= DURATION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _life / DURATION
		for p in _puffs:
			var v: Vector2 = p[0]
			draw_circle(v * ease(k, 0.4) * 0.5, float(p[1]) * (1.0 + k), Color(0.8, 0.8, 0.9, 0.35 * (1.0 - k)))


## Expanding shock ring (parries, slams, wall splats).
class Ring extends Node2D:
	const DURATION := 0.35
	var color := Color.WHITE
	var _life := 0.0

	func _process(delta: float) -> void:
		_life += delta
		if _life >= DURATION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _life / DURATION
		draw_arc(Vector2.ZERO, lerpf(10.0, 85.0, ease(k, 0.3)), 0.0, TAU, 48, Color(color, 1.0 - k), 6.0 * (1.0 - k) + 1.0)


## Floating outlined text ("PARRY!", "COUNTER!").
class FloatText extends Node2D:
	const DURATION := 0.9
	var text := ""
	var color := Color.WHITE
	var font_size := 34
	var _life := 0.0

	func _ready() -> void:
		z_index = 30

	func _process(delta: float) -> void:
		_life += delta
		position.y -= 60.0 * delta
		if _life >= DURATION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var k := _life / DURATION
		var pop := 1.0 + 0.4 * maxf(0.0, 1.0 - _life * 8.0)
		var a := 1.0 if k < 0.6 else (1.0 - k) / 0.4
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * pop)
		draw_string_outline(font, Vector2(-150, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 300, font_size, 8, Color(0, 0, 0, a))
		draw_string(font, Vector2(-150, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 300, font_size, Color(color, a))
