extends MeshInstance3D

const WIDTH = 300
const HEIGHT = 300
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
const BIOME_BLEND = 3

const MOUNTAINS = 0
const PLAINS = 1
const OCEANS = 2

var last_update_time
var biome_map
var noise
var height_map
var feature_map
var feature_threshold

# Called when the node enters the scene tree for the first time.
func _ready():
	last_update_time = Time.get_ticks_msec()
	
	print_status("Generating biome map")
	biome_map = generate_biome_map()
	
	print_status("Generating grid")
	var my_mesh = generate_grid()
	
	print_status("Creating MeshDataTool from surface")
	var mdt = MeshDataTool.new()
	if not mdt.create_from_surface(my_mesh, 0) == OK:
		print("ERROR: create_from_surface()")
		return
	
	print_status("Adding randomization")
	noise = FastNoiseLite.new()
	noise.set_noise_type(FastNoiseLite.TYPE_PERLIN)
	noise.set_seed(7714)
	
	height_map = []
	for x in range(WIDTH + 1):
		var col = []
		col.resize(WIDTH + 1)
		height_map.append(col)
		for y in range(HEIGHT + 1):
			height_map[x][y] = random_height(x, y)
	
	print_status("Generating feature map and smoothing")
	var sum = 0
	for x in range(CON_KERNEL.size()):
		for y in range(CON_KERNEL.size()):
			if CON_KERNEL[x][y] < 0:
				sum += -CON_KERNEL[x][y]
	feature_threshold = sum * FEATURE_SENSITIVITY
	
	generate_feature_map()
	smooth_height_map()
	
	# Apply noise to all vertices
	var mesh_vertices = PackedVector3Array()
	for i in range(mdt.get_vertex_count()):
		mesh_vertices.append(mdt.get_vertex(i))
		
		mesh_vertices[i][1] = height_map[i / (WIDTH + 1)][i % (WIDTH + 1)]
		
		mdt.set_vertex(i, mesh_vertices[i])
	
	print_status("Generating ArrayMesh")
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var uvs = PackedVector2Array()

	for face in mdt.get_face_count():
		var normal = mdt.get_face_normal(face)
		for vertex in range(0, 3):
			var faceVertex = mdt.get_face_vertex(face, vertex)
			vertices.push_back(mdt.get_vertex(faceVertex))
			uvs.push_back(mdt.get_vertex_uv(faceVertex))
			
			if feature_map[(int)(mdt.get_vertex(faceVertex)[2] / CELL_SIZE)][(int)(mdt.get_vertex(faceVertex)[0] / CELL_SIZE)] > feature_threshold:
				colors.push_back(Color(128, 0, 128, 1))
			elif mdt.get_vertex(faceVertex)[1] > 20:
				colors.push_back(Color(255, 255, 255, 1))
			elif mdt.get_vertex(faceVertex)[1] <= -20:
				colors.push_back(Color(0, 0, 255, 1))
			else:			
				colors.push_back(Color(0, 255, 0, 1))
				
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
	
	print_status("Fixing material")
	var mat = StandardMaterial3D.new();
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	
	print_status("Done")
	return


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func print_status(message):
	print("(", (float)(Time.get_ticks_msec() - last_update_time) / 1000, " secs) ", message)
	last_update_time = Time.get_ticks_msec()


func generate_grid():
	var vertices = PackedVector3Array()
	var indicies = PackedInt32Array()
	
	for y in range(WIDTH + 1):
		for x in range(HEIGHT + 1):
			vertices.push_back(Vector3(x * CELL_SIZE, 0, y * CELL_SIZE))
	
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var i0 = y + (WIDTH + 1) * x
			var i1 = i0 + 1
			var i2 = i1 + WIDTH
			var i3 = i2 + 1
			
			indicies.push_back(i0)
			indicies.push_back(i1)
			indicies.push_back(i2)
			
			indicies.push_back(i1)
			indicies.push_back(i3)
			indicies.push_back(i2)
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indicies
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh


func generate_biome_map():
	var map = []
	
	for x in range(WIDTH + 1):
		var col = []
		col.resize(HEIGHT + 1)
		map.append(col)
		for y in range(HEIGHT + 1):
			if x > 2 * WIDTH / 3:
				map[x][y] = MOUNTAINS
			elif x > WIDTH / 3:
				map[x][y] = PLAINS
			else:
				map[x][y] = OCEANS
	
	return map


func random_height(x, y):
	var height = 0
	
	match biome_map[x][y]:
		MOUNTAINS:
			height = 100 * noise.get_noise_2d(x, y) + 5
		PLAINS:
			height = 50 * noise.get_noise_2d(x, y)
		OCEANS:
			height = 10 * noise.get_noise_2d(x, y) - 5
	
	if height < -20:
		height = -20
	
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
