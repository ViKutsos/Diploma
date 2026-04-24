extends Node2D

signal unit_clicked(unit)

@export var move_range := 2
@export var max_action_points := 2

var action_points := 2
var grid_position: Vector2i

@onready var selection = $Selection


func _ready():
	action_points = max_action_points
	selection.visible = false


func set_selected(value: bool):
	selection.visible = value


func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("unit_clicked", self)


func can_act() -> bool:
	return action_points > 0


func spend_ap(amount := 1):
	action_points -= amount
	action_points = max(action_points, 0)
