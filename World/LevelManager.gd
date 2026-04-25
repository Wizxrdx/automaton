extends Node

var current_level_number = 1

func load_next_level():
	current_level_number += 1
	
	# 1. Manually find and kill the old level if it's stuck in the root
	# This is necessary because of the reparenting we did in the Main Menu
	var root = get_tree().root
	for child in root.get_children():
		# This looks for any node that looks like Level1, Level2, etc.
		if "Level" in child.name and child is Node2D:
			child.queue_free()
			print("Purged old level: ", child.name)

	# 2. Pick the next path
	var next_path = "res://World/Level2.tscn"
	if current_level_number > 2:
		next_path = "res://World/GeneratedLevel.tscn"
		
	# 3. Change Scene
	get_tree().change_scene_to_file(next_path)
	
	# 4. Re-lock the mouse (Scene changes often reset mouse mode)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
