class_name Arena
extends Node2D
## "Neon Rooftop": a walled rooftop with three one-way platforms, a parallax
## city skyline and rain. Layout lives in plain data (platforms, spawns,
## bounds), so new arenas are new data plus their own backdrop drawing.
##
## Collision layers: 1 = solid world, 2 = fighters, 3 = one-way platforms.

const HALF_WIDTH := 1000.0
const FLOOR_COLOR := Color(0.06, 0.06, 0.1)
const NEON_A := Color(0.35, 0.8, 1.0)
const NEON_B := Color(1.0, 0.3, 0.55)

var display_name := "Neon Rooftop"
var platforms: Array[Rect2] = [Rect2(-580, -190, 290, 18), Rect2(290, -190, 290, 18), Rect2(-150, -350, 300, 18)]
var spawn_points: Array[Vector2] = [Vector2(-260, 0), Vector2(260, 0)]
var camera: Camera2D

var _layers: Array[Skyline] = []
var _rain: CPUParticles2D
var _time := 0.0


func camera_bounds() -> Rect2:
	return Rect2(-HALF_WIDTH - 60.0, -1150.0, HALF_WIDTH * 2.0 + 120.0, 1320.0)


func _ready() -> void:
	_build_backdrop()
	_build_collision()
	_build_rain()


func _process(delta: float) -> void:
	_time += delta
	if camera:
		var c := camera.get_screen_center_position()
		for layer in _layers:
			layer.position = Vector2(c.x * (1.0 - layer.factor), c.y * (1.0 - layer.factor))
		_rain.position = c + Vector2(0, -760)
	queue_redraw()


func _draw() -> void:
	# Rooftop slab and the walls of the neighbouring towers.
	draw_rect(Rect2(-HALF_WIDTH - 1400.0, 0.0, HALF_WIDTH * 2.0 + 2800.0, 900.0), FLOOR_COLOR)
	for side in [-1.0, 1.0]:
		var x: float = HALF_WIDTH if side > 0.0 else -HALF_WIDTH - 900.0
		draw_rect(Rect2(x, -2200.0, 900.0, 2300.0), Color(0.045, 0.04, 0.075))
		var edge: float = HALF_WIDTH * side
		draw_line(Vector2(edge, -2200.0), Vector2(edge, 0.0), Color(NEON_B, 0.7), 3.0)
		for i in 9:
			var y := -120.0 - i * 120.0
			var lit := fmod(i * 7.3 + side * 3.1, 3.0) > 1.2
			draw_rect(Rect2(edge + side * 40.0 - (0.0 if side > 0.0 else 50.0), y, 50.0, 70.0),
				Color(1.0, 0.8, 0.45, 0.35) if lit else Color(0.12, 0.12, 0.2))
	# Glowing floor edge with a slow pulse.
	var pulse := 0.75 + 0.25 * sin(_time * 2.0)
	draw_line(Vector2(-HALF_WIDTH, 0.0), Vector2(HALF_WIDTH, 0.0), Color(NEON_A, 0.25 * pulse), 12.0)
	draw_line(Vector2(-HALF_WIDTH, 0.0), Vector2(HALF_WIDTH, 0.0), Color(NEON_A, 0.95), 3.0)
	for i in 21:
		var x := -HALF_WIDTH + i * 100.0
		draw_line(Vector2(x, 4.0), Vector2(x - 40.0, 60.0), Color(1, 1, 1, 0.04), 2.0)
	# Rooftop props: vents and an antenna for silhouette interest.
	draw_rect(Rect2(-860.0, -46.0, 90.0, 46.0), Color(0.1, 0.1, 0.16))
	draw_rect(Rect2(-850.0, -58.0, 70.0, 12.0), Color(0.13, 0.13, 0.2))
	draw_rect(Rect2(760.0, -30.0, 120.0, 30.0), Color(0.1, 0.1, 0.16))
	draw_line(Vector2(820.0, -30.0), Vector2(820.0, -170.0), Color(0.16, 0.16, 0.24), 4.0)
	draw_circle(Vector2(820.0, -172.0), 4.0, Color(1.0, 0.2, 0.25, 0.5 + 0.5 * sin(_time * 4.0)))
	# Platforms.
	for p in platforms:
		draw_rect(p, Color(0.1, 0.09, 0.17))
		draw_line(p.position, Vector2(p.end.x, p.position.y), Color(NEON_B, 0.3 * pulse), 10.0)
		draw_line(p.position, Vector2(p.end.x, p.position.y), NEON_B, 3.0)


