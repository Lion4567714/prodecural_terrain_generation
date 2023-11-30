extends MeshInstance3D

const TEST_BIOME = false

const BIOME_VIEW = true

const WIDTH = 100
const HEIGHT = 100
const CELL_SIZE = 2.0
#const CON_KERNEL = [[-1, -1, -1],
#					[-1,  8, -1],
#					[-1, -1, -1]]
const CON_KERNEL = [[ 0, -1,  0],
					[ 0,  2,  0],
					[ 0, -1,  0]]
#const CON_KERNEL = [[-1, -1, -1, -1, -1],
#					[-1, -2, -2, -2, -1],
#					[-1, -2, 30, -2, -1],
#					[-1, -2, -2, -2, -1],
#					[-1, -1, -1, -1, -1]]
#const CON_KERNEL = [[0, 0, -1, 0, 0],
#					[0, 0, -1, 0, 0],
#					[0, 0,  4, 0, 0],
#					[0, 0, -1, 0, 0],
#					[0, 0, -1, 0, 0]]
const FEATURE_SENSITIVITY = 0.5
const BIOME_BLEND = 5

const HAMMING = [0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4, 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5]
const BIOME = {
	HIGH_MOUNTAINS = 0b00001,
	MOUNTAINS = 0b00010,
	PLAINS = 0b00100,
	BEACHS = 0b01000,
	OCEANS = 0b10000
}
const SNOW = Color(255, 255, 255, 1)
const GRASS = Color(0, 255, 0, 1)
const SAND = Color(255, 240, 0, 1)
const WATER = Color(0, 0, 255, 1)

var last_update_time
var biome_map
var biome_size
var biome_dict
var noise
var height_map
var feature_map
var feature_threshold


# Called when the node enters the scene tree for the first time.
func _ready():
	generate_mesh()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _input(_event):
	if Input.is_key_pressed(KEY_R):
		generate_mesh()
		

func generate_mesh():
	print("-----")
	print("Starting new mesh generation...")
	last_update_time = Time.get_ticks_usec()	# Reset timer for new mesh generation
	
	if !TEST_BIOME:
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
	
	noise = FastNoiseLite.new()
	noise.set_noise_type(FastNoiseLite.TYPE_PERLIN)
	noise.set_seed(Time.get_datetime_dict_from_system().second)
	
	height_map = []
	for x in range(WIDTH + 1):
		var col = []
		col.resize(WIDTH + 1)
		height_map.append(col)
		for y in range(HEIGHT + 1):
			height_map[x][y] = random_height(x, y, biome_map[x][y])
	print_status("Added randomization")
	
	var sum = 0
	for x in range(CON_KERNEL.size()):
		for y in range(CON_KERNEL.size()):
			if CON_KERNEL[x][y] < 0:
				sum += -CON_KERNEL[x][y]
	feature_threshold = sum * FEATURE_SENSITIVITY
	
	generate_feature_map()
	blend_biomes(BIOME_BLEND)
	#smooth_height_map()
	print_status("Generated feature map and smoothing")
	
	var color_map = generate_colors()
	print_status("Generated color map")
	
	# Apply heightmap to mesh
	for i in range(mdt.get_vertex_count()):
		var vertex: Vector3 = mdt.get_vertex(i)
		vertex[1] = height_map[i / (WIDTH + 1)][i % (WIDTH + 1)]
		mdt.set_vertex(i, vertex)
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var uvs = PackedVector2Array()

	for face in mdt.get_face_count():
		var normal = mdt.get_face_normal(face)
		for vertex in range(0, 3):
			var faceVertex = mdt.get_face_vertex(face, vertex)
			var x = (int)(mdt.get_vertex(faceVertex)[2] / CELL_SIZE)
			var y = (int)(mdt.get_vertex(faceVertex)[0] / CELL_SIZE)
			
			vertices.push_back(mdt.get_vertex(faceVertex))
			uvs.push_back(mdt.get_vertex_uv(faceVertex))
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

	self.mesh = arr_mesh
	print_status("Generated final mesh")
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	print_status("Done")
	
	print(biome_size)
	print(biome_dict)


func print_status(message):
	var string = "(%6.3f secs) %s"
	print(string % [(float)(Time.get_ticks_usec() - last_update_time) / 1_000_000, message])
	last_update_time = Time.get_ticks_usec()


func generate_grid():
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	for y in range(WIDTH + 1):
		for x in range(HEIGHT + 1):
			vertices.push_back(Vector3(x * CELL_SIZE, 0, y * CELL_SIZE))
	
	for x in range(WIDTH):
		for y in range(HEIGHT):
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
		#return str(options)
		return "WFCNode: pos (" + str(pos.x) + ", " + str(pos.y) + "), num_options = " + str(num_options)


func limit_options_of_node(node: WFCNode, limit: int, arrays: Array) -> void:
	var old = node.num_options - 1
	node.limit_options(limit)
	var new = node.num_options - 1
	
	if new != old:
		arrays[old].erase(node)
		arrays[new].append(node)


