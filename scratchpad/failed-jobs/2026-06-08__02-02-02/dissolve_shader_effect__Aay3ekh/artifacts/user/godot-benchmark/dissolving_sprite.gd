extends Sprite2D

signal dissolve_completed

func dissolve() -> void:
	if material:
		var tween = create_tween()
		tween.tween_property(material, "shader_parameter/dissolve_amount", 1.0, 1.0).from(0.0)
		tween.finished.connect(_on_dissolve_completed)

func _on_dissolve_completed() -> void:
	dissolve_completed.emit()
