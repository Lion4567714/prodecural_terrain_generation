class_name MeshController
extends MeshInstance3D

# Overall settings
var PRINT_STATUS_MESSAGES = false
var VIEW_BIOME_TEST = false
var VIEW_BIOME_MAP = false
var VIEW_HEIGHT_MAP = true
var ENABLE_SMOOTHING = true

# Mesh settings
const WIDTH = 75
const HEIGHT = 75
const CELL_SIZE = 3.0
const FEATURE_SENSITIVITY = 0.5
const BIOME_BLEND = 5

# Constants (DON'T PLAY WITH)
const BIOME = {
	MOUNTAINS = 0b00001,
	HILLS = 0b00010,
	PLAINS = 0b00100,
	BEACHS = 0b01000,
	OCEANS = 0b10000
}
const BIOME_NAMES = [
	"Mountains",
	"Hills",
	"Plains",
	"Beachs",
	"Oceans"
]
const BIOME_PLACEHOLDER_COLORS = [
	Color.RED,
	Color.YELLOW,
	Color.DARK_GREEN,
	Color.DEEP_SKY_BLUE,
	Color.WEB_PURPLE
]
const SNOW = Color(255, 255, 255, 1)
const GRASS = Color(0, 255, 0, 1)
const SAND = Color(255, 240, 0, 1)
const WATER = Color(0, 0, 255, 1)
const RAYCAST_LENGTH = 1000
const HAMMING = [0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4, 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5]

# Global scene components
var camera: Camera3D
var collision_area: Area3D
var biome_text: RichTextLabel
var brush_text: RichTextLabel
var progress_bar: ProgressBar

# Script globals
var selected_biome: int = 0
var brush_size: int = 5
var last_update_time
var noise
var gaussian_kernel
var biome_map
var height_map

signal progress_updated(ratio: float)


class Biome:
	var name: String
	var color: Color
	
	var noise: FastNoiseLite
	var noise_offset: float
	var noise_intensity: float
	var noise_x_sensitivity: float
	var noise_y_sensitivity: float
	
	var terrain_colors: Array[Color]
	var terrain_color_constraints: Array[Vector2]
	
	func _init(_name: String, _color: Color = Color.BLACK, _noise: FastNoiseLite = FastNoiseLite.new(), _noise_offset: float = 0, \
			_noise_intensity: float = 1.0, _noise_x_sensitivity: float = 1.0, _noise_y_sensitivity: float = 1.0,
			_terrain_colors: Array[Color] = [Color.BLACK], _terrain_color_constraints: Array[Vector2] = [Vector2(-1, -1)]) -> void:
		assert(terrain_colors.size() == terrain_color_constraints.size(), "Biome._init(): Every terrain color must have a corresponding terrain color constraint!")
		
		name = _name
		color = _color
		noise = _noise
		noise_offset = _noise_offset
		noise_intensity = _noise_intensity
		noise_x_sensitivity = _noise_x_sensitivity
		noise_y_sensitivity = _noise_y_sensitivity
		terrain_colors = _terrain_colors
		terrain_color_constraints = _terrain_color_constraints
	
	func height_at(x: int, y: int) -> float:
		return noise_offset + noise_intensity * noise.get_noise_2d(noise_x_sensitivity * x, noise_y_sensitivity * y)
	
	func color_at(height: float) -> Color:
		for i in range(terrain_colors.size()):
			if (height > terrain_color_constraints[i].x || terrain_color_constraints[i].x == -1) && \
					(height < terrain_color_constraints[i].y || terrain_color_constraints[i].y == -1):
				return terrain_colors[i]
		return Color.BLACK


# Runs once at the start
# Sets up blank mesh and prints controls to output
func _ready():
	camera = get_viewport().get_camera_3d()
	
	collision_area = get_node("/root/Node3D/Area3D")
	collision_area.scale = Vector3(WIDTH * CELL_SIZE, 1, HEIGHT * CELL_SIZE)
	
	biome_text = get_node("/root/Node3D/Canvas/BiomeText")
	biome_text.text = "Selected Biome: [b]" + BIOME_NAMES[selected_biome] + "[/b]"
	
	brush_text = get_node("/root/Node3D/Canvas/BrushText")
	brush_text.text = "Brush Size:     [b]" + str(brush_size) + "[/b]"
	
	progress_bar = get_node("/root/Node3D/Canvas/ProgressBar")
	
	print("Controls:")
	print("WASD+C+Space: camera movement")
	print("LMB: draw biome")
	print("Scroll: switch biome type")
	print("Up/Down: change brush size")
	print("E: erase mesh")
	print("R: regenerate mesh")
	print("T: toggle biome test")
	print("B: toggle biome map")
	print("H: toggle height map")
	print("F: toggle feature map")
	print("M: toggle status messages")
	print("O: toggle terrain smoothing")
	print("-----")


