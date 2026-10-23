class_name TouchControls
extends Control
## On-screen controls for phones and tablets. A floating joystick on the left
## half of the screen and an arc of action buttons on the right. Everything
## is fed into the normal "p1_*" InputMap actions, so fighters don't know
## whether a finger, a pad or a keyboard is playing.

signal pause_pressed

const STICK_RADIUS := 70.0
const DEAD_ZONE := 0.3
const BUTTONS := [
	# action, label, offset from bottom-right corner, radius, color
	["light", "LIGHT", Vector2(-130, -120), 58.0, Color(0.35, 0.8, 1.0)],
	["heavy", "HEAVY", Vector2(-250, -70), 48.0, Color(1.0, 0.45, 0.35)],
	["jump", "JUMP", Vector2(-110, -250), 48.0, Color(0.5, 1.0, 0.6)],
	["dodge", "DODGE", Vector2(-250, -195), 40.0, Color(0.95, 0.85, 0.4)],
	["block", "BLOCK", Vector2(-365, -80), 40.0, Color(0.75, 0.6, 1.0)],
]
const PAUSE_RECT := Rect2(-30, 86, 60, 44)

var prefix := "p1_"

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _button_touches := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_tree() -> void:
	for action in ["left", "right", "up", "down", "jump", "light", "heavy", "block", "dodge"]:
		Input.action_release(prefix + action)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var pause := Rect2(PAUSE_RECT.position + Vector2(size.x * 0.5, 0), PAUSE_RECT.size)
		if pause.has_point(event.position):
			pause_pressed.emit()
			return
		var hit := _button_at(event.position)
		if hit != "":
			_button_touches[event.index] = hit
			Input.action_press(prefix + hit)
		elif event.position.x < size.x * 0.5 and _stick_touch == -1:
			_stick_touch = event.index
			_stick_origin = event.position
			_stick_pos = event.position
			_apply_stick()
	else:
		if _button_touches.has(event.index):
			Input.action_release(prefix + String(_button_touches[event.index]))
			_button_touches.erase(event.index)
		elif event.index == _stick_touch:
			_stick_touch = -1
			_stick_pos = _stick_origin
			_apply_stick()
	queue_redraw()


func _on_drag(event: InputEventScreenDrag) -> void:
	if event.index != _stick_touch:
		return
	_stick_pos = event.position
	var d := _stick_pos - _stick_origin
	if d.length() > STICK_RADIUS:
		_stick_origin = _stick_pos - d.normalized() * STICK_RADIUS
	_apply_stick()
	queue_redraw()


func _apply_stick() -> void:
	var v := (_stick_pos - _stick_origin) / STICK_RADIUS
	if _stick_touch == -1:
		v = Vector2.ZERO
	_set_axis("right", maxf(0.0, v.x))
	_set_axis("left", maxf(0.0, -v.x))
	_set_axis("down", maxf(0.0, v.y))
	_set_axis("up", maxf(0.0, -v.y))


func _set_axis(action: String, strength: float) -> void:
	if strength > DEAD_ZONE:
		Input.action_press(prefix + action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(prefix + action)


func _button_at(pos: Vector2) -> String:
	for b in BUTTONS:
		var center: Vector2 = size + b[2]
		if pos.distance_to(center) <= float(b[3]) * 1.15:
			return b[0]
	return ""


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Joystick.
	if _stick_touch != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.08))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 3.0)
		draw_circle(_stick_pos, 30.0, Color(1, 1, 1, 0.35))
	else:
		var hint := Vector2(150, size.y - 150)
		draw_arc(hint, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.14), 3.0)
		draw_circle(hint, 26.0, Color(1, 1, 1, 0.12))
	# Buttons.
	var held := _button_touches.values()
	for b in BUTTONS:
		var center: Vector2 = size + b[2]
		var r: float = b[3]
		var col: Color = b[4]
		var down: bool = b[0] in held
		draw_circle(center, r, Color(col, 0.45 if down else 0.18))
		draw_arc(center, r, 0.0, TAU, 40, Color(col, 0.9 if down else 0.55), 3.0)
		draw_string(font, center + Vector2(-r, 6), b[1], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 16, Color(1, 1, 1, 0.85))
	# Pause.
	var pause := Rect2(PAUSE_RECT.position + Vector2(size.x * 0.5, 0), PAUSE_RECT.size)
	draw_rect(pause, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(pause.position + Vector2(20, 11), Vector2(6, 22)), Color(1, 1, 1, 0.7))
	draw_rect(Rect2(pause.position + Vector2(34, 11), Vector2(6, 22)), Color(1, 1, 1, 0.7))
