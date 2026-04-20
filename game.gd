extends Node2D

@onready var tilemap = $TileMap

const HIGHLIGHT_LAYER = 1
const HIGHLIGHT_TILE = Vector2i(3, 3)

const MAP_MIN = Vector2i(0, 0)
const MAP_MAX = Vector2i(10, 10)

var selected_unit = null
var occupied_cells = {}

# ❗ нове
var click_handled = false


# =========================================================
# INIT
# =========================================================

func _ready():
	occupied_cells.clear()

	for unit in get_tree().get_nodes_in_group("unit"):
		unit.unit_clicked.connect(select_unit)
		unit.grid_position = world_to_cell(unit.position)
		occupied_cells[unit.grid_position] = unit


# =========================================================
# SELECT
# =========================================================

func select_unit(unit):
	click_handled = true  # ❗ фікс подвійного кліку

	if selected_unit == unit:
		selected_unit.set_selected(false)
		selected_unit = null
		clear_highlight()
		return

	if selected_unit:
		selected_unit.set_selected(false)

	selected_unit = unit
	selected_unit.set_selected(true)

	show_move_range(unit)


# =========================================================
# INPUT
# =========================================================

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:

			click_handled = false

			# даємо шанс Area2D обробити клік
			await get_tree().process_frame

			if not click_handled:
				handle_map_click(get_global_mouse_position())


# =========================================================
# CLICK
# =========================================================

func handle_map_click(mouse_pos):
	if not selected_unit:
		return

	var target = get_clicked_cell(mouse_pos)

	if not is_within_map(target):
		return

	if is_cell_occupied(target):
		return

	var path = find_path(selected_unit.grid_position, target)

	if path.is_empty():
		print("Шляху немає")
		return

	if path.size() - 1 > selected_unit.move_range:
		print("Занадто далеко")
		return

	move_unit_along_path(selected_unit, path)


# =========================================================
# MOVE
# =========================================================

func move_unit_along_path(unit, path):
	occupied_cells.erase(unit.grid_position)

	for cell in path:
		unit.grid_position = cell
		unit.position = cell_to_world(cell)

	occupied_cells[unit.grid_position] = unit

	clear_highlight()

	# ❗ перемалювати підсвітку для нового положення
	if selected_unit == unit:
		show_move_range(unit)

# =========================================================
# BFS (ПІДСВІТКА)
# =========================================================

func show_move_range(unit):
	clear_highlight()

	var origin = unit.grid_position
	var range = unit.move_range

	var visited = {}
	var queue = []

	queue.append(origin)
	visited[origin] = 0

	while queue.size() > 0:
		var current = queue.pop_front()
		var dist = visited[current]

		for neighbor in get_neighbors(current):

			if not is_within_map(neighbor):
				continue

			if is_cell_occupied(neighbor) and neighbor != origin:
				continue

			var new_dist = dist + 1

			if new_dist > range:
				continue

			if neighbor not in visited:
				visited[neighbor] = new_dist
				queue.append(neighbor)

				if new_dist > 0:
					tilemap.set_cell(HIGHLIGHT_LAYER, neighbor, 0, HIGHLIGHT_TILE)


func clear_highlight():
	tilemap.clear_layer(HIGHLIGHT_LAYER)


# =========================================================
# A*
# =========================================================

func find_path(start, goal):
	var open = [start]
	var came_from = {}

	var g_score = {}
	g_score[start] = 0

	var f_score = {}
	f_score[start] = get_distance(start, goal)

	while open.size() > 0:
		var current = open[0]

		for c in open:
			if f_score.get(c, 99999) < f_score.get(current, 99999):
				current = c

		if current == goal:
			return reconstruct_path(came_from, current)

		open.erase(current)

		for neighbor in get_neighbors(current):

			if not is_within_map(neighbor):
				continue

			if is_cell_occupied(neighbor) and neighbor != goal:
				continue

			var tentative = g_score[current] + 1

			if tentative < g_score.get(neighbor, 99999):
				came_from[neighbor] = current
				g_score[neighbor] = tentative
				f_score[neighbor] = tentative + get_distance(neighbor, goal)

				if neighbor not in open:
					open.append(neighbor)

	return []


func reconstruct_path(came_from, current):
	var path = [current]

	while current in came_from:
		current = came_from[current]
		path.insert(0, current)

	return path


# =========================================================
# HEX (cube-based)
# =========================================================

func get_neighbors(cell: Vector2i) -> Array:
	var result = []

	var cube = offset_to_cube(cell)

	var directions = [
		Vector3i(1, -1, 0), Vector3i(1, 0, -1),
		Vector3i(0, 1, -1), Vector3i(-1, 1, 0),
		Vector3i(-1, 0, 1), Vector3i(0, -1, 1)
	]

	for d in directions:
		var neighbor_cube = cube + d
		var neighbor_offset = cube_to_offset(neighbor_cube)
		result.append(neighbor_offset)

	return result


func offset_to_cube(cell):
	var x = cell.x - ((cell.y - (cell.y & 1)) >> 1)
	var z = cell.y
	var y = -x - z
	return Vector3i(x, y, z)


func cube_to_offset(cube: Vector3i) -> Vector2i:
	var col = cube.x + ((cube.z - (cube.z & 1)) >> 1)
	var row = cube.z
	return Vector2i(col, row)


func get_distance(a, b):
	var ac = offset_to_cube(a)
	var bc = offset_to_cube(b)

	return (
		abs(ac.x - bc.x) +
		abs(ac.y - bc.y) +
		abs(ac.z - bc.z)
	) / 2


# =========================================================
# MAP
# =========================================================

func is_within_map(cell):
	if cell.y < MAP_MIN.y or cell.y > MAP_MAX.y:
		return false

	if cell.y % 2 == 1:
		return cell.x >= MAP_MIN.x and cell.x <= MAP_MAX.x - 1
	else:
		return cell.x >= MAP_MIN.x and cell.x <= MAP_MAX.x


# =========================================================
# OCCUPIED
# =========================================================

func is_cell_occupied(cell):
	return occupied_cells.has(cell)


# =========================================================
# COORDS
# =========================================================

func world_to_cell(pos):
	return tilemap.local_to_map(tilemap.to_local(pos))


func cell_to_world(cell):
	return tilemap.to_global(tilemap.map_to_local(cell))


func get_clicked_cell(mouse_pos):
	var local_pos = tilemap.to_local(mouse_pos)
	var cell = tilemap.local_to_map(local_pos)

	var best_cell = cell
	var best_dist = cell_to_world(cell).distance_to(mouse_pos)

	for x in range(-1, 2):
		for y in range(-1, 2):
			var n = cell + Vector2i(x, y)
			var d = cell_to_world(n).distance_to(mouse_pos)

			if d < best_dist:
				best_dist = d
				best_cell = n

	return best_cell