# Runs every frame, unused
func _process(_delta):
	pass


# Handles keyboard and mouse input related to mesh
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			initialize()
			generate_mesh(true)
		#elif event.keycode == KEY_R:
			#generate_mesh()
		elif event.keycode == KEY_UP:
			brush_size += 1
			brush_text.text = "Brush Size:     [b]" + str(brush_size) + "[/b]"
		elif event.keycode == KEY_DOWN:
			if brush_size > 1:
				brush_size -= 1
				brush_text.text = "Brush Size:     [b]" + str(brush_size) + "[/b]" 
		elif event.keycode == KEY_H:
			VIEW_HEIGHT_MAP = toggle(VIEW_HEIGHT_MAP, "Height map")
		elif event.keycode == KEY_B:
			VIEW_BIOME_MAP = toggle(VIEW_BIOME_MAP, "Biome map")
		elif event.keycode == KEY_M:
			PRINT_STATUS_MESSAGES = toggle(PRINT_STATUS_MESSAGES, "Status messages")
		elif event.keycode == KEY_O:
			ENABLE_SMOOTHING = toggle(ENABLE_SMOOTHING, "Terrain smoothing")
		elif event.keycode == KEY_T:
			VIEW_BIOME_TEST = toggle(VIEW_BIOME_TEST, "Biome test")
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_pos = get_viewport().get_mouse_position()
			var from = camera.project_ray_origin(mouse_pos)
			var to = from + camera.project_ray_normal(mouse_pos) * RAYCAST_LENGTH
			
			var space_state = get_world_3d().get_direct_space_state()
			var params = PhysicsRayQueryParameters3D.new()
			params.from = from
			params.to = to
			params.collide_with_areas = true
			var result = space_state.intersect_ray(params)
			
			if !result:
				return
			
			var grid_position: Vector2 = Vector2(result.position.x, result.position.z)
			grid_position.x += ((WIDTH + 1) * CELL_SIZE) / 2
			grid_position.y += ((HEIGHT + 1) * CELL_SIZE) / 2
			grid_position /= CELL_SIZE
			grid_position.x = int(grid_position.x)
			grid_position.y = int(grid_position.y)
			if PRINT_STATUS_MESSAGES:
				print("Set vertex at " + str(grid_position) + " to " + BIOME_NAMES[selected_biome])
			
			for x in range(grid_position.x - brush_size + 1, grid_position.x + brush_size):
				for y in range(grid_position.y - brush_size + 1, grid_position.y + brush_size):
					if abs(grid_position.x - x) + abs(grid_position.y - y) <= brush_size:
						if x >= 0 && x <= WIDTH && y >= 0 && y <= HEIGHT:
							biome_map[x][y] = 1 << selected_biome
			reload_mesh()
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if selected_biome == BIOME.size() - 1:
				return
			selected_biome += 1
			biome_text.text = "Selected Biome: [b]" + BIOME_NAMES[selected_biome] + "[/b]"
	
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if selected_biome == 0:
				return
			selected_biome -= 1
			biome_text.text = "Selected Biome: [b]" + BIOME_NAMES[selected_biome] + "[/b]"


# Toggles settings on and off
func toggle(setting: bool, setting_name: String) -> bool:
	setting = not setting
	print(setting_name + " -> " + "on" if setting else "off")
	return setting


# Sets up global variables
func initialize() -> void:
	add_user_signal("progress_updated")
	#add_user_signal("progress_updated", [{"name": "ratio", "type": TYPE_FLOAT}])
	print(get_signal_list())
	
	self.mesh = generate_grid()
	
	noise = FastNoiseLite.new()
	noise.set_noise_type(FastNoiseLite.TYPE_PERLIN)
	noise.set_seed(Time.get_datetime_dict_from_system().second)
	
	gaussian_kernel = generate_gaussian_kernel(10, 1.5)
	
	biome_map = []
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		biome_map.append(col)
	
	generate_mesh(true)


# Runs every mouse click
# Redraws blank mesh to show plainted biomes
func reload_mesh():
	var state = VIEW_BIOME_MAP
	VIEW_BIOME_MAP = true
	
	var my_mesh = generate_grid()
	
	var mdt = MeshDataTool.new()
	if not mdt.create_from_surface(my_mesh, 0) == OK:
		print("ERROR: create_from_surface()")
		return
	print_status("Created MeshDataTool from surface")
	
	var color_map = generate_colors(biome_map, true)
	print_status("Generated color map")
	
	self.mesh = compile_mesh(mdt, color_map)
	print_status("Mesh compiled")
	
	VIEW_BIOME_MAP = state


