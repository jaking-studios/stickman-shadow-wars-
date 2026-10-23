class_name StickRig
extends Node2D
## Procedural stick-figure body. A pose is a set of joint angles that the rig
## blends toward every frame, so a new move only needs a pose entry, not drawn
## frames. On KO the same skeleton becomes a verlet ragdoll that collides with
## the arena. The rig knows nothing about fighters, so menus and the future
## character creator can use it directly.
##
## Angle conventions (rig faces right; the parent flips it with scale.x):
##   t       torso lean from vertical, + leans forward
##   limbs   absolute angle from straight down, + swings forward

const TORSO := 32.0
const NECK := 12.0
const HEAD_R := 9.5
const UPPER_ARM := 18.0
const FOREARM := 18.0
const THIGH := 23.0
const SHIN := 24.0
const LIMB_W := 5.0
const STAND_HIP := -46.0
const AIR_HIP := -52.0
const TRAIL_TIME := 0.12
const KEYS: Array[String] = ["t", "uaf", "faf", "uab", "fab", "thf", "shf", "thb", "shb"]

## Missing keys fall back to "idle". "snap": false keeps the hip at "hy"
## instead of planting the lowest foot on the ground.
const POSES := {
	&"idle": {"t": 8, "uaf": 35, "faf": 150, "uab": 15, "fab": 135, "thf": 22, "shf": 2, "thb": -18, "shb": -22},
	&"run": {"t": 16},
	&"jump": {"t": 4, "uaf": 140, "faf": 110, "uab": -40, "fab": -10, "thf": 70, "shf": -10, "thb": -5, "shb": -60, "snap": false, "hy": AIR_HIP},
	&"fall": {"t": 0, "uaf": 105, "faf": 140, "uab": -55, "fab": -20, "thf": 25, "shf": 5, "thb": -15, "shb": -35, "snap": false, "hy": AIR_HIP},
	&"land": {"t": 18, "uaf": 45, "faf": 120, "uab": 25, "fab": 110, "thf": 60, "shf": -20, "thb": -40, "shb": -95},
	&"block": {"t": -4, "uaf": 62, "faf": 172, "uab": 52, "fab": 165, "thf": 28, "shf": 5, "thb": -25, "shb": -32},
	&"roll": {"t": 70, "uaf": 60, "faf": 170, "uab": 60, "fab": 170, "thf": 120, "shf": -30, "thb": 110, "shb": -40, "snap": false, "hy": -30},
	&"hurt": {"t": -26, "uaf": -30, "faf": -70, "uab": -50, "fab": -90, "thf": 15, "shf": -5, "thb": -22, "shb": -22},
	&"parried": {"t": -22, "uaf": -80, "faf": -115, "uab": 120, "fab": 150, "thf": 10, "shf": 0, "thb": -22, "shb": -38},
	&"tumble": {"t": -32, "uaf": 150, "faf": 172, "uab": -140, "fab": -170, "thf": 50, "shf": 20, "thb": -50, "shb": -20, "snap": false, "hy": AIR_HIP},
	&"down": {"t": -88, "uaf": -100, "faf": -125, "uab": -70, "fab": -40, "thf": 82, "shf": 92, "thb": 76, "shb": 96, "snap": false, "hy": -6},
	&"victory": {"t": -2, "uaf": 160, "faf": 175, "uab": -160, "fab": -175, "thf": 12, "shf": 0, "thb": -12, "shb": 0},
	# Attacks: *_wind is the anticipation, the bare name is the strike.
	&"jab_wind": {"t": 4, "uaf": 22, "faf": 168, "uab": 15, "fab": 140},
	&"jab": {"t": 18, "uaf": 88, "faf": 90, "uab": 8, "fab": 150, "thf": 30, "shf": 5, "thb": -26, "shb": -20},
	&"cross_wind": {"t": -6, "uaf": 42, "faf": 150, "uab": -22, "fab": 150},
	&"cross": {"t": 26, "uaf": 14, "faf": 150, "uab": 92, "fab": 90, "thf": 32, "shf": 5, "thb": -32, "shb": -14},
	&"kick_wind": {"t": -10, "uaf": 60, "faf": 140, "uab": -30, "fab": 120, "thf": 75, "shf": -40, "thb": -5, "shb": -5},
	&"kick": {"t": -24, "uaf": 62, "faf": 150, "uab": -50, "fab": -30, "thf": 96, "shf": 92, "thb": -8, "shb": -8},
	&"heavy_wind": {"t": -20, "uaf": -72, "faf": -20, "uab": 40, "fab": 140, "thf": 30, "shf": 10, "thb": -30, "shb": -30},
	&"heavy": {"t": 34, "uaf": 96, "faf": 94, "uab": -42, "fab": -10, "thf": 42, "shf": 15, "thb": -42, "shb": -35},
	&"uppercut_wind": {"t": 26, "uaf": 0, "faf": 40, "uab": 40, "fab": 150, "thf": 62, "shf": -12, "thb": -40, "shb": -62},
	&"uppercut": {"t": -8, "uaf": 170, "faf": 178, "uab": -30, "fab": 0, "thf": 22, "shf": 0, "thb": -26, "shb": -30},
	&"dash_wind": {"t": 32, "uaf": -42, "faf": -62, "uab": -52, "fab": -72, "thf": 52, "shf": -30, "thb": -32, "shb": -42},
	&"dash": {"t": 40, "uaf": 82, "faf": 96, "uab": -62, "fab": -82, "thf": 102, "shf": 12, "thb": -52, "shb": -30},
	&"air_kick_wind": {"t": -4, "uaf": 100, "faf": 150, "uab": -40, "fab": -60, "thf": 72, "shf": -30, "thb": -10, "shb": -60, "snap": false, "hy": AIR_HIP},
	&"air_kick": {"t": -22, "uaf": 120, "faf": 122, "uab": -60, "fab": -40, "thf": 96, "shf": 96, "thb": -30, "shb": -90, "snap": false, "hy": AIR_HIP},
	&"air_spin": {"t": -30, "uaf": 140, "faf": 160, "uab": -100, "fab": -130, "thf": 122, "shf": 128, "thb": -20, "shb": -70, "snap": false, "hy": AIR_HIP},
	&"slash_wind": {"t": -14, "uaf": -150, "faf": -175, "uab": 30, "fab": 120, "thf": 30, "shf": 8, "thb": -28, "shb": -30},
	&"slash": {"t": 30, "uaf": 70, "faf": 40, "uab": -30, "fab": 10, "thf": 40, "shf": 12, "thb": -40, "shb": -32},
	&"slam_wind": {"t": -16, "uaf": 175, "faf": 176, "uab": 170, "fab": 175, "thf": 52, "shf": -20, "thb": 10, "shb": -40, "snap": false, "hy": AIR_HIP},
	&"slam": {"t": 36, "uaf": 52, "faf": 22, "uab": 42, "fab": 16, "thf": 10, "shf": 0, "thb": -10, "shb": -5, "snap": false, "hy": AIR_HIP},
}

