extends Node2D

@onready var tilemap = $TileMap
@onready var camera = $Camera2D

const HIGHLIGHT_LAYER = 1
const HIGHLIGHT_TILE = Vector2i(3, 3)

const MAP_MIN = Vector2i(0, 0)
const MAP_MAX = Vector2i(10, 10)

const ZOOM_MIN = 3.0
const ZOOM_MAX = 6.0
const CAMERA_SPEED = 200.0
const CAMERA_MIN = Vector2(90, 50)
const CAMERA_MAX = Vector2(180, 180)
const EDGE_SCROLL_MARGIN = 10
const EDGE_SCROLL_SPEED = 1.0

var selected_unit = null
var occupied_cells = {}
var click_handled = false
var is_moving = false

var current_team = 0


# =========================================================
# INIT
# =========================================================

func _ready():
	occupied_cells.clear()

	for unit in get_tree().get_nodes_in_group("unit"):
		unit.unit_clicked.connect(select_unit)
		unit.grid_position = world_to_cell(unit.position)
		occupied_cells[unit.grid_position] = unit

func _process(delta):
	move_camera(delta)

func move_camera(delta):
	var direction = Vector2.ZERO

	# WASD
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S):
		direction.y += 1

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D):
		direction.x += 1

	# Стрілки
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	if Input.is_action_pressed("ui_down"):
		direction.y += 1

	if Input.is_action_pressed("ui_left"):
		direction.x -= 1

	if Input.is_action_pressed("ui_right"):
		direction.x += 1

	# 🖱 РУХ КАМЕРИ КРАЯМИ ЕКРАНУ
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size

	# ЛІВО
	if mouse_pos.x <= EDGE_SCROLL_MARGIN:
		direction.x -= EDGE_SCROLL_SPEED

	# ПРАВО
	elif mouse_pos.x >= screen_size.x - EDGE_SCROLL_MARGIN:
		direction.x += EDGE_SCROLL_SPEED

	# ВГОРУ
	if mouse_pos.y <= EDGE_SCROLL_MARGIN:
		direction.y -= EDGE_SCROLL_SPEED

	# ВНИЗ
	elif mouse_pos.y >= screen_size.y - EDGE_SCROLL_MARGIN:
		direction.y += EDGE_SCROLL_SPEED

	if direction != Vector2.ZERO:
		direction = direction.normalized()

		camera.position += direction * CAMERA_SPEED * delta


	# 🔒 ОБМЕЖЕННЯ КАМЕРИ
	camera.position.x = clamp(
		camera.position.x,
		CAMERA_MIN.x,
		CAMERA_MAX.x
	)

	camera.position.y = clamp(
		camera.position.y,
		CAMERA_MIN.y,
		CAMERA_MAX.y
	)

# =========================================================
# SELECT
# =========================================================

func select_unit(unit):
	if is_moving:
		return

	# 🆕 тільки своя команда
	if unit.team != current_team:
		return

	if not unit.can_act():
		print("Немає очок дії")
		return

	click_handled = true

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
	if is_moving:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			click_handled = false
			await get_tree().process_frame
			if not click_handled:
				handle_map_click(get_global_mouse_position())

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_zoom = camera.zoom * 1.1
			new_zoom.x = min(new_zoom.x, ZOOM_MAX)
			new_zoom.y = min(new_zoom.y, ZOOM_MAX)
			camera.zoom = new_zoom

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_zoom = camera.zoom * 0.9
			new_zoom.x = max(new_zoom.x, ZOOM_MIN)
			new_zoom.y = max(new_zoom.y, ZOOM_MIN)
			camera.zoom = new_zoom

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL \
		or event.keycode == KEY_KP_ADD:
			var new_zoom = camera.zoom * 1.1
			new_zoom.x = min(new_zoom.x, ZOOM_MAX)
			new_zoom.y = min(new_zoom.y, ZOOM_MAX)
			camera.zoom = new_zoom

		elif event.keycode == KEY_MINUS \
		or event.keycode == KEY_KP_SUBTRACT:
			var new_zoom = camera.zoom * 0.9
			new_zoom.x = max(new_zoom.x, ZOOM_MIN)
			new_zoom.y = max(new_zoom.y, ZOOM_MIN)
			camera.zoom = new_zoom

func apply_zoom(factor):
	var cam = get_node("UnitsContainer/Camera2D")

	cam.zoom *= factor

	cam.zoom.x = clamp(cam.zoom.x, ZOOM_MIN, ZOOM_MAX)
	cam.zoom.y = clamp(cam.zoom.y, ZOOM_MIN, ZOOM_MAX)

# =========================================================
# CLICK
# =========================================================