# Main mesh generation function
func generate_mesh(is_blank: bool = false) -> void:
	if PRINT_STATUS_MESSAGES:
		print("-----")
		print("Starting new mesh generation...")
	last_update_time = Time.get_ticks_usec()	# Reset timer for new mesh generation
	
	if !is_blank:
		if !VIEW_BIOME_TEST:
			biome_map = generate_biome_map()
		else:
			biome_map = generate_biome_map_test()
		print_status("Generated biome map")
	
	var my_mesh = generate_grid()
	print_status("Generated grid")
	
	var mdt = MeshDataTool.new()
	if not mdt.create_from_surface(my_mesh, 0) == OK:
		print("ERROR: create_from_surface()")
		return
	print_status("Created MeshDataTool from surface")
	
	height_map = generate_height_map(biome_map, is_blank || !VIEW_HEIGHT_MAP)
	print_status("Generated height map")
	
	if !is_blank && ENABLE_SMOOTHING:
		height_map = convolve(height_map, gaussian_kernel)
		print_status("Smoothed height map")
	
	var color_map
	if is_blank:
		color_map = generate_colors(biome_map, true)
	else:
		color_map = generate_colors(biome_map)
	print_status("Generated color map")
	
	self.mesh = compile_mesh(mdt, color_map)
	print_status("Mesh compiled")


# Prints status messages with timestamp
func print_status(message):
	if !PRINT_STATUS_MESSAGES:
		return
	
	var string = "(%6.3f secs) %s"
	print(string % [(float)(Time.get_ticks_usec() - last_update_time) / 1_000_000, message])
	last_update_time = Time.get_ticks_usec()


# Creates basic triangle frame grid
func generate_grid():
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	for y in range(WIDTH + 1):
		for x in range(HEIGHT + 1):
			vertices.push_back(Vector3((x - (WIDTH + 1) / 2) * CELL_SIZE, 0, (y - (HEIGHT + 1) / 2) * CELL_SIZE))
	
	for y in range(WIDTH):
		for x in range(HEIGHT):
			var i0 = y + (WIDTH + 1) * x
			var i1 = i0 + 1
			var i2 = i1 + WIDTH
			var i3 = i2 + 1
			
			indices.push_back(i0)
			indices.push_back(i1)
			indices.push_back(i2)
			
			indices.push_back(i1)
			indices.push_back(i3)
			indices.push_back(i2)
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh


# Class for representing one node in the wave function collapse algorithm
class WFCNode:
	var pos: Vector2
	var options: int
	var num_options: int
	
	func _init(x: int, y: int) -> void:
		pos.x = x
		pos.y = y
		options = 0
		for biome in BIOME.values():
			options += biome
		num_options = BIOME.size()
	
	func limit_options(limit: int) -> void:
		assert(options & limit > 0, "num_options == 0! options: " + str(options) + ", limit: " + str(limit))
		options &= limit
		num_options = HAMMING[options]
	
	static func sort(a: WFCNode, b: WFCNode) -> bool:
		return a.num_options < b.num_options
	
	func _to_string() -> String:
		return str(options)
		#return "WFCNode: pos (" + str(pos.x) + ", " + str(pos.y) + "), num_options = " + str(num_options)


# Masks and updates available options for given node
func limit_options_of_node(node: WFCNode, limit: int, arrays: Array) -> void:
	var old = node.num_options - 1
	node.limit_options(limit)
	var new = node.num_options - 1
	
	if new != old:
		arrays[old].erase(node)
		arrays[new].append(node)


# Handles updating surrounding nodes after node collapse
func collapse_node(node: WFCNode, node_mat: Array, node_arrs: Array) -> void:
	var x0 = node.pos.x
	var y0 = node.pos.y
	var limit = node.options
	
	for i in range(1, BIOME.size() - 1):
		limit |= limit >> 1
		limit |= limit << 1
		if y0 - i >= 0:
			for x in range(x0 - i, x0 + i + 1):
				if x >= 0 && x <= WIDTH:
					limit_options_of_node(node_mat[x][y0 - i], limit, node_arrs)
		if y0 + i <= HEIGHT:
			for x in range(x0 - i, x0 + i + 1):
				if x >= 0 && x <= WIDTH:
					limit_options_of_node(node_mat[x][y0 + i], limit, node_arrs)
		if x0 - i >= 0:
			for y in range(y0 - i, y0 + i + 1):
				if y >= 0 && y <= HEIGHT:
					limit_options_of_node(node_mat[x0 - i][y], limit, node_arrs)
		if x0 + i <= WIDTH:
			for y in range(y0 - i, y0 + i + 1):
				if y >= 0 && y <= HEIGHT:
					limit_options_of_node(node_mat[x0 + i][y], limit, node_arrs)