const SEGMENTS := [
	[&"hip", &"neck"], [&"neck", &"head"],
	[&"neck", &"elbow_f"], [&"elbow_f", &"hand_f"], [&"neck", &"elbow_b"], [&"elbow_b", &"hand_b"],
	[&"hip", &"knee_f"], [&"knee_f", &"foot_f"], [&"hip", &"knee_b"], [&"knee_b", &"foot_b"],
]

# Ragdoll particles and the distance constraints between them.
const RD: Array[StringName] = [&"head", &"neck", &"hip", &"elbow_f", &"hand_f", &"elbow_b", &"hand_b", &"knee_f", &"foot_f", &"knee_b", &"foot_b"]
const RD_LINKS := [
	[0, 1, NECK], [1, 2, TORSO], [1, 3, UPPER_ARM], [3, 4, FOREARM], [1, 5, UPPER_ARM], [5, 6, FOREARM],
	[2, 7, THIGH], [7, 8, SHIN], [2, 9, THIGH], [9, 10, SHIN], [0, 2, TORSO + NECK],
]
const RD_GRAVITY := 1900.0
const RD_MASK := 1 | 4

var color := Color.WHITE
var aura_color := Color(1, 1, 1, 0)
var eye_color := Color(0.04, 0.04, 0.07)
var pose_name: StringName = &""
var blend_speed := 14.0
## Whole-body rotation in radians (rolls, flips).
var spin := 0.0
var locomotion_speed := 0.0
var health_ratio := 1.0
## Set during hitstop: the pose holds and the body shakes.
var frozen := false
var shake := 0.0
var trail_joint: StringName = &""
## Held weapon (drawn in the front hand) or null for fists.
var weapon: WeaponData
var joints := {}
var ragdoll_active := false

