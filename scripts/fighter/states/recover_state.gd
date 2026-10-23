extends FighterState
## Generic lockout: landing lag, getting up, victory pose.
## msg: frames (int), pose (StringName), invulnerable (bool)

var _total := 10
var _invulnerable := false


func enter(msg: Dictionary) -> void:
	_total = msg.get("frames", 10)
	_invulnerable = msg.get("invulnerable", false)
	fighter.rig.set_pose(msg.get("pose", &"idle"), 18.0)


func is_invulnerable() -> bool:
	return _invulnerable


func update(delta: float) -> void:
	var f := fighter
	if f.is_on_floor():
		f.velocity.x = move_toward(f.velocity.x, 0.0, Fighter.GROUND_FRICTION * delta)
	f.apply_gravity(delta, 1.0, false)
	f.move_and_slide()
	if frames >= _total:
		settle()
