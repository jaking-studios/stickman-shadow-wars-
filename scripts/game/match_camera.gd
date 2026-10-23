class_name MatchCamera
extends Camera2D
## Frames every fighter, zooming out as they separate. Trauma-based screen
## shake (shake = trauma^2) and a cinematic punch-in for knockouts.

const MIN_ZOOM := 0.7
const MAX_ZOOM := 1.6
const MAX_SHAKE := 26.0

var targets: Array = []
var trauma := 0.0

var _punch := 0.0
var _focus: Node2D


func _ready() -> void:
	ignore_rotation = false


func set_bounds(r: Rect2) -> void:
	limit_left = int(r.position.x)
	limit_top = int(r.position.y)
	limit_right = int(r.end.x)
	limit_bottom = int(r.end.y)


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func punch_in(focus: Node2D) -> void:
	_focus = focus
	_punch = 1.0


func snap() -> void:
	var view := _framing()
	global_position = view[0]
	zoom = Vector2.ONE * float(view[1])


func _process(delta: float) -> void:
	if targets.is_empty():
		return
	var view := _framing()
	var center: Vector2 = view[0]
	var want: float = view[1]
	if _focus and _punch > 0.0:
		center = center.lerp(_focus.focus_point(), 0.65 * _punch)
		want *= 1.0 + 0.45 * _punch
		_punch = maxf(0.0, _punch - delta * 0.5)
	global_position = global_position.lerp(center, 1.0 - exp(-7.0 * delta))
	zoom = zoom.lerp(Vector2.ONE * want, 1.0 - exp(-4.0 * delta))
	trauma = maxf(0.0, trauma - 1.6 * delta)
	var s := trauma * trauma
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * MAX_SHAKE * s
	rotation = randf_range(-1.0, 1.0) * 0.025 * s


## Returns [center, zoom] that fits every target with some breathing room.
func _framing() -> Array:
	var box := Rect2(targets[0].focus_point(), Vector2.ZERO)
	for t in targets:
		box = box.expand(t.focus_point())
	var view := get_viewport_rect().size
	var fit := minf(view.x / (box.size.x + 520.0), view.y / (box.size.y + 380.0))
	var z := clampf(fit, MIN_ZOOM, MAX_ZOOM)
	# Keep the floor in the lower fifth of the screen.
	return [box.get_center() + Vector2(0, 50.0 - 230.0 / z), z]