func _build_collision() -> void:
	_static_box(Rect2(-HALF_WIDTH - 600.0, 0.0, HALF_WIDTH * 2.0 + 1200.0, 400.0), 1, false)
	_static_box(Rect2(-HALF_WIDTH - 300.0, -2400.0, 300.0, 2800.0), 1, false)
	_static_box(Rect2(HALF_WIDTH, -2400.0, 300.0, 2800.0), 1, false)
	_static_box(Rect2(-HALF_WIDTH - 300.0, -2700.0, HALF_WIDTH * 2.0 + 600.0, 300.0), 1, false)
	for p in platforms:
		_static_box(p, Fighter.PLATFORM_LAYER, true)


func _static_box(rect: Rect2, layer: int, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(layer, true)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


func _build_backdrop() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.09, 0.04, 0.2))
	gradient.set_color(1, Color(0.5, 0.12, 0.32))
	gradient.add_point(0.65, Color(0.2, 0.06, 0.28))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	sky.texture = tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky_layer.add_child(sky)

	var far := Skyline.new()
	far.factor = 0.15
	far.seed_value = 7
	far.base_height = 330.0
	far.color = Color(0.13, 0.06, 0.22)
	far.window_color = Color(0.9, 0.5, 0.9, 0.18)
	far.with_moon = true
	var near := Skyline.new()
	near.factor = 0.4
	near.seed_value = 21
	near.base_height = 170.0
	near.color = Color(0.07, 0.04, 0.12)
	near.window_color = Color(0.5, 0.85, 1.0, 0.35)
	for layer in [far, near]:
		layer.z_index = -20 if layer == far else -10
		add_child(layer)
		_layers.append(layer)


func _build_rain() -> void:
	_rain = CPUParticles2D.new()
	var img := Image.create(2, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_rain.texture = ImageTexture.create_from_image(img)
	_rain.amount = 260
	_rain.lifetime = 1.3
	_rain.preprocess = 1.3
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(1500, 20)
	_rain.direction = Vector2(0.12, 1.0)
	_rain.spread = 1.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 1100.0
	_rain.initial_velocity_max = 1300.0
	_rain.color = Color(0.7, 0.8, 1.0, 0.22)
	_rain.local_coords = false
	_rain.z_index = 15
	add_child(_rain)


## One parallax layer of procedurally generated tower silhouettes.
class Skyline extends Node2D:
	var factor := 0.5
	var seed_value := 1
	var base_height := 300.0
	var color := Color.BLACK
	var window_color := Color.WHITE
	var with_moon := false
	var _towers: Array[Rect2] = []
	var _windows: Array[Rect2] = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var x := -2800.0
		while x < 2800.0:
			var w := rng.randf_range(90.0, 230.0)
			var h := rng.randf_range(base_height * 0.5, base_height * 1.6)
			_towers.append(Rect2(x, -h, w, h + 900.0))
			var wy := -h + 24.0
			while wy < -20.0:
				var wx := x + 14.0
				while wx < x + w - 22.0:
					if rng.randf() < 0.18:
						_windows.append(Rect2(wx, wy, 10.0, 14.0))
					wx += 22.0
				wy += 30.0
			x += w + rng.randf_range(4.0, 40.0)

	func _draw() -> void:
		if with_moon:
			draw_circle(Vector2(280, -470), 120.0, Color(1.0, 0.4, 0.55, 0.08))
			draw_circle(Vector2(280, -470), 80.0, Color(1.0, 0.55, 0.65, 0.85))
			draw_circle(Vector2(305, -490), 62.0, Color(1.0, 0.7, 0.75, 0.25))
		for r in _towers:
			draw_rect(r, color)
		for r in _windows:
			draw_rect(r, window_color)
