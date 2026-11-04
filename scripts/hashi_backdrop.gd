extends Control
## Quiet vector background, decorative only and never an input target.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0e2027"))
	for i in 12:
		var center := Vector2(size.x * 1.08, size.y * 0.18)
		draw_arc(center, 90 + i * 26, 1.5, 4.4, 80, Color(0.26,0.46,0.43,0.045), 1, true)
	draw_circle(Vector2(size.x * 0.05, size.y * 0.82), 140, Color(0.06,0.28,0.29,0.13))
