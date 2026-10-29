class_name UiTheme
extends RefCounted
## Thème de l'interface construit en code : fond crème, boutons rose / turquoise,
## contours prune épais. Les couleurs viennent des références d'ambiance.

const CREAM := Color("fff3d6")
const CREAM_DARK := Color("f3dfb4")
const PINK := Color("f2a0b8")
const TEAL := Color("5cc8c8")
const YELLOW := Color("f7c948")
const PLUM := Color("5a3e4b")
const WOOD := Color("a9714b")
const WOOD_DARK := Color("7b4a2f")


static func box(bg: Color, border: Color = PLUM, radius := 12, border_width := 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16

	theme.set_stylebox("normal", "Button", box(PINK))
	theme.set_stylebox("hover", "Button", box(PINK.lightened(0.18)))
	theme.set_stylebox("pressed", "Button", box(TEAL))
	theme.set_stylebox("hover_pressed", "Button", box(TEAL.lightened(0.12)))
	theme.set_stylebox("disabled", "Button", box(Color("cfc2c8"), Color("8c7a83")))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "Button", PLUM)
	theme.set_color("font_disabled_color", "Button", Color("8c7a83"))

	theme.set_stylebox("panel", "PanelContainer", box(CREAM, WOOD_DARK, 14, 4))
	theme.set_color("font_color", "Label", PLUM)
	return theme


static func chip_style(tint: Color) -> StyleBoxFlat:
	return box(tint, PLUM, 10, 2)
