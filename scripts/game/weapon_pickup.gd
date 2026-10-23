class_name WeaponPickup
extends Node2D
## A weapon lying in the arena. Drops from the sky (or from a KO'd fighter),
## lands on the floor or a platform, and is grabbed by walking over it.

const GRAVITY := 1400.0
const LIFETIME := 22.0
const RAY_MASK := 1 | 4

var weapon: WeaponData
var velocity := Vector2.ZERO
var grounded := false
var _age := 0.0


func _ready() -> void:
	add_to_group(&"pickups")
	z_index = 4


func grab_rect() -> Rect2:
	return Rect2(global_position + Vector2(-30, -80), Vector2(60, 84))


func _physics_process(delta: float) -> void:
	_age += delta
	if not grounded:
		velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
		var to := global_position + velocity * delta
		var query := PhysicsRayQueryParameters2D.create(global_position, to, RAY_MASK)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and velocity.y > 0.0:
			global_position = hit["position"]
			grounded = true
			CombatBus.fx.emit(&"dust", global_position, {})
		else:
			global_position = to
	if _age > LIFETIME:
		modulate.a = maxf(0.0, modulate.a - delta * 2.0)
		if modulate.a <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, -34.0 + sin(_age * 3.0) * 5.0)
	var pulse := 0.5 + 0.5 * sin(_age * 5.0)
	draw_circle(bob, 30.0, Color(weapon.color, 0.08 + 0.08 * pulse))
	draw_arc(bob, 30.0, 0.0, TAU, 32, Color(weapon.color, 0.35 + 0.3 * pulse), 2.0)
	var dir := Vector2.from_angle(-PI * 0.3 + sin(_age * 1.5) * 0.15)
	var half := minf(weapon.length, 50.0) * 0.5
	StickRig.draw_weapon_shape(self, weapon, bob - dir * half, bob + dir * half)
	if grounded:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-80, -76), weapon.display_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 160, 14, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-80, -76), weapon.display_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(weapon.color, 0.9))