# Generates biome map using wave function collapse algorithm
func generate_biome_map():
	var node_mat = []
	var node_arrs = []	# Array of arrays, index cooresponds to num remaining options + 1
	var num_uncollapsed_nodes = (WIDTH + 1) * (HEIGHT + 1)
	for i in range(BIOME.size()):
		node_arrs.append([])
	for x in range(WIDTH + 1):
		var arr1 = []
		arr1.resize(HEIGHT + 1)
		var arr2 = []
		arr2.resize(HEIGHT + 1)
		node_mat.append(arr2)
		
		for y in range(HEIGHT + 1):
			node_mat[x][y] = WFCNode.new(x, y)
			node_arrs[BIOME.size() - 1].append(node_mat[x][y])
	
	# Check for existing biome mapping and collapse based upon that
	for x in range(WIDTH + 1):
		for y in range(HEIGHT + 1):
			if biome_map[x][y] != null:
				var node: WFCNode = node_mat[x][y]
				node_arrs[node.num_options - 1].erase(node)
				node_arrs[0].append(node)
				node.options = biome_map[x][y]
				node.num_options = 1
				num_uncollapsed_nodes -= 1
				collapse_node(node, node_mat, node_arrs)
	
	while num_uncollapsed_nodes > 0:
		progress_updated.emit(1 - num_uncollapsed_nodes / ((WIDTH + 1) * (HEIGHT + 1)))
		
		# Find the first array with > 0 nodes, choose a random node within that array
		var rand_node = null
		
		for i in range(1, node_arrs.size()):
			if node_arrs[i].size() > 0:
				rand_node = node_arrs[i][randi_range(0, node_arrs[i].size() - 1)]
				break
		if rand_node == null:
			break
		
		# Collapse vertex
		var rand_option_index = randi_range(0, rand_node.num_options - 1)
		var rand_option
		for i in range(BIOME.size()):
			if (1 << i) & rand_node.options > 0:
				if rand_option_index == 0:
					rand_option = 1 << i 
					break;
				rand_option_index -= 1
		node_arrs[rand_node.num_options - 1].erase(rand_node)
		node_arrs[0].append(rand_node)
		rand_node.options = rand_option
		rand_node.num_options = 1
		num_uncollapsed_nodes -= 1
		
		collapse_node(rand_node, node_mat, node_arrs)
	
	for x in range(WIDTH + 1):
		for y in range(HEIGHT + 1):
			biome_map[x][y] = node_mat[x][y].options
	
	#progress_bar.visible = false
	
	return biome_map


# Creates artificial biome map for testing purposes
func generate_biome_map_test():
	var map = []
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		map.append(col)
		for y in range(HEIGHT + 1):
			if y < 1 * (HEIGHT + 1) / BIOME.size():
				map[x][y] = BIOME.values()[0]
			elif y < 2 * (HEIGHT + 1) / BIOME.size():
				map[x][y] = BIOME.values()[1]
			elif y < 3 * (HEIGHT + 1) / BIOME.size():
				map[x][y] = BIOME.values()[2]
			elif y < 4 * (HEIGHT + 1) / BIOME.size():
				map[x][y] = BIOME.values()[3]
			elif y < 5 * (HEIGHT + 1) / BIOME.size():
				map[x][y] = BIOME.values()[4]
	return map


# Generates randomness to height map
func generate_height_map(biome_map: Array, is_flat: bool) -> Array:
	height_map = []
	
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		height_map.append(col)
		
		for y in range(HEIGHT + 1):
			var height = 0
			
			if !is_flat:
				match biome_map[x][y]:
					BIOME.MOUNTAINS:
						height = 30 + 150 * noise.get_noise_2d(3 * x, 3 * y)
					BIOME.HILLS:
						height = 20 + 100 * noise.get_noise_2d(1.5 * x, 1.5 * y)
					BIOME.PLAINS:
						height = 10 + 50 * noise.get_noise_2d(x, y)
					BIOME.BEACHS:
						height = 5 + 12 * noise.get_noise_2d(15 * x, 5 * y)
					BIOME.OCEANS:
						height = 0
				if height < 0:
					height = 0
			
			height_map[x][y] = height
	
	return height_map


