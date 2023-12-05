class_name CameraController
extends Node3D

var canvas: CanvasLayer

var mouse_is_captured = true
var move_speed = 50.0
var look_speed = 0.003
var rot_x = 0
var rot_y = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if Input.is_action_pressed("ui_up"):
		self.position -= transform.basis.z.normalized() * move_speed * delta
	if Input.is_action_pressed("ui_down"):
		self.position += transform.basis.z.normalized() * move_speed * delta
	if Input.is_action_pressed("ui_left"):
		self.position -= transform.basis.x.normalized() * move_speed * delta
	if Input.is_action_pressed("ui_right"):
		self.position += transform.basis.x.normalized() * move_speed * delta
	if Input.is_action_pressed("ui_page_up"):
		self.position.y += move_speed * delta
	if Input.is_action_pressed("ui_page_down"):
		self.position.y -= move_speed * delta
		
	if Input.is_action_just_pressed("ui_menu"):
		if mouse_is_captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_is_captured = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_is_captured = true
		
	# Needs to be done every frame to prevent loss of significance
	transform = transform.orthonormalized()

func _input(event):
	if mouse_is_captured:
		if event is InputEventMouseMotion:
			rot_x += -event.relative.x * look_speed
			rot_y += -event.relative.y * look_speed
			transform.basis = Basis()
			rotate_object_local(Vector3(0, 1, 0), rot_x)
			rotate_object_local(Vector3(1, 0, 0), rot_y)
