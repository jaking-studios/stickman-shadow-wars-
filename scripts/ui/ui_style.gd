class_name UiStyle
extends RefCounted
## Shared look for menu buttons: dark glass panels with a neon edge on focus,
## sized for both mouse and thumbs.

const ACCENT := Color(0.35, 0.8, 1.0)
const ACCENT_HOT := Color(1.0, 0.3, 0.55)


static func make_button(text: String, min_width := 380.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 58)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _box(Color(0.08, 0.07, 0.14, 0.85), Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("hover", _box(Color(0.12, 0.1, 0.22, 0.95), ACCENT))
	b.add_theme_stylebox_override("focus", _box(Color(0.12, 0.1, 0.22, 0.95), ACCENT_HOT))
	b.add_theme_stylebox_override("pressed", _box(Color(0.2, 0.1, 0.25, 1.0), ACCENT_HOT))
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(Sfx.play.bind(&"ui", 1.0, -14.0))
	return b


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.border_width_left = 6
	s.set_corner_radius_all(6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	return s
