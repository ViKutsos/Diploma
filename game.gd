extends Node2D

@onready var tilemap = $TileMap

var selected_unit = null


# 🔧 Ініціалізація
func _ready():
	for unit in get_tree().get_nodes_in_group("unit"):
		unit.unit_clicked.connect(select_unit)
		unit.grid_position = world_to_cell(unit.position)

		print("INIT:", unit.grid_position)


# 🟡 Вибір юніта (toggle)
func select_unit(unit):
	if selected_unit == unit:
		selected_unit.set_selected(false)
		selected_unit = null
		return

	if selected_unit:
		selected_unit.set_selected(false)

	selected_unit = unit
	selected_unit.set_selected(true)


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
	unit.grid_position = target_cell
	unit.position = cell_to_world(target_cell)


# 🔄 Базові перетворення
func world_to_cell(pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(pos))


func cell_to_world(cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))


# 🔥 ТОЧНЕ визначення клітинки під мишею
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
# 🧠 HEX ЛОГІКА (ГОЛОВНЕ)
# =========================================================

# 🔁 Offset → Cube (для odd-r)
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

	var dist: int = (
		abs(ac.x - bc.x)
		+ abs(ac.y - bc.y)
		+ abs(ac.z - bc.z)
	) >> 1

	return dist
