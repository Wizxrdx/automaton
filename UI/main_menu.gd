extends Control

func _on_start_button_pressed():
	# 1. Capture the mouse (essential for web/top-down games)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED) 
	
	# 2. Switch to your game world
	get_tree().change_scene_to_file("res://World/Level1.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