var _cur := {}
var _target := {}
var _snap := true
var _hip_target := STAND_HIP
var _hip := STAND_HIP
var _flash := 0.0
var _time := 0.0
var _run_phase := 0.0
var _trail: Array = []
var _rd_pos := PackedVector2Array()
var _rd_prev := PackedVector2Array()
var _rd_safe := PackedVector2Array()
var _rd_last_dt := 0.0
var _shake_offset := Vector2.ZERO


func _ready() -> void:
	set_pose(&"idle")
	_cur = _target.duplicate()
	_hip = _snap_height()
	_solve()


func set_pose(pose: StringName, speed := 14.0) -> void:
	blend_speed = speed
	if pose == pose_name:
		return
	pose_name = pose
	var p: Dictionary = POSES.get(pose, POSES[&"idle"])
	var base: Dictionary = POSES[&"idle"]
	for k in KEYS:
		_target[k] = float(p.get(k, base[k]))
	_snap = p.get("snap", true)
	_hip_target = p.get("hy", STAND_HIP)


func hit_flash() -> void:
	_flash = 0.09
	shake = 4.0
	if not _cur.is_empty():
		_cur["t"] -= 14.0


func _process(delta: float) -> void:
	_update_trail(delta)
	_shake_offset = Vector2.ZERO
	if ragdoll_active:
		queue_redraw()
		return
	if frozen:
		if shake > 0.0:
			_shake_offset = Vector2(randf_range(-shake, shake), 0.0)
		queue_redraw()
		return
	shake = 0.0
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	if pose_name == &"run":
		_animate_run(delta)
	var w := 1.0 - exp(-blend_speed * delta)
	for k in KEYS:
		_cur[k] = lerpf(_cur[k], _target[k], w)
	_hip = lerpf(_hip, _snap_height() if _snap else _hip_target, w)
	_solve()
	queue_redraw()


func _animate_run(delta: float) -> void:
	_run_phase += delta * (5.0 + absf(locomotion_speed) * 0.022)
	var s := sin(_run_phase)
	var c := cos(_run_phase)
	_target["thf"] = s * 42.0
	_target["thb"] = -s * 42.0
	_target["shf"] = s * 42.0 - (25.0 + 45.0 * maxf(0.0, -c))
	_target["shb"] = -s * 42.0 - (25.0 + 45.0 * maxf(0.0, c))
	_target["uaf"] = -s * 45.0 + 15.0
	_target["faf"] = -s * 45.0 + 100.0
	_target["uab"] = s * 45.0 + 15.0
	_target["fab"] = s * 45.0 + 100.0
	blend_speed = 22.0


func _snap_height() -> float:
	var front := THIGH * cos(deg_to_rad(_cur["thf"])) + SHIN * cos(deg_to_rad(_cur["shf"]))
	var back := THIGH * cos(deg_to_rad(_cur["thb"])) + SHIN * cos(deg_to_rad(_cur["shb"]))
	return -maxf(front, back)


func _dir(degrees: float) -> Vector2:
	var r := deg_to_rad(degrees)
	return Vector2(sin(r), cos(r))


func _solve() -> void:
	var bob := sin(_time * 2.6) * 2.0 if pose_name == &"idle" else 0.0
	var lean := deg_to_rad(float(_cur["t"]) + bob + (1.0 - health_ratio) * 12.0)
	var up := Vector2(sin(lean), -cos(lean))
	var hip := Vector2(0.0, _hip)
	var neck := hip + up * TORSO
	var elbow_f := neck + _dir(_cur["uaf"] + bob) * UPPER_ARM
	var elbow_b := neck + _dir(_cur["uab"] - bob) * UPPER_ARM
	var knee_f := hip + _dir(_cur["thf"]) * THIGH
	var knee_b := hip + _dir(_cur["thb"]) * THIGH
	var j := {
		&"hip": hip, &"neck": neck, &"head": neck + up * NECK,
		&"elbow_f": elbow_f, &"hand_f": elbow_f + _dir(_cur["faf"] + bob) * FOREARM,
		&"elbow_b": elbow_b, &"hand_b": elbow_b + _dir(_cur["fab"] - bob) * FOREARM,
		&"knee_f": knee_f, &"foot_f": knee_f + _dir(_cur["shf"]) * SHIN,
		&"knee_b": knee_b, &"foot_b": knee_b + _dir(_cur["shb"]) * SHIN,
	}
	if weapon:
		var hand: Vector2 = j[&"hand_f"]
		var along: Vector2 = (hand - elbow_f).normalized()
		j[&"blade_base"] = hand - along * (14.0 if weapon.style == &"spear" else 6.0)
		j[&"blade_tip"] = hand + along * weapon.length
	if spin != 0.0:
		var pivot := hip + up * (TORSO * 0.3)
		for k in j.keys():
			j[k] = pivot + (j[k] - pivot).rotated(spin)
	joints = j


