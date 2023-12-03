class_name GameController
extends Node

var camera_node
var mesh_node
var gui_node
var camera_prefab = preload("res://prefabs/camera_3d.tscn")
var mesh_prefab = preload("res://prefabs/mesh_instance_3d.tscn")
var gui_prefab = preload("res://prefabs/canvas.tscn")
var camera_script = preload("res://scripts/camera_controller.gd")
var mesh_script = preload("res://scripts/mesh_controller.gd")
var gui_script = preload("res://scripts/gui_controller.gd")

func _ready():
	print("GameController._ready()")
	
	camera_node = get_node("/root/Node3D/Camera3D")
	camera_node.queue_free()
	camera_node = camera_prefab.instantiate()
	camera_node.set_script(camera_script)
	add_child(camera_node)
	
	mesh_node = get_node("/root/Node3D/MeshInstance3D")
	mesh_node.queue_free()
	mesh_node = mesh_prefab.instantiate()
	mesh_node.set_script(mesh_script)
	add_child(mesh_node)
	
	gui_node = get_node("/root/Node3D/Canvas")
	gui_node.queue_free()
	gui_node = gui_prefab.instantiate()
	gui_node.set_script(gui_script)
	add_child(gui_node)
	
	var thread = Thread.new()
	thread.start(mesh_node.initialize)


func _process(delta):
	pass


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			var thread = Thread.new()
			thread.start(mesh_node.generate_mesh.bind())
