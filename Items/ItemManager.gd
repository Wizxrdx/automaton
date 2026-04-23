extends Node

# Hold all the scenes here globally
var item_scenes = {
	"battery": preload("res://Items/Types/battery.tscn"),
	"scrap": preload("res://Items/Types/scrap.tscn"),
	"tires": preload("res://Items/Types/tires.tscn")
}

func spawn_item(item_type: String, spawn_pos: Vector2) -> Node2D:
	var scene = item_scenes.get(item_type)
	if not scene: 
		push_error("ItemManager: Scene not found for " + item_type)
		return null
	
	var new_item = scene.instantiate()
	new_item.global_position = spawn_pos
	
	# Add it directly to the main game world
	get_tree().current_scene.add_child(new_item)
	
	# Automatically trigger the robot cooldown timer
	if new_item.has_method("drop_to_ground"):
		new_item.drop_to_ground()
		
	return new_item
