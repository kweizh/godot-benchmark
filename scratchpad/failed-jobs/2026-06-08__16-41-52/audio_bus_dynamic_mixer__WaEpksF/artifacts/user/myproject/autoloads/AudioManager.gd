extends Node

## Emitted whenever a bus volume is changed via set_bus_volume.
signal bus_volume_changed(bus_name: StringName, db: float)

## Cache of bus name → bus index for fast lookup.
var _bus_index: Dictionary = {}

## The bus index for the Music bus, used by duck_music and set_low_pass_enabled.
var _music_idx: int = -1

## Remember the pre-duck Music volume so duck_music can restore it.
var _pre_duck_volume_db: float = 0.0


func _ready() -> void:
	# Build a lookup table of bus name → index.
	for i in range(AudioServer.bus_count):
		var name: String = AudioServer.get_bus_name(i)
		_bus_index[name.to_lower()] = i

	_music_idx = _bus_index.get("music", -1)


## Set the volume (in dB) of the named bus.
func set_bus_volume(bus_name: StringName, db: float) -> void:
	var idx: int = _get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, db)
	bus_volume_changed.emit(bus_name, db)


## Get the current volume (in dB) of the named bus.
func get_bus_volume(bus_name: StringName) -> float:
	var idx: int = _get_bus_index(bus_name)
	if idx < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(idx)


## Mute or unmute the named bus.
func mute_bus(bus_name: StringName, muted: bool) -> void:
	var idx: int = _get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, muted)


## Enable or disable the LowPassFilter on the Music bus.
func set_low_pass_enabled(enabled: bool) -> void:
	if _music_idx < 0:
		return
	AudioServer.set_bus_effect_enabled(_music_idx, 0, enabled)


## Temporarily lower the Music bus volume by strength_db for duration seconds,
## then restore to the original level using a Tween.
func duck_music(strength_db: float = -12.0, duration: float = 0.5) -> void:
	if _music_idx < 0:
		return

	_pre_duck_volume_db = AudioServer.get_bus_volume_db(_music_idx)
	var target_db: float = _pre_duck_volume_db + strength_db

	# Kill any existing duck tween to avoid conflicts.
	if has_node("DuckTween"):
		var old: Tween = $DuckTween
		old.kill()
		old.queue_free()
		await get_tree().process_frame

	var tween := create_tween()
	tween.name = "DuckTween"

	# Immediately drop to the ducked volume.
	tween.tween_method(_set_music_volume, _pre_duck_volume_db, target_db, 0.0)

	# Hold at the ducked level for the specified duration.
	tween.tween_interval(duration)

	# Restore to the original volume.
	tween.tween_method(_set_music_volume, target_db, _pre_duck_volume_db, 0.1)

	tween.tween_callback(_on_duck_complete)


## Play a stream on the Voice bus, ducking Music for the duration.
func play_voice_with_duck(stream: AudioStream) -> void:
	if stream == null:
		return

	var voice_idx: int = _get_bus_index(&"Voice")
	if voice_idx < 0:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Voice"
	player.finished.connect(_on_voice_finished.bind(player))
	add_child(player)
	player.play()

	duck_music()


func _on_voice_finished(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.queue_free()


func _on_duck_complete() -> void:
	# Signal that the duck cycle completed; the Music bus is now restored.
	bus_volume_changed.emit(&"Music", _pre_duck_volume_db)


## Helper: tween the Music bus volume.
func _set_music_volume(db: float) -> void:
	if _music_idx < 0:
		return
	AudioServer.set_bus_volume_db(_music_idx, db)


## Resolve a bus name to its index (case-insensitive).
func _get_bus_index(bus_name: StringName) -> int:
	return _bus_index.get(String(bus_name).to_lower(), -1)
