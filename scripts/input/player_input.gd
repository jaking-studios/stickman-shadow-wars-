class_name PlayerInput
extends FighterInput
## Reads the InputMap actions for one local player ("p1_*" or "p2_*"). Touch
## controls press the same actions, so mobile needs nothing special here.

const PRESS_ACTIONS: Array[StringName] = [&"jump", &"light", &"heavy", &"dodge"]

var prefix := "p1_"


func _init(player := "p1") -> void:
	prefix = player + "_"


func poll(_fighter: Fighter) -> void:
	move_x = Input.get_axis(prefix + "left", prefix + "right")
	up = Input.is_action_pressed(prefix + "up")
	down = Input.is_action_pressed(prefix + "down")
	block = Input.is_action_pressed(prefix + "block")
	for action in PRESS_ACTIONS:
		if Input.is_action_just_pressed(prefix + String(action)):
			press(action)
