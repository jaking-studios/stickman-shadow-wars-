class_name Hud
extends CanvasLayer
## Fighting-game HUD: health bars with a trailing damage chunk, round pips,
## timer, combo counters and the big centre announcer.

const BAR_H := 24.0
const MARGIN := 28.0

var fighters: Array = []
var wins: Array = [0, 0]
var time_left := 99.0
var rounds_to_win := 2
var hint := ""

var _trail_health: Array[float] = [100.0, 100.0]
var _trail_delay: Array[float] = [0.0, 0.0]
var _combo: Array[int] = [0, 0]
var _combo_t: Array[float] = [0.0, 0.0]
var _announce := ""
var _announce_sub := ""
var _announce_t := 0.0
var _announce_len := 1.0
var _canvas: HudCanvas


func _ready() -> void:
	layer = 5
	_canvas = HudCanvas.new()
	_canvas.hud = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)


func announce(text: String, sub := "", duration := 1.4) -> void:
	_announce = text
	_announce_sub = sub
	_announce_t = 0.0
	_announce_len = duration


func show_combo(player: int, count: int) -> void:
	if player < 0 or player > 1:
		return
	_combo[player] = count
	_combo_t[player] = 1.4


func _process(delta: float) -> void:
	# Real time, so the HUD stays responsive during slow motion.
	var dt := delta / maxf(Engine.time_scale, 0.01)
	for i in mini(fighters.size(), 2):
		var f: Fighter = fighters[i]
		if f.health < _trail_health[i]:
			if _trail_delay[i] <= 0.0:
				_trail_health[i] = move_toward(_trail_health[i], f.health, 60.0 * dt)
			else:
				_trail_delay[i] -= dt
		else:
			_trail_health[i] = f.health
			_trail_delay[i] = 0.45
		_combo_t[i] = maxf(0.0, _combo_t[i] - dt)
	_announce_t += dt
	_canvas.queue_redraw()


func draw_hud(c: Control) -> void:
	var font := ThemeDB.fallback_font
	var size := c.size
	var bar_w := minf(520.0, size.x * 0.36)
	for i in mini(fighters.size(), 2):
		var f: Fighter = fighters[i]
		var left := i == 0
		var x := MARGIN if left else size.x - MARGIN - bar_w
		var y := MARGIN
		var ratio := clampf(f.health / f.max_health, 0.0, 1.0)
		var trail := clampf(_trail_health[i] / f.max_health, 0.0, 1.0)
		# Frame.
		c.draw_rect(Rect2(x - 4, y - 4, bar_w + 8, BAR_H + 8), Color(0, 0, 0, 0.65))
		c.draw_rect(Rect2(x, y, bar_w, BAR_H), Color(0.16, 0.05, 0.08))
		# Bars drain toward the outer edge of the screen.
		var tw := bar_w * trail
		var hw := bar_w * ratio
		c.draw_rect(Rect2(x if left else x + bar_w - tw, y, tw, BAR_H), Color(1.0, 0.9, 0.85))
		var col := Color(1.0, 0.25, 0.2).lerp(Color(1.0, 0.85, 0.2), clampf(ratio * 2.0, 0.0, 1.0))
		col = col.lerp(Color(0.35, 0.95, 0.5), clampf(ratio * 2.0 - 1.0, 0.0, 1.0))
		c.draw_rect(Rect2(x if left else x + bar_w - hw, y, hw, BAR_H), col)
		c.draw_rect(Rect2(x if left else x + bar_w - hw, y, hw, BAR_H * 0.35), Color(1, 1, 1, 0.25))
		# Name and round pips.
		var align := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		_text(c, font, Vector2(x, y + BAR_H + 30), f.display_name, align, bar_w, 22, f.body_color)
		for r in rounds_to_win:
			var px := x + 10.0 + r * 26.0 if left else x + bar_w - 10.0 - r * 26.0
			var won: bool = wins[i] > r
			c.draw_circle(Vector2(px, y + BAR_H + 52), 8.0, Color(0, 0, 0, 0.6))
			c.draw_circle(Vector2(px, y + BAR_H + 52), 6.0, Color(1.0, 0.8, 0.2) if won else Color(0.25, 0.25, 0.3))
		# Combo counter under the attacker's bar.
		if _combo_t[i] > 0.0 and _combo[i] >= 2:
			var a := clampf(_combo_t[i] / 0.4, 0.0, 1.0)
			_text(c, font, Vector2(x, y + BAR_H + 100), "%d HITS" % _combo[i], align, bar_w, 40, Color(1.0, 0.85, 0.3, a))

	# Timer.
	var cx := size.x * 0.5
	c.draw_rect(Rect2(cx - 44, MARGIN - 8, 88, 58), Color(0, 0, 0, 0.6))
	var timer_col := Color(1.0, 0.35, 0.3) if time_left <= 10.0 else Color.WHITE
	_text(c, font, Vector2(cx - 60, MARGIN + 36), str(ceili(time_left)), HORIZONTAL_ALIGNMENT_CENTER, 120, 40, timer_col)

	# Announcer.
	if _announce != "" and _announce_t < _announce_len:
		var k := _announce_t
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 6.0)
		var fade := clampf((_announce_len - k) / 0.25, 0.0, 1.0)
		var center := Vector2(cx, size.y * 0.42)
		c.draw_rect(Rect2(0, center.y - 70, size.x, 100), Color(0, 0, 0, 0.35 * fade))
		c.draw_set_transform(center, 0.0, Vector2.ONE * pop)
		_text(c, font, Vector2(-500, 18), _announce, HORIZONTAL_ALIGNMENT_CENTER, 1000, 76, Color(1.0, 0.95, 0.85, fade))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _announce_sub != "":
			_text(c, font, Vector2(0, center.y + 70), _announce_sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.8, 0.85, 1.0, fade))

	if hint != "":
		_text(c, font, Vector2(0, size.y - 18), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(1, 1, 1, 0.45))


func _text(c: Control, font: Font, pos: Vector2, text: String, align: HorizontalAlignment, width: float, font_size: int, color: Color) -> void:
	c.draw_string_outline(font, pos, text, align, width, font_size, maxi(4, font_size / 6), Color(0, 0, 0, color.a * 0.9))
	c.draw_string(font, pos, text, align, width, font_size, color)


class HudCanvas extends Control:
	var hud: Hud

	func _draw() -> void:
		hud.draw_hud(self)