func generate_biome_map():
	#randomize()
	
	biome_size = []
	biome_size.resize(BIOME.size())
	for i in range(BIOME.size()):
		biome_size[i] = 0
	biome_dict = {}
	
	var map = []
	var node_mat = []
	var node_arrs = []	# Array of arrays, index cooresponds to num remaining options + 1
	var num_uncollapsed_nodes = (WIDTH + 1) * (HEIGHT + 1)
	for i in range(BIOME.size()):
		node_arrs.append([])
	for x in range(WIDTH + 1):
		var arr1 = []
		arr1.resize(HEIGHT + 1)
		map.append(arr1)
		var arr2 = []
		arr2.resize(HEIGHT + 1)
		node_mat.append(arr2)
		
		for y in range(HEIGHT + 1):
			node_mat[x][y] = WFCNode.new(x, y)
			node_arrs[BIOME.size() - 1].append(node_mat[x][y])
	
	while num_uncollapsed_nodes > 0:
		# Find the first array with > 0 nodes, choose a random node within that array
		var rand_node
		for i in range(1, node_arrs.size()):
			if node_arrs[i].size() > 0:
				rand_node = node_arrs[i][randi_range(0, node_arrs[i].size() - 1)]
				break
				
		if !biome_dict.has(rand_node.options):
			biome_dict[rand_node.options] = 0
		biome_dict[rand_node.options] += 1
		
		# Collapse vertex
		var rand_option_index = randi_range(0, rand_node.num_options - 1)
		#var rand_option_index = randi_range(0, 100) % (rand_node.num_options)
		var rand_option
		for i in range(BIOME.size()):
			if (1 << i) & rand_node.options > 0:
				if rand_option_index == 0:
					rand_option = 1 << i 
					break;
				rand_option_index -= 1
		biome_size[log(rand_option)] += 1 ###############################
		rand_node.options = rand_option
		node_arrs[rand_node.num_options - 1].erase(rand_node)
		node_arrs[0].append(rand_node)
		rand_node.num_options = 1
		num_uncollapsed_nodes -= 1
		
		# Update surround nodes
		var x0 = rand_node.pos.x
		var y0 = rand_node.pos.y
		for i in range(1, BIOME.size() - 1):
			rand_option |= rand_option >> 1
			rand_option |= rand_option << 1
			if y0 - i >= 0:
				for x in range(x0 - i, x0 + i + 1):
					if x >= 0 && x <= WIDTH:
						limit_options_of_node(node_mat[x][y0 - i], rand_option, node_arrs)
			if y0 + i <= HEIGHT:
				for x in range(x0 - i, x0 + i + 1):
					if x >= 0 && x <= WIDTH:
						limit_options_of_node(node_mat[x][y0 + i], rand_option, node_arrs)
			if x0 - i >= 0:
				for y in range(y0 - i, y0 + i + 1):
					if y >= 0 && y <= HEIGHT:
						limit_options_of_node(node_mat[x0 - i][y], rand_option, node_arrs)
			if x0 + i <= WIDTH:
				for y in range(y0 - i, y0 + i + 1):
					if y >= 0 && y <= HEIGHT:
						limit_options_of_node(node_mat[x0 + i][y], rand_option, node_arrs)
	
	for x in range(WIDTH + 1):
		for y in range(HEIGHT + 1):
			map[x][y] = node_mat[x][y].options
	
	return map


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


func random_height(x, y, biome):
	var height = 0
	
	match biome:
		BIOME.HIGH_MOUNTAINS:
			height = 30 + 150 * noise.get_noise_2d(3 * x, 3 * y)
		BIOME.MOUNTAINS:
			height = 20 + 100 * noise.get_noise_2d(1.5 * x, 1.5 * y)
		BIOME.PLAINS:
			height = 10 + 50 * noise.get_noise_2d(x, y)
		BIOME.BEACHS:
			height = 5 + 12 * noise.get_noise_2d(15 * x, y)
		BIOME.OCEANS:
			height = -3 + 5 * noise.get_noise_2d(10 * x, 5 * y)
	
	if height < 0:
		height = 0
	
	return height
	

func generate_feature_map():
	feature_map = []
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		feature_map.append(col)
		for y in range(HEIGHT + 1):
			feature_map[x][y] = convolve(CON_KERNEL, x, y)


func convolve(kernel, x, y):
	var sum = 0
	var kernel_width = kernel.size() / 2
	
	for i in range(x - kernel_width, x + kernel_width + 1):
		for j in range(y - kernel_width, y + kernel_width + 1):
			if i < 0 || i > WIDTH || j < 0 || j > HEIGHT:
				sum += kernel[x - i + kernel_width][y - j + kernel_width]
			else:
				sum += kernel[x - i + kernel_width][y - j + kernel_width] * height_map[i][j]
	
	return sum