func handle_map_click(mouse_pos):
	if not selected_unit:
		return

	# 🔥 якщо AP = 0 → зняти виділення
	if not selected_unit.can_act():
		selected_unit.set_selected(false)
		selected_unit = null
		clear_highlight()
		return

	var target = get_clicked_cell(mouse_pos)

	if not is_within_map(target):
		return

	if is_cell_occupied(target):
		return

	var path = find_path(selected_unit.grid_position, target)

	if path.is_empty():
		return

	if path.size() - 1 > selected_unit.move_range:
		return

	await move_unit_along_path(selected_unit, path)


# =========================================================
# MOVE
# =========================================================

func move_unit_along_path(unit, path):
	is_moving = true

	occupied_cells.erase(unit.grid_position)

	await animate_path(unit, path)

	unit.spend_ap(1)

	occupied_cells[unit.grid_position] = unit

	clear_highlight()

	if selected_unit == unit:
		if unit.can_act():
			show_move_range(unit)
		else:
			print("Очки дії вичерпано")

			unit.set_selected(false)
			selected_unit = null
			clear_highlight()

	is_moving = false


func animate_path(unit, path):
	var tween = create_tween()
	var prev_dir = null

	for i in range(1, path.size()):
		var from = cell_to_world(path[i - 1])
		var to = cell_to_world(path[i])

		var dir = (to - from).normalized()

		if prev_dir == null or dir.dot(prev_dir) < 0.999:
			var target_angle = dir.angle()
			var current = unit.rotation
			var diff = wrapf(target_angle - current, -PI, PI)
			var final_angle = current + diff

			tween.tween_property(unit, "rotation", final_angle, 0.12)

		tween.tween_property(unit, "position", to, 0.25)\
			.set_trans(Tween.TRANS_LINEAR)\
			.set_ease(Tween.EASE_IN_OUT)

		prev_dir = dir
		unit.grid_position = path[i]

	await tween.finished


# =========================================================
# TURN SYSTEM (поки не використовується, але готово)
# =========================================================

func end_turn():
	current_team = 1 - current_team

	for unit in get_tree().get_nodes_in_group("unit"):
		if unit.team == current_team:
			unit.action_points = unit.max_action_points

	clear_highlight()

	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null


# =========================================================
# BFS (ПІДСВІТКА)
# =========================================================

func show_move_range(unit):
	clear_highlight()

	if not unit.can_act():
		return

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
# PATHFINDING
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
# HEX
# =========================================================

func get_neighbors(cell):
	var result = []
	var cube = offset_to_cube(cell)

	var directions = [
		Vector3i(1,-1,0), Vector3i(1,0,-1),
		Vector3i(0,1,-1), Vector3i(-1,1,0),
		Vector3i(-1,0,1), Vector3i(0,-1,1)
	]

	for d in directions:
		result.append(cube_to_offset(cube + d))

	return result


func offset_to_cube(cell):
	var x = cell.x - ((cell.y - (cell.y & 1)) >> 1)
	var z = cell.y
	var y = -x - z
	return Vector3i(x, y, z)


func cube_to_offset(cube):
	var col = cube.x + ((cube.z - (cube.z & 1)) >> 1)
	return Vector2i(col, cube.z)


func get_distance(a, b):
	var ac = offset_to_cube(a)
	var bc = offset_to_cube(b)

	return (
		abs(ac.x - bc.x) +
		abs(ac.y - bc.y) +
		abs(ac.z - bc.z)
	) / 2


# =========================================================
# MAP / UTILS
# =========================================================

func is_within_map(cell):
	if cell.y < MAP_MIN.y or cell.y > MAP_MAX.y:
		return false

	if cell.y % 2 == 1:
		return cell.x >= 0 and cell.x <= MAP_MAX.x - 1
	else:
		return cell.x >= 0 and cell.x <= MAP_MAX.x


func is_cell_occupied(cell):
	return occupied_cells.has(cell)


func world_to_cell(pos):
	return tilemap.local_to_map(tilemap.to_local(pos))


func cell_to_world(cell):
	return tilemap.to_global(tilemap.map_to_local(cell))


func get_clicked_cell(mouse_pos):
	var local_pos = tilemap.to_local(mouse_pos)
	var cell = tilemap.local_to_map(local_pos)

	var best = cell
	var best_dist = cell_to_world(cell).distance_to(mouse_pos)

	for x in range(-1,2):
		for y in range(-1,2):
			var n = cell + Vector2i(x,y)
			var d = cell_to_world(n).distance_to(mouse_pos)

			if d < best_dist:
				best_dist = d
				best = n

	return best


func _on_end_turn_button_pressed():
	if is_moving:
		return

	end_turn()
