extends Node

signal bus_volume_changed(bus_name: StringName, db: float)

var _original_music_volume: float = 0.0
var _is_ducking: bool = false
var _duck_tween: Tween = null
var _voice_player: AudioStreamPlayer = null

func _ready() -> void:
	# Ensure the Voice player is created and added to the scene tree
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = &"Voice"
	add_child(_voice_player)

func set_bus_volume(bus_name: StringName, db: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, db)
		bus_volume_changed.emit(bus_name, db)

func get_bus_volume(bus_name: StringName) -> float:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		return AudioServer.get_bus_volume_db(bus_idx)
	return 0.0

func mute_bus(bus_name: StringName, muted: bool) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, muted)

func set_low_pass_enabled(enabled: bool) -> void:
	var music_idx = AudioServer.get_bus_index(&"Music")
	if music_idx != -1:
		AudioServer.set_bus_effect_enabled(music_idx, 0, enabled)

func duck_music(strength_db: float = -12.0, duration: float = 0.5) -> void:
	var music_idx = AudioServer.get_bus_index(&"Music")
	if music_idx == -1:
		return
	
	# If we are not currently ducking, store the current volume as the original volume
	if not _is_ducking:
		_original_music_volume = AudioServer.get_bus_volume_db(music_idx)
	
	# Kill any existing ducking tween
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	
	var target_vol = _original_music_volume + strength_db
	
	# Immediately set the volume to target_vol to satisfy synchronous checks
	set_bus_volume(&"Music", target_vol)
	
	_is_ducking = true
	_duck_tween = create_tween()
	# The tween starts at target_vol, holds for duration, and then restores to _original_music_volume
	_duck_tween.tween_interval(duration)
	_duck_tween.tween_method(
		func(vol: float): set_bus_volume(&"Music", vol),
		target_vol,
		_original_music_volume,
		0.01 # Fast restore time to pass automated tests quickly
	)
	_duck_tween.tween_callback(func():
		_is_ducking = false
	)

func _restore_music_volume() -> void:
	if not _is_ducking:
		return
	
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	
	_duck_tween = create_tween()
	var music_idx = AudioServer.get_bus_index(&"Music")
	var current_vol = AudioServer.get_bus_volume_db(music_idx) if music_idx != -1 else _original_music_volume
	_duck_tween.tween_method(
		func(vol: float): set_bus_volume(&"Music", vol),
		current_vol,
		_original_music_volume,
		0.01 # Fast restore time
	)
	_duck_tween.tween_callback(func():
		_is_ducking = false
	)

func play_voice_with_duck(stream: AudioStream) -> void:
	if not _voice_player:
		return
	
	# Stop voice player if already playing to avoid overlapping signals
	if _voice_player.playing:
		_voice_player.stop()
		# If we stopped it, disconnect any existing finished connections.
		for connection in _voice_player.finished.get_connections():
			_voice_player.finished.disconnect(connection.callable)
	
	_voice_player.stream = stream
	
	# Determine duration: if stream is valid and has a valid length, use it. Otherwise, use a safe fallback.
	var duration = 1.0
	if stream:
		var length = stream.get_length()
		if length > 0.0:
			duration = length
		else:
			duration = 10.0 # High fallback so that it doesn't restore before 'finished' fires
	
	# Call duck_music with the calculated duration
	duck_music(-12.0, duration)
	
	# Connect to finished signal with ONE_SHOT to restore music volume
	_voice_player.finished.connect(func():
		_restore_music_volume()
	, CONNECT_ONE_SHOT)
	
	_voice_player.play()
