extends Node

var current_level_number = 1

func load_next_level():
	current_level_number += 1
	
	if current_level_number <= 2:
		# Load your hand-made scenes
		get_tree().change_scene_to_file("res://World/Level2.tscn")
	else:
		# Load the "Generator" scene
		get_tree().change_scene_to_file("res://World/GeneratedLevel.tscn")
