# Runtime Audio Bus Mixer with Dynamic Ducking (Godot 4)

Project path: `/home/user/myproject`.

Implement a Godot 4 project that satisfies the following criteria:

- `project.godot` sets `audio/buses/default_bus_layout="res://default_bus_layout.tres"` and registers `AudioManager` as an autoload pointing at `res://autoloads/AudioManager.gd`.
- `default_bus_layout.tres` defines exactly four buses in this order: `Master`, `Music`, `SFX`, `Voice`. `Music`, `SFX`, and `Voice` send to `Master`.
- The `Music` bus has an `AudioEffectLowPassFilter` inserted at effect index `0`, disabled by default.
- `AudioManager` operates on the real `AudioServer` (no shadow dictionary) and exposes:
  - `set_bus_volume(bus_name: StringName, db: float)`
  - `get_bus_volume(bus_name: StringName) -> float`
  - `mute_bus(bus_name: StringName, muted: bool)`
  - `set_low_pass_enabled(enabled: bool)`
  - `duck_music(strength_db: float = -12.0, duration: float = 0.5)` — uses a Tween to lower Music by `strength_db`, hold for `duration`, then restore.
  - `play_voice_with_duck(stream: AudioStream)` — plays the stream on a `Voice`-bus `AudioStreamPlayer`, calls `duck_music`, restores on `finished`.
  - Signal `bus_volume_changed(bus_name, db)` emitted from `set_bus_volume`.

The verifier runs a headless harness that asserts the criteria below against `AudioServer`:

- `AudioServer.bus_count >= 4` and bus names at 0..3 are `Master`, `Music`, `SFX`, `Voice` (case-insensitive).
- `AudioServer.get_bus_effect(music_idx, 0) is AudioEffectLowPassFilter` and is disabled initially.
- `set_bus_volume(&"Music", -6.0)` -> `AudioServer.get_bus_volume_db(music_idx) == -6.0` ± 0.01 and emits `bus_volume_changed`.
- `mute_bus(&"SFX", true)` -> `AudioServer.is_bus_mute(sfx_idx) == true`; `mute_bus(&"SFX", false)` -> `false`.
- `set_low_pass_enabled(enabled)` mirrors `AudioServer.is_bus_effect_enabled(music_idx, 0)`.
- `duck_music(-10.0, 0.05)` immediately drops Music volume; after waiting longer than `duration`, restores within 0.5 dB of the original.
