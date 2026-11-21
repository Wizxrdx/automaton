extends CanvasLayer

@onready var music_slider: HSlider = $Backdrop/MenuAnchor/VBoxContainer/VolumePanel/VolumeMargin/VolumeVBox/MusicRow/MusicSlider
@onready var music_value: Label = $Backdrop/MenuAnchor/VBoxContainer/VolumePanel/VolumeMargin/VolumeVBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Backdrop/MenuAnchor/VBoxContainer/VolumePanel/VolumeMargin/VolumeVBox/SfxRow/SfxSlider
@onready var sfx_value: Label = $Backdrop/MenuAnchor/VBoxContainer/VolumePanel/VolumeMargin/VolumeVBox/SfxRow/SfxValue

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	sync_volume_ui()

func sync_volume_ui():
	if music_slider:
		music_slider.set_value_no_signal(LevelManager.music_volume)
	if music_value:
		music_value.text = str(int(round(LevelManager.music_volume * 100.0))) + "%"
	if sfx_slider:
		sfx_slider.set_value_no_signal(LevelManager.sfx_volume)
	if sfx_value:
		sfx_value.text = str(int(round(LevelManager.sfx_volume * 100.0))) + "%"

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

func _on_music_slider_value_changed(value: float):
	LevelManager.set_music_volume(value)
	if music_value:
		music_value.text = str(int(round(value * 100.0))) + "%"

func _on_sfx_slider_value_changed(value: float):
	LevelManager.set_sfx_volume(value)
	if sfx_value:
		sfx_value.text = str(int(round(value * 100.0))) + "%"

func _on_main_menu_button_pressed():
	visible = false
	get_tree().paused = false
	LevelManager.return_to_main_menu()
