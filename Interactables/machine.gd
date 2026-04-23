extends StaticBody2D

@export var robot_scene = preload("res://Units/Friendly/AGV/AGV.tscn")
var highlighted := false

# Definition of what this machine needs
@export var recipe = {
	"battery": 1,
	"scrap": 1,
	"tires": 1
}

# Tracking what has been put in
var current_inventory = {
	"battery": 0,
	"scrap": 0,
	"tires": 0
}

var is_complete = false

func _ready():
	add_to_group('machine')

func interact(player_ref):
	if is_complete:
		revive_robot(player_ref)
		return

	var held = player_ref.inventory.held_item
	
	if held == null:
		print("Machine: You aren't holding anything.")
		return

	# Check if the item is part of the recipe and if we still need more of it
	if recipe.has(held) and current_inventory[held] < recipe[held]:
		# Accept the item
		current_inventory[held] += 1
		player_ref.inventory.consume_item()
		print("Machine: Added ", held, ". Status: ", current_inventory)
		
		# Check if that was the last item needed
		check_recipe_completion()
	else:
		print("Machine: I don't need that.")

func check_recipe_completion():
	for item in recipe:
		if current_inventory[item] < recipe[item]:
			is_complete = false
			return
	
	is_complete = true
	print("Machine: Recipe complete! Interact again to revive.")
	# Optional: Change sprite color or play a sound to show it's ready
	$Sprite2D.modulate = Color(0.5, 1.0, 0.5) # Greenish tint when ready

func revive_robot(player_ref):
	var robot = robot_scene.instantiate()
	robot.player = player_ref
	# Spawn it slightly offset so it doesn't get stuck in the machine
	robot.global_position = global_position + Vector2(0, 30)
	get_parent().add_child(robot)
	
	# Instead of queue_free, you could just reset the machine or disable it
	queue_free()

func set_highlight(state: bool):
	highlighted = state
	if is_complete:
		$Sprite2D.modulate = Color(0.7, 1.0, 0.7) if highlighted else Color(0.5, 1.0, 0.5)
	else:
		$Sprite2D.modulate = Color(1, 1, 0.6) if highlighted else Color(1, 1, 1)
