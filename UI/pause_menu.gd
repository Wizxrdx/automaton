extends CanvasLayer

@onready var volume_slider: HSlider = $Backdrop/MenuAnchor/VBoxContainer/VolumePanel/VolumeMargin/VolumeRow/VolumeSlider
@onready var volume_value: Label = $Backdrop/MenuAnchor/VBoxContainer/VolumePanel/VolumeMargin/VolumeRow/VolumeValue

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	sync_volume_ui()

func sync_volume_ui():
	if volume_slider:
		volume_slider.set_value_no_signal(LevelManager.master_volume)
	if volume_value:
		volume_value.text = str(int(round(LevelManager.master_volume * 100.0))) + "%"

func open_menu():
	sync_volume_ui()
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_menu():
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _on_resume_button_pressed():
	close_menu()

func _on_restart_button_pressed():
	visible = false
	get_tree().paused = false
	LevelManager.restart_current_level()

func _on_volume_slider_value_changed(value: float):
	LevelManager.set_master_volume(value)
	if volume_value:
		volume_value.text = str(int(round(value * 100.0))) + "%"

func _on_main_menu_button_pressed():
	visible = false
	get_tree().paused = false
	LevelManager.return_to_main_menu()
