extends Control
## Quiet vector background, decorative only and never an input target.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f1eddf"))
	for i in 12:
		var center := Vector2(size.x * 1.08, size.y * 0.18)
		draw_arc(center, 90 + i * 26, 1.5, 4.4, 80, Color(0.45,0.6,0.4,0.06), 1, true)
	draw_circle(Vector2(size.x * 0.05, size.y * 0.82), 140, Color(0.65,0.75,0.52,0.12))
