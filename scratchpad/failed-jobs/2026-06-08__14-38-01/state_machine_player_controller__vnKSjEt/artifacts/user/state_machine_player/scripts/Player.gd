extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0

# Get gravity from project settings, fallback to 980.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
