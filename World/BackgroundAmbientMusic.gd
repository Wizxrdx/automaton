extends Node

var bg_music: AudioStreamPlayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	bg_music = AudioStreamPlayer.new()
	add_child(bg_music)
	
	# Load your file here
	bg_music.stream = load("res://World/Assets/ambient.wav")
	bg_music.bus = &"Music"
	bg_music.volume_db = -18.0
	bg_music.finished.connect(bg_music.play)
	bg_music.play()
