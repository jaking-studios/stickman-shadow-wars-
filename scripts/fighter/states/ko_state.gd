extends FighterState
## Knocked out: the rig becomes a verlet ragdoll flung by the final blow.


func enter(msg: Dictionary) -> void:
	var f := fighter
	f.velocity = Vector2.ZERO
	f.rig.spin = 0.0
	f.rig.start_ragdoll(msg.get("knockback", Vector2(0, -300)))


func is_invulnerable() -> bool:
	return true


func solid() -> bool:
	return false
