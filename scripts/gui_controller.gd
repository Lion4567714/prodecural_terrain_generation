class_name GUIController
extends Node
 
var mesh_controller: Node3D
var progress_bar: ProgressBar

func initialize():
	print("GUIController.initialize()")
	
	var counter = 0
	while true:
		counter += 1


func _init():
	print("GUIController._init()")


func _ready():
	print("GUIController _ready()")
	
	progress_bar = get_node("/root/Node3D/Canvas/ProgressBar")
	
	mesh_controller = get_node("/root/Node3D/MeshInstance3D")
	print(mesh_controller.get_signal_list())
	#print(mesh_controller)
	#print(mesh_controller.progress_updated)
	#mesh_controller.progress_updated.connect(_handle_progress_update)
	#print(mesh_controller.progress_updated)


func _process(delta):
	pass


func _handle_progress_update(ratio: float):
	progress_bar.ratio = ratio
