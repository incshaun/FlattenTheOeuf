extends ColorRect

const MaxPoints : int = 100
const PlotInterval : float = 1.0
var points = []
var timeSinceLast = 0.0
var threshold = 0.7

func addPoint (v, delta):
	timeSinceLast += delta
	if timeSinceLast > PlotInterval:
		timeSinceLast = 0.0
		if v > 1.0:
			v = 1.0
		if v < 0.0:
			v = 0.0
#		print ("Adding point", v, points)
		while points.size () > MaxPoints:
			points.remove (0)
		points.append (v)
	
		update ()
	
func _draw():
	var margin = 0.05
	# border of chart.
	draw_rect (Rect2 (Vector2 (margin, margin) * rect_size, Vector2 (1.0 - 2.0 * margin, 1.0 - 2.0 * margin) * rect_size), Color (0.05, 0.05, 0.05), 1)
	# threshold line
	draw_line (Vector2 (margin, margin + (1.0 - 2.0 * margin) * (1.0 - threshold)) * rect_size, Vector2 (margin + 1.0 - 2.0 * margin, margin + (1.0 - 2.0 * margin) * (1.0 - threshold)) * rect_size, Color (0.75, 0.55, 0.05), 1)
	# vertical lines.
	for i in range (9):
		draw_line (Vector2 (margin + (1.0 - 2.0 * margin) * (float (i + 1) / 10), margin) * rect_size, Vector2 (margin + (1.0 - 2.0 * margin) * (float (i + 1) / 10), margin + 1.0 - 2.0 * margin) * rect_size, Color (0.45, 0.45, 0.45), 1)
	
	# plot points.
	var markerSize = Vector2 (4.0, 4.0)
	if points.size () > 0:
		var start = Vector2 (0 + margin, margin + (1.0 - 2.0 * margin) * (1.0 - points[0])) * rect_size
		for i in range (points.size () - 1):
			var p = points[i + 1]
			var end = Vector2 (margin + (1.0 - 2.0 * margin) * (float (i) / MaxPoints), margin + (1.0 - 2.0 * margin) * (1.0 - p)) * rect_size
			var markerColour = Color (0.8 + 0.2 * p, 0.8 + 0.4 * (0.5 * threshold - p), 0.8 - p)
			
			draw_line (start, end, Color(0.4, 0.4, 0.4), 1.5, true)
			draw_rect (Rect2 (end - 0.5 * markerSize, markerSize), markerColour, 1)
			start = end
		
func _ready():
	pass # Replace with function body.

#func _process(delta):
#	pass
