extends Node
## Registers every gameplay action in code, so keyboard, controller and touch
## layouts live in one place (and a rebinding menu can edit them later).
##
## Actions are named "<player>_<action>", e.g. "p1_light". Controller N drives
## player N + 1; the on-screen touch controls drive p1.

const ACTIONS := ["left", "right", "up", "down", "jump", "light", "heavy", "block", "dodge"]

const KEYBOARD := {
	"p1": {
		"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"jump": [KEY_W], "light": [KEY_J], "heavy": [KEY_K], "block": [KEY_L], "dodge": [KEY_SPACE],
	},
	"p2": {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": [KEY_UP], "light": [KEY_KP_1], "heavy": [KEY_KP_2], "block": [KEY_KP_3], "dodge": [KEY_KP_0],
	},
}

const PAD_BUTTONS := {
	"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
	"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_A], "light": [JOY_BUTTON_X], "heavy": [JOY_BUTTON_Y],
	"block": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER], "dodge": [JOY_BUTTON_B],
}

const PAD_AXES := {
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
	"block": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


func _ready() -> void:
	for i in 2:
		var prefix := "p%d" % (i + 1)
		var keys: Dictionary = KEYBOARD[prefix]
		for action in ACTIONS:
			var action_name: String = prefix + "_" + action
			if not InputMap.has_action(action_name):
				InputMap.add_action(action_name, 0.45)
			for key in keys.get(action, []):
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action_name, ev)
			for button in PAD_BUTTONS.get(action, []):
				var ev := InputEventJoypadButton.new()
				ev.device = i
				ev.button_index = button
				InputMap.action_add_event(action_name, ev)
			if PAD_AXES.has(action):
				var ev := InputEventJoypadMotion.new()
				ev.device = i
				ev.axis = PAD_AXES[action][0]
				ev.axis_value = PAD_AXES[action][1]
				InputMap.action_add_event(action_name, ev)

	if not InputMap.has_action("debug_hitboxes"):
		InputMap.add_action("debug_hitboxes")
		var f1 := InputEventKey.new()
		f1.physical_keycode = KEY_F1
		InputMap.action_add_event("debug_hitboxes", f1)


## True on phones/tablets and touch-only devices, where the virtual pad is shown.
func wants_touch_controls() -> bool:
	return "--touch" in OS.get_cmdline_user_args() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
		or (DisplayServer.is_touchscreen_available() and Input.get_connected_joypads().is_empty() and OS.has_feature("web"))