# --- Drawing -------------------------------------------------------------

func _draw() -> void:
	_draw_trail()
	draw_set_transform(_shake_offset)
	var pts := joints
	if ragdoll_active:
		pts = {}
		for i in RD.size():
			pts[RD[i]] = to_local(_rd_pos[i])
	if pts.is_empty():
		return
	var c := color.lerp(Color.WHITE, clampf(_flash / 0.06, 0.0, 1.0))
	var back := c.darkened(0.35)
	if aura_color.a > 0.0:
		var glow := Color(aura_color, aura_color.a * 0.22)
		for seg in SEGMENTS:
			draw_line(pts[seg[0]], pts[seg[1]], glow, LIMB_W + 8.0)
		draw_circle(pts[&"head"], HEAD_R + 5.0, glow)
	_limb(pts, &"hip", &"knee_b", &"foot_b", back)
	_limb(pts, &"neck", &"elbow_b", &"hand_b", back)
	draw_line(pts[&"hip"], pts[&"neck"], c, LIMB_W + 1.5)
	draw_circle(pts[&"hip"], (LIMB_W + 1.5) * 0.5, c)
	draw_circle(pts[&"neck"], (LIMB_W + 1.5) * 0.5, c)
	_limb(pts, &"hip", &"knee_f", &"foot_f", c)
	if weapon and not ragdoll_active and pts.has(&"blade_tip"):
		draw_weapon_shape(self, weapon, pts[&"blade_base"], pts[&"blade_tip"])
	_limb(pts, &"neck", &"elbow_f", &"hand_f", c)
	var head: Vector2 = pts[&"head"]
	var up: Vector2 = (head - pts[&"neck"]).normalized()
	draw_circle(head, HEAD_R, c)
	draw_circle(head + Vector2(-up.y, up.x) * 4.0 + up * 1.5, 2.2, eye_color)


## Shared with weapon pickups so a weapon looks the same in hand and on the floor.
static func draw_weapon_shape(ci: CanvasItem, w: WeaponData, base: Vector2, tip: Vector2) -> void:
	var along := (tip - base).normalized()
	var side := Vector2(-along.y, along.x)
	var col := w.color
	match w.style:
		&"hammer":
			var neck := tip - along * 6.0
			ci.draw_line(base, neck, Color(0.45, 0.3, 0.2), 4.0)
			var head := PackedVector2Array([neck + side * 13.0 - along * 7.0, neck + side * 13.0 + along * 9.0, neck - side * 13.0 + along * 9.0, neck - side * 13.0 - along * 7.0])
			ci.draw_colored_polygon(head, col)
			ci.draw_polyline(head + PackedVector2Array([head[0]]), col.lightened(0.35), 1.5)
		&"spear":
			ci.draw_line(base, tip - along * 12.0, Color(0.55, 0.38, 0.22), 3.5)
			ci.draw_colored_polygon(PackedVector2Array([tip, tip - along * 14.0 + side * 5.0, tip - along * 14.0 - side * 5.0]), col)
		&"plasma":
			ci.draw_line(base, base + along * 9.0, Color(0.25, 0.25, 0.3), 5.0)
			var start := base + along * 9.0
			ci.draw_line(start, tip, Color(col, 0.25), 13.0)
			ci.draw_line(start, tip, Color(col, 0.6), 7.0)
			ci.draw_line(start, tip, Color(0.92, 1.0, 1.0), 3.0)
			ci.draw_circle(tip, 3.0, Color(0.92, 1.0, 1.0))
		_:
			ci.draw_line(base, base + along * 9.0, Color(0.2, 0.18, 0.22), 5.0)
			ci.draw_line(base + along * 8.0 + side * 6.0, base + along * 8.0 - side * 6.0, Color(0.85, 0.7, 0.3), 3.0)
			ci.draw_line(base + along * 9.0, tip, col, 3.5)
			ci.draw_line(base + along * 9.0 + side * 1.2, tip, Color(1, 1, 1, 0.7), 1.2)


