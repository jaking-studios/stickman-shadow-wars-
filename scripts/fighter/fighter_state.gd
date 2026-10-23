class_name FighterState
extends RefCounted
## Base class for fighter states. `frames` counts physics frames since enter().

var fighter: Fighter
var name: StringName
var frames := 0


func enter(_msg: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


## True while attacks pass straight through (dodge i-frames, knockdown, KO).
func is_invulnerable() -> bool:
	return false


## False when the fighter should not push other fighters apart (rolling through).
func solid() -> bool:
	return true


func change(to: StringName, msg := {}) -> void:
	fighter.states.change(to, msg)


func settle() -> void:
	change(&"ground" if fighter.is_on_floor() else &"air")
