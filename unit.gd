extends Node2D

signal unit_clicked(unit)

@export var hp: int = 100
@export var move_range: int = 2
@export var grid_position: Vector2i

@onready var selection = $Selection

func set_selected(value: bool):
	selection.visible = value

func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("unit_clicked", self)
