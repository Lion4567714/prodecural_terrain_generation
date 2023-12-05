class_name GUIController
extends Node
 
var mesh_controller: Node3D
var progress_bar: ProgressBar
var crosshair_line1: Line2D
var crosshair_line2: Line2D


func initialize():
	mesh_controller = get_node("/root/Node3D/MeshInstance3D")
	mesh_controller.progress_updated.connect(_handle_progress_update)


func _ready():
	progress_bar = get_node("/root/Node3D/Canvas/ProgressBar")
	progress_bar.visible = false
	
	get_tree().root.size_changed.connect(_handle_window_resize)
	
	# Create crosshair
	var canvas = get_node("/root/Node3D/Canvas")
	crosshair_line1 = Line2D.new()
	crosshair_line1.width = 2
	crosshair_line1.add_point(Vector2(get_viewport().size.x / 2 + 10, get_viewport().size.y / 2))
	crosshair_line1.add_point(Vector2(get_viewport().size.x / 2 - 10, get_viewport().size.y / 2))
	crosshair_line2 = Line2D.new()
	crosshair_line2.width = 2
	crosshair_line2.add_point(Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2 + 10))
	crosshair_line2.add_point(Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2 - 10))
	canvas.add_child(crosshair_line1)
	canvas.add_child(crosshair_line2)


func _handle_progress_update(ratio: float):
	if ratio < 0:
		progress_bar.visible = false
	else:
		progress_bar.visible = true
		progress_bar.ratio = ratio


func _handle_window_resize():
	crosshair_line1.clear_points()
	crosshair_line1.add_point(Vector2(get_viewport().size.x / 2 + 10, get_viewport().size.y / 2))
	crosshair_line1.add_point(Vector2(get_viewport().size.x / 2 - 10, get_viewport().size.y / 2))
	crosshair_line2.clear_points()
	crosshair_line2.add_point(Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2 + 10))
	crosshair_line2.add_point(Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2 - 10))
