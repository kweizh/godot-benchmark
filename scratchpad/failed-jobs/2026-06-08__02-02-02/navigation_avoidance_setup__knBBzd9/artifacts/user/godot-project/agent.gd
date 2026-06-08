extends CharacterBody2D

var speed: float = 100.0
var nav_agent: NavigationAgent2D
var velocity_computed_triggered: bool = false

func _ready():
	# Create and configure the NavigationAgent2D child node programmatically
	nav_agent = NavigationAgent2D.new()
	nav_agent.name = "NavigationAgent2D"
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 10.0
	add_child(nav_agent)
	
	# Connect the velocity_computed signal to apply safe avoidance velocity
	nav_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta: float):
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return
	
	# Get the next position along the navigation path
	var next_path_pos = nav_agent.get_next_path_position()
	var current_pos = global_position
	
	# Calculate the desired velocity towards the next path point
	var desired_velocity = current_pos.direction_to(next_path_pos) * speed
	
	# Pass the desired velocity to the NavigationAgent2D to trigger avoidance calculation
	nav_agent.velocity = desired_velocity

func _on_velocity_computed(safe_velocity: Vector2):
	velocity_computed_triggered = true
	# Use the safe velocity computed by the NavigationServer to move
	velocity = safe_velocity
	move_and_slide()