func _limb(pts: Dictionary, a: StringName, b: StringName, tip: StringName, col: Color) -> void:
	draw_line(pts[a], pts[b], col, LIMB_W)
	draw_line(pts[b], pts[tip], col, LIMB_W)
	draw_circle(pts[b], LIMB_W * 0.5, col)
	draw_circle(pts[tip], LIMB_W * 0.65, col)


func _update_trail(delta: float) -> void:
	for item in _trail:
		item[1] += delta
	while not _trail.is_empty() and _trail[0][1] > TRAIL_TIME:
		_trail.pop_front()
	if trail_joint != &"" and joints.has(trail_joint) and not ragdoll_active:
		_trail.append([to_global(joints[trail_joint]), 0.0])


func _draw_trail() -> void:
	if _trail.size() < 2:
		return
	var tint := aura_color if aura_color.a > 0.0 else color
	if weapon:
		tint = weapon.color
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for item in _trail:
		pts.append(to_local(item[0]))
		cols.append(Color(tint, (1.0 - item[1] / TRAIL_TIME) * 0.85))
	draw_polyline_colors(pts, cols, 11.0 if weapon else 8.0, true)


# --- Ragdoll -------------------------------------------------------------

func start_ragdoll(impulse: Vector2) -> void:
	if joints.is_empty():
		_solve()
	ragdoll_active = true
	trail_joint = &""
	_trail.clear()
	var n := RD.size()
	_rd_pos.resize(n)
	_rd_prev.resize(n)
	_rd_safe.resize(n)
	var dt := 1.0 / 60.0
	_rd_last_dt = dt
	for i in n:
		var g := to_global(joints[RD[i]])
		var v := impulse * randf_range(0.8, 1.2) + Vector2(randf_range(-140.0, 140.0), randf_range(-160.0, 40.0))
		if i == 0:
			v *= 1.25
		_rd_pos[i] = g
		_rd_safe[i] = g
		_rd_prev[i] = g - v * dt


func stop_ragdoll() -> void:
	ragdoll_active = false


func ragdoll_center() -> Vector2:
	return _rd_pos[2] if ragdoll_active else global_position


func _physics_process(delta: float) -> void:
	if not ragdoll_active or delta <= 0.0:
		return
	var space := get_world_2d().direct_space_state
	var ratio := delta / _rd_last_dt
	_rd_last_dt = delta
	var g := Vector2(0.0, RD_GRAVITY) * delta * delta
	for i in _rd_pos.size():
		var v := (_rd_pos[i] - _rd_prev[i]) * 0.995 * ratio
		_rd_prev[i] = _rd_pos[i]
		_rd_pos[i] += v + g
	for _iter in 6:
		for link in RD_LINKS:
			var a: int = link[0]
			var b: int = link[1]
			var rest: float = link[2]
			var d := _rd_pos[b] - _rd_pos[a]
			var dist := d.length()
			if dist < 0.001:
				continue
			var corr := d * ((dist - rest) / dist * 0.5)
			_rd_pos[a] += corr
			_rd_pos[b] -= corr
	# Sweep each particle from its last known-free spot so it can't tunnel.
	for i in _rd_pos.size():
		var query := PhysicsRayQueryParameters2D.create(_rd_safe[i], _rd_pos[i], RD_MASK)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			_rd_safe[i] = _rd_pos[i]
			continue
		var normal: Vector2 = hit["normal"]
		var p: Vector2 = hit["position"] + normal * 1.5
		var v := _rd_pos[i] - _rd_prev[i]
		var vn := normal * v.dot(normal)
		_rd_pos[i] = p
		_rd_prev[i] = p - ((v - vn) * 0.7 - vn * 0.25)
		_rd_safe[i] = p
