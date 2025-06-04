extends CharacterBody2D

signal navigation_finished
signal navigation_failed
signal state_changed(new_state: String)

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var path_line: Line2D = $PathLine

# Agent properties
var speed: float = 150.0  # Slightly slower than main agent
var start_position: Vector2
var current_state: String = "IDLE"

# Following behavior
var target_agent: Node2D
var follow_distance: float = 80.0  # Distance to maintain from target
var update_interval: float = 0.3  # How often to update target position
var update_timer: float = 0.0

# Navigation state
var target_reached: bool = false
var stuck_timer: float = 0.0
var stuck_threshold: float = 3.0
var last_position: Vector2
var stuck_check_timer: float = 0.0

# Following state
var last_target_position: Vector2
var target_position_threshold: float = 30.0  # Minimum distance before updating path

func _ready():
	# Store starting position
	start_position = global_position
	
	# Setup navigation agent
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 8.0  # Slightly larger than main agent
	navigation_agent.path_max_distance = 50.0
	
	# Connect navigation signals
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	navigation_agent.target_reached.connect(_on_target_reached)
	navigation_agent.waypoint_reached.connect(_on_waypoint_reached)
	
	# Setup visuals
	_setup_sprite()
	_setup_path_line()
	
	# Initialize state
	_change_state("IDLE")
	last_position = global_position

func _setup_sprite():
	# Create a simple triangle sprite pointing right (different color from main agent)
	var texture = ImageTexture.new()
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)  # Green to distinguish from blue main agent
	
	texture.set_image(image)
	sprite.texture = texture

func _setup_path_line():
	path_line.width = 2.0
	path_line.default_color = Color.LIME
	path_line.visible = true

func _physics_process(delta):
	match current_state:
		"FOLLOWING":
			_handle_following(delta)
			_handle_movement(delta)
			_check_if_stuck(delta)
		"MOVING":
			_handle_movement(delta)
			_check_if_stuck(delta)
		"IDLE":
			_handle_idle_following(delta)
		"TARGET_REACHED":
			_handle_idle_following(delta)
		"STUCK":
			_handle_stuck(delta)

func _handle_following(delta):
	update_timer += delta
	
	if update_timer >= update_interval and target_agent:
		update_timer = 0.0
		_update_follow_target()

func _handle_idle_following(delta):
	# Even when idle, check if we should start following
	update_timer += delta
	
	if update_timer >= update_interval and target_agent:
		update_timer = 0.0
		_update_follow_target()

func _handle_stuck(delta):
	# When stuck, try to find a new path after a short delay
	stuck_timer += delta
	if stuck_timer >= 1.0:  # Wait 1 second before trying again
		if target_agent:
			_update_follow_target()
		stuck_timer = 0.0

func _update_follow_target():
	if not target_agent:
		return
	
	var target_pos = target_agent.global_position
	var distance_to_target = global_position.distance_to(target_pos)
	
	# Only update if target moved significantly or we're too far/close
	var target_moved = target_pos.distance_to(last_target_position) > target_position_threshold
	var distance_check = distance_to_target > follow_distance + 20.0 or distance_to_target < follow_distance - 20.0
	
	if target_moved or distance_check:
		last_target_position = target_pos
		
		# Calculate position to follow (maintain distance)
		var direction_to_target = (target_pos - global_position).normalized()
		var desired_position = target_pos - direction_to_target * follow_distance
		
		# Set new target position
		navigation_agent.target_position = desired_position
		target_reached = false
		stuck_timer = 0.0
		
		if distance_to_target > follow_distance + 10.0:
			_change_state("FOLLOWING")

func _handle_movement(delta):
	if navigation_agent.is_navigation_finished():
		return
	
	var current_agent_position = global_position
	var next_path_position = navigation_agent.get_next_path_position()
	
	# Calculate movement
	var direction = (next_path_position - current_agent_position).normalized()
	velocity = direction * speed
	
	# Move the agent
	move_and_slide()
	
	# Rotate agent to face movement direction
	if velocity.length() > 0:
		rotation = velocity.angle()
	
	# Update path visualization
	_update_path_visualization()

func _check_if_stuck(delta):
	stuck_check_timer += delta
	
	if stuck_check_timer >= 0.5:  # Check every 0.5 seconds
		var distance_moved = global_position.distance_to(last_position)
		
		if distance_moved < 5.0:  # Less than 5 pixels moved
			stuck_timer += stuck_check_timer
		else:
			stuck_timer = 0.0
		
		last_position = global_position
		stuck_check_timer = 0.0
	
	if stuck_timer >= stuck_threshold:
		_change_state("STUCK")
		navigation_failed.emit()

func set_target_agent(agent: Node2D):
	target_agent = agent
	if agent:
		last_target_position = agent.global_position
		_change_state("FOLLOWING")
	else:
		_change_state("IDLE")

func set_follow_distance(distance: float):
	follow_distance = distance

func set_target_position(target: Vector2):
	# Override for manual control
	navigation_agent.target_position = target
	target_reached = false
	stuck_timer = 0.0
	_change_state("MOVING")

func reset_to_start():
	global_position = start_position
	navigation_agent.target_position = start_position
	target_reached = false
	stuck_timer = 0.0
	_change_state("IDLE")
	path_line.clear_points()

func set_path_visible(visible: bool):
	path_line.visible = visible

func get_current_state() -> String:
	return current_state

func get_distance_to_target() -> float:
	if target_agent:
		return global_position.distance_to(target_agent.global_position)
	return 0.0

func _change_state(new_state: String):
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)
		print("Follower state changed to: ", new_state)

func _update_path_visualization():
	if not path_line.visible:
		return
	
	var path = navigation_agent.get_current_navigation_path()
	path_line.clear_points()
	
	if path.size() > 0:
		# Add current position as first point
		path_line.add_point(to_local(global_position))
		
		# Add all path points
		for point in path:
			path_line.add_point(to_local(point))

func _on_navigation_finished():
	if current_state == "FOLLOWING":
		_change_state("TARGET_REACHED")
	else:
		_change_state("TARGET_REACHED")
	navigation_finished.emit()

func _on_target_reached():
	if current_state == "FOLLOWING":
		_change_state("TARGET_REACHED")
	else:
		_change_state("TARGET_REACHED")
	navigation_finished.emit()

func _on_waypoint_reached(details: Dictionary):
	print("Follower waypoint reached: ", details)
