extends Node

var item_scenes = {
	"battery": preload("res://Items/Types/battery.tscn"),
	"scrap": preload("res://Items/Types/scrap.tscn"),
	"tires": preload("res://Items/Types/tires.tscn")
}

func spawn_item(item_type: String, spawn_pos: Vector2) -> Node2D:
	var scene = item_scenes.get(item_type)
	if not scene: return null
	
	var new_item = scene.instantiate()
	var root = get_tree().root
	var game_world = null
	
	for child in root.get_children():
		if child is Node2D and "Level" in child.name:
			game_world = child
			break
			
	if game_world:
		game_world.add_child(new_item)
		new_item.global_position = spawn_pos
		new_item.global_scale = Vector2(1, 1) 
		
		if new_item.has_method("drop_to_ground"):
			new_item.drop_to_ground()
			
		return new_item
	return null
