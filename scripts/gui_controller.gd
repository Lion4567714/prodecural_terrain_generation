class_name GUIController
extends Node
 
var mesh_controller: Node3D
var progress_bar: ProgressBar

func initialize():
	mesh_controller = get_node("/root/Node3D/MeshInstance3D")
	mesh_controller.progress_updated.connect(_handle_progress_update)


func _ready():
	progress_bar = get_node("/root/Node3D/Canvas/ProgressBar")
	progress_bar.visible = false


func _handle_progress_update(ratio: float):
	if ratio < 0:
		progress_bar.visible = false
	else:
		progress_bar.visible = true
		progress_bar.ratio = ratio