func blend_biomes(radius: int) -> void:
	var new_height_map = []
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		new_height_map.append(col)
	
	for x0 in range(1, WIDTH):
		for y0 in range(1, HEIGHT):
			var num = 0
			var sum = 0
			
			for x1 in range(x0 - radius, x0 + radius + 1):
				for y1 in range(y0 - radius, y0 + radius + 1):
					if x1 < 0 || y1 < 0 || x1 > WIDTH || y1 > HEIGHT:
						continue
					var dist = abs(x0 - x1) + abs(y0 - y1)
					if dist > radius:
						continue
					num += 1
					sum += height_map[x1][y1]
			
			var mean = sum / num
			
			for x1 in range(x0 - radius, x0 + radius + 1):
				for y1 in range(y0 - radius, y0 + radius + 1):
					if x1 < 0 || y1 < 0 || x1 > WIDTH || y1 > HEIGHT:
						continue
					var dist = abs(x0 - x1) + abs(y0 - y1)
					if dist > radius:
						continue
					new_height_map[x1][y1] = mean + (height_map[x1][y1] - height_map[x0][y1]) * pow(0.75, dist)
	
	for x in range(WIDTH + 1):
		for y in range(HEIGHT + 1):
			if new_height_map[x][y] != null:
				height_map[x][y] = new_height_map[x][y]
			

func smooth_height_map():
	var new_height_map = []
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		new_height_map.append(col)
		for y in range(HEIGHT + 1):
			new_height_map[x][y] = height_map[x][y]
	
	for x in range(WIDTH + 1):
		for y in range(HEIGHT + 1):
			if abs(feature_map[x][y]) > feature_threshold:
				smooth_at_coords(new_height_map, x, y)
	
	for x in range(WIDTH + 1):
		for y in range(HEIGHT + 1):
			if new_height_map[x][y] != null:
				height_map[x][y] = new_height_map[x][y]


func smooth_at_coords(new_height_map, x, y):
	var sum = 0
	for i in range(x - BIOME_BLEND - 1, x + BIOME_BLEND + 1):
		for j in range(y - BIOME_BLEND - 1, y + BIOME_BLEND + 1):
			if i < 0 || i > WIDTH || j < 0 || j > HEIGHT:
				continue
			else:
				sum += height_map[i][j]
	
	var mean = sum / pow(2 * BIOME_BLEND + 1, 2)
	
	for i in range(x - BIOME_BLEND, x + BIOME_BLEND):
		for j in range(y - BIOME_BLEND, y + BIOME_BLEND):
			if i < 0 || i > WIDTH || j < 0 || j > HEIGHT:
				continue
			else:
				var center_dist = abs(x - i) + abs(y - j)
				new_height_map[i][j] = mean + pow(0.8, pow(BIOME_BLEND, 2) - center_dist) * (height_map[i][j] - mean)
	return
	
	var std_dev = 0
	for i in range(x - BIOME_BLEND, x + BIOME_BLEND):
		for j in range(y - BIOME_BLEND, y + BIOME_BLEND):
			if i < 0 || i > WIDTH || j < 0 || j > HEIGHT:
				continue
			else:
				std_dev += pow(height_map[i][j] - mean, 2)
	std_dev = pow(std_dev / (pow(2 * BIOME_BLEND + 1, 2) - 1), 0.5)
	
	for i in range(x - BIOME_BLEND, x + BIOME_BLEND):
		for j in range(y - BIOME_BLEND, y + BIOME_BLEND):
			if i < 0 || i > WIDTH || j < 0 || j > HEIGHT:
				continue
			else:
				var z_score = (height_map[i][j] - mean) / std_dev
				new_height_map[i][j] -= std_dev * tanh(z_score / 4)


func generate_colors():
	var color_map = []
	
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		color_map.append(col)
		
		for y in range(HEIGHT + 1):
			if !BIOME_VIEW:
				if height_map[x][y] > 35:
					color_map[x][y] = SNOW
				elif biome_map[x][y] == BIOME.BEACHS:
					color_map[x][y] = SAND
				elif height_map[x][y] > 0 && biome_map[x][y] == BIOME.OCEANS:
					color_map[x][y] = SAND
				elif height_map[x][y] == 0:
					color_map[x][y] = WATER
				else:
					color_map[x][y] = GRASS
			else:		
				if biome_map[x][y] == BIOME.HIGH_MOUNTAINS:
					color_map[x][y] = Color(255, 0, 0, 1)
				elif biome_map[x][y] == BIOME.MOUNTAINS:
					color_map[x][y] = Color(255, 255, 0, 1)
				elif biome_map[x][y] == BIOME.PLAINS:
					color_map[x][y] = Color(0, 255, 0, 1)
				elif biome_map[x][y] == BIOME.BEACHS:
					color_map[x][y] = Color(0, 255, 255, 1)
				elif biome_map[x][y] == BIOME.OCEANS:
					color_map[x][y] = Color(0, 0, 255, 1) 
	
	return color_map
