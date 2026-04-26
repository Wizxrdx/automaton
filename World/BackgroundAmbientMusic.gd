extends Node

var bg_music: AudioStreamPlayer

func _ready():
	bg_music = AudioStreamPlayer.new()
	add_child(bg_music)
	
	# Load your file here
	bg_music.stream = load("res://World/Assets/ambient.wav")
	bg_music.volume_db = -18.0
	bg_music.autoplay = true
	
	# Ensure the import settings for the file have 'Loop' enabled!
	bg_music.play()