# Generates Gaussian kernel for convolutional smoothing
func generate_gaussian_kernel(size: int, std_dev: float) -> Array:
	var kernel = []
	var sum = 0
	
	for x in range(size):
		var col = []
		col.resize(size)
		kernel.append(col)
		
		for y in range(size):
			kernel[x][y] = (1 / (2 * PI * pow(std_dev, 2))) * pow(2.718282, -((pow(x - size / 2, 2) + pow(y - size / 2, 2)) / (2 * pow(std_dev, 2))))
			sum += kernel[x][y]
	
	for x in range(size):
		for y in range(size):
			kernel[x][y] /= sum
	
	return kernel


# Applies kernel to given matrix and returns resulting convolution
func convolve(matrix: Array, kernel: Array) -> Array:
	var new_matrix = []
	
	for x in range(matrix.size()):
		var col = []
		col.resize(matrix[x].size())
		new_matrix.append(col)
		
		for y in range(matrix[x].size()):
			new_matrix[x][y] = 0
			
			for i in range(kernel.size()):
				for j in range(kernel[i].size()):
					var mat_x = x - kernel.size() / 2 + i
					var mat_y = y - kernel[i].size() / 2 + j
					if mat_x >= 0 && mat_x < matrix.size() && mat_y >= 0 && mat_y < matrix[x].size():
						new_matrix[x][y] += matrix[mat_x][mat_y] * kernel[i][j]
	
	return new_matrix


# Creates color map using biome and height data
func generate_colors(biome_map: Array, is_blank: bool = false) -> Array:
	var color_map = []
	
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		color_map.append(col)
		
		for y in range(HEIGHT + 1):
			if VIEW_BIOME_MAP || is_blank:
				if biome_map[x][y] == 0:
					color_map[x][y] = Color(255, 255, 255, 1)
				if biome_map[x][y] == BIOME.MOUNTAINS:
					color_map[x][y] = Color(255, 0, 0, 1)
				elif biome_map[x][y] == BIOME.HILLS:
					color_map[x][y] = Color(255, 255, 0, 1)
				elif biome_map[x][y] == BIOME.PLAINS:
					color_map[x][y] = Color(0, 255, 0, 1)
				elif biome_map[x][y] == BIOME.BEACHS:
					color_map[x][y] = Color(0, 255, 255, 1)
				elif biome_map[x][y] == BIOME.OCEANS:
					color_map[x][y] = Color(0, 0, 255, 1)
			else:
				if height_map[x][y] > 35:
					color_map[x][y] = SNOW
				elif biome_map[x][y] == BIOME.BEACHS:
					color_map[x][y] = SAND
				elif height_map[x][y] > 0 && biome_map[x][y] == BIOME.OCEANS:
					color_map[x][y] = SAND
				elif height_map[x][y] < 1:
					color_map[x][y] = WATER
				else:
					color_map[x][y] = GRASS
	
	return color_map


# Final pass before rendering mesh
func compile_mesh(mdt: MeshDataTool, color_map: Array) -> ArrayMesh:
	# Apply heightmap to mesh
	for i in range(mdt.get_vertex_count()):
		var vertex: Vector3 = mdt.get_vertex(i)
		vertex[1] = height_map[i % (WIDTH + 1)][i / (WIDTH + 1)]
		mdt.set_vertex(i, vertex)
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var uvs = PackedVector2Array()

	for face in mdt.get_face_count():
		var normal = mdt.get_face_normal(face)
		for vertex in range(0, 3):
			var faceVertex = mdt.get_face_vertex(face, vertex)
			var x = (int)(mdt.get_vertex(faceVertex)[0] / CELL_SIZE) + (WIDTH + 1) / 2
			var y = (int)(mdt.get_vertex(faceVertex)[2] / CELL_SIZE) + (HEIGHT + 1) / 2
			
			vertices.push_back(mdt.get_vertex(faceVertex))
			uvs.push_back(mdt.get_vertex_uv(faceVertex))
			if color_map[x][y] == null:
				colors.push_back(Color(255, 255, 255, 1))
			else:
				colors.push_back(color_map[x][y])
			normals.push_back(normal)

	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrays[ArrayMesh.ARRAY_NORMAL] = normals
	arrays[ArrayMesh.ARRAY_COLOR] = colors
	arrays[ArrayMesh.ARRAY_TEX_UV] = uvs
	var arr_mesh = ArrayMesh.new()
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	arr_mesh.surface_set_material(0, mat)
	
	return arr_mesh
