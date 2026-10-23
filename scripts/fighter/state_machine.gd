class_name StateMachine
extends RefCounted
## Minimal finite state machine for a Fighter. States are registered by name;
## adding a new behaviour (grab, ability cast, finisher) is one new
## FighterState script plus one entry in Fighter.STATES.

signal changed(from: StringName, to: StringName)

var fighter: Fighter
var states := {}
var current: FighterState
var current_name: StringName = &""


func _init(owner_fighter: Fighter) -> void:
	fighter = owner_fighter


func add(state_name: StringName, state: FighterState) -> void:
	state.fighter = fighter
	state.name = state_name
	states[state_name] = state


func change(state_name: StringName, msg := {}) -> void:
	var previous := current_name
	if current:
		current.exit()
	current = states[state_name]
	current_name = state_name
	current.frames = 0
	current.enter(msg)
	changed.emit(previous, state_name)


func update(delta: float) -> void:
	current.frames += 1
	current.update(delta)
