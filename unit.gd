extends Node2D

signal unit_clicked(unit)
signal unit_died(unit)

@export var move_range := 2
@export var max_action_points := 2
@export var max_hp := 100
@export var damage := 25
@export var attack_range := 1

# 🆕 команда
@export var team := 0

# 🆕 текстури
@export var texture_team_0: Texture2D
@export var texture_team_1: Texture2D
@export var selection_ap_2: Texture2D
@export var selection_ap_1: Texture2D
@export var selection_ap_0: Texture2D

var action_points := 2
var hp := 100
var grid_position: Vector2i

@onready var selection = $Selection
@onready var sprite = $Visuals/Sprite2D


func _ready():
	action_points = max_action_points
	hp = max_hp
	selection.visible = false
	update_visual()
	update_selection_visual()


func update_visual():
	if team == 0 and texture_team_0:
		sprite.texture = texture_team_0
	elif team == 1 and texture_team_1:
		sprite.texture = texture_team_1


func set_selected(value: bool):
	selection.visible = value

	if value:
		update_selection_visual()


func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("unit_clicked", self)


func can_act() -> bool:
	return action_points > 0


func spend_ap(amount := 1):
	action_points = clamp(
		action_points - amount,
		0,
		max_action_points
	)

	update_selection_visual()

func take_damage(amount):
	hp -= amount

	print(name, " отримав ", amount, " шкоди. HP: ", hp)

	if hp <= 0:
		die()

func die():
	emit_signal("unit_died", self)
	queue_free()

func attack(target):

	if not can_act():
		return

	target.take_damage(damage)

	spend_ap(1)


func update_selection_visual():

	if action_points >= 2:
		selection.texture = selection_ap_2

	elif action_points == 1:
		selection.texture = selection_ap_1

	else:
		selection.texture = selection_ap_0
