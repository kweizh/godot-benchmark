extends Node

signal bus_volume_changed(bus_name: StringName, db: float)

var _duck_tween: Tween
var _base_music_volume: float = 0.0
var _voice_player: AudioStreamPlayer

func _ready() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = &"Voice"
	add_child(_voice_player)
	_voice_player.finished.connect(_on_voice_finished)
	
	var music_idx = AudioServer.get_bus_index(&"Music")
	if music_idx >= 0:
		_base_music_volume = AudioServer.get_bus_volume_db(music_idx)

func set_bus_volume(bus_name: StringName, db: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)
		if bus_name == &"Music":
			_base_music_volume = db
		bus_volume_changed.emit(bus_name, db)

func get_bus_volume(bus_name: StringName) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return AudioServer.get_bus_volume_db(idx)
	return 0.0

func mute_bus(bus_name: StringName, muted: bool) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)

func set_low_pass_enabled(enabled: bool) -> void:
	var idx = AudioServer.get_bus_index(&"Music")
	if idx >= 0:
		AudioServer.set_bus_effect_enabled(idx, 0, enabled)

func duck_music(strength_db: float = -12.0, duration: float = 0.5) -> void:
	var idx = AudioServer.get_bus_index(&"Music")
	if idx < 0:
		return
		
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
		
	_duck_tween = create_tween()
	
	var target_vol = _base_music_volume + strength_db
	AudioServer.set_bus_volume_db(idx, target_vol)
	
	_duck_tween.tween_interval(duration)
	_duck_tween.tween_callback(func(): AudioServer.set_bus_volume_db(idx, _base_music_volume))

func play_voice_with_duck(stream: AudioStream) -> void:
	_voice_player.stream = stream
	_voice_player.play()
	var duration = 0.5
	if stream and stream.has_method("get_length"):
		duration = stream.get_length()
	duck_music(-12.0, duration)

func _on_voice_finished() -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	var idx = AudioServer.get_bus_index(&"Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _base_music_volume)
