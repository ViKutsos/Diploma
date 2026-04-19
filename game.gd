extends Node2D

@onready var tilemap = $TileMap

const HIGHLIGHT_LAYER = 1
const HIGHLIGHT_TILE = Vector2i(3, 3)

const MAP_MIN = Vector2i(0, 0)
const MAP_MAX = Vector2i(10, 10)

var selected_unit = null

# 🔥 НОВЕ: зайняті клітини
var occupied_cells = {}


# 🔧 Ініціалізація
func _ready():
	occupied_cells.clear()

	for unit in get_tree().get_nodes_in_group("unit"):
		unit.unit_clicked.connect(select_unit)
		unit.grid_position = world_to_cell(unit.position)

		occupied_cells[unit.grid_position] = unit

		print("INIT:", unit.grid_position)


# 🟡 Вибір юніта
func select_unit(unit):
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


# 🖱 Клік по мапі
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_map_click(get_global_mouse_position())


# 🚶 Обробка кліку
func handle_map_click(mouse_pos):
	if not selected_unit:
		return

	var target_cell = get_clicked_cell(mouse_pos)

	if not is_within_map(target_cell):
		return

	# ❗ блокування
	if is_cell_occupied(target_cell):
		print("Клітинка зайнята")
		return

	var distance = get_distance(selected_unit.grid_position, target_cell)

	print("FROM:", selected_unit.grid_position)
	print("TO:", target_cell)
	print("DIST:", distance)

	if distance > selected_unit.move_range:
		print("Занадто далеко")
		return

	move_unit(selected_unit, target_cell)


# 📍 Переміщення
func move_unit(unit, target_cell):
	# ❗ звільняємо стару клітинку
	occupied_cells.erase(unit.grid_position)

	unit.grid_position = target_cell
	unit.position = cell_to_world(target_cell)

	# ❗ займаємо нову
	occupied_cells[target_cell] = unit

	clear_highlight()


# 🔄 Базові перетворення
func world_to_cell(pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(pos))


func cell_to_world(cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))


# 🔥 Визначення клітинки під мишею
func get_clicked_cell(mouse_pos: Vector2) -> Vector2i:
	var local_pos = tilemap.to_local(mouse_pos)
	var cell = tilemap.local_to_map(local_pos)

	var best_cell = cell
	var best_dist = cell_to_world(cell).distance_to(mouse_pos)

	for x in range(-1, 2):
		for y in range(-1, 2):
			var neighbor = cell + Vector2i(x, y)
			var world_pos = cell_to_world(neighbor)
			var dist = world_pos.distance_to(mouse_pos)

			if dist < best_dist:
				best_dist = dist
				best_cell = neighbor

	return best_cell


# =========================================================
# 🧠 HEX ЛОГІКА
# =========================================================

func offset_to_cube(cell: Vector2i) -> Vector3i:
	var col: int = cell.x
	var row: int = cell.y

	var x: int = col - ((row - (row & 1)) >> 1)
	var z: int = row
	var y: int = -x - z

	return Vector3i(x, y, z)


func get_distance(a: Vector2i, b: Vector2i) -> int:
	var ac: Vector3i = offset_to_cube(a)
	var bc: Vector3i = offset_to_cube(b)

	return (
		abs(ac.x - bc.x)
		+ abs(ac.y - bc.y)
		+ abs(ac.z - bc.z)
	) / 2


# =========================================================
# 🗺 МЕЖІ МАПИ
# =========================================================

func is_within_map(cell: Vector2i) -> bool:
	if cell.y < MAP_MIN.y or cell.y > MAP_MAX.y:
		return false

	if cell.y % 2 == 1:
		return cell.x >= MAP_MIN.x and cell.x <= MAP_MAX.x - 1
	else:
		return cell.x >= MAP_MIN.x and cell.x <= MAP_MAX.x


# =========================================================
# 🔒 ЗАЙНЯТІСТЬ КЛІТИН
# =========================================================

func is_cell_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)


# =========================================================
# ✨ ПІДСВІТКА
# =========================================================

func show_move_range(unit):
	clear_highlight()

	var range = unit.move_range
	var origin = unit.grid_position

	for x in range(origin.x - range, origin.x + range + 1):
		for y in range(origin.y - range, origin.y + range + 1):
			var cell = Vector2i(x, y)

			if not is_within_map(cell):
				continue

			var dist = get_distance(origin, cell)

			# ❗ не підсвічуємо стартову клітинку
			if dist == 0:
				continue

			# ❗ не підсвічуємо зайняті
			if is_cell_occupied(cell):
				continue

			if dist <= range:
				tilemap.set_cell(HIGHLIGHT_LAYER, cell, 0, HIGHLIGHT_TILE)


func clear_highlight():
	tilemap.clear_layer(HIGHLIGHT_LAYER)
