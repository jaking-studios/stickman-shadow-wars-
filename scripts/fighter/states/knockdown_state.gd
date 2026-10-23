extends FighterState
## Lying on the floor, invincible. Pressing dodge right after landing is a
## tech roll; otherwise the fighter gets up after LIE_FRAMES.

const LIE_FRAMES := 40
const TECH_WINDOW := 12


func enter(_msg: Dictionary) -> void:
	var f := fighter
	f.rig.set_pose(&"down", 22.0)
	f.velocity.y = 0.0
	Sfx.play(&"land", 0.8, -4.0)
	CombatBus.fx.emit(&"dust", f.global_position, {"big": true})


func is_invulnerable() -> bool:
	return true


func solid() -> bool:
	return false


func update(delta: float) -> void:
	var f := fighter
	f.velocity.x = move_toward(f.velocity.x, 0.0, 1800.0 * delta)
	f.apply_gravity(delta, 1.0, false)
	f.move_and_slide()
	if frames <= TECH_WINDOW and f.input.consume(&"dodge"):
		change(&"dodge")
	elif frames >= LIE_FRAMES:
		change(&"recover", {"frames": 14, "pose": &"land", "invulnerable": true})
