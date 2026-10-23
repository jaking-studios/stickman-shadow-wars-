class_name FighterInput
extends RefCounted
## Everything a Fighter reads from its controller, sampled once per physics
## frame. Local players, the CPU and (later) network peers are all just
## subclasses that fill these fields, which keeps fighters multiplayer-ready.
##
## Button presses are buffered for a few frames so inputs made slightly early
## (mid-combo, during hitstop) still come out.

const BUFFER_FRAMES := 8

var enabled := true
var move_x := 0.0
var up := false
var down := false
var block := false
var _buffer := {}


## Override: read the device / think, then set fields and call press().
func poll(_fighter: Fighter) -> void:
	pass


func press(action: StringName) -> void:
	_buffer[action] = BUFFER_FRAMES


func peek(action: StringName) -> bool:
	return _buffer.get(action, 0) > 0


func consume(action: StringName) -> bool:
	if peek(action):
		_buffer.erase(action)
		return true
	return false


func age() -> void:
	for action in _buffer.keys():
		_buffer[action] -= 1
		if _buffer[action] <= 0:
			_buffer.erase(action)


func clear() -> void:
	move_x = 0.0
	up = false
	down = false
	block = false
	_buffer.clear()
