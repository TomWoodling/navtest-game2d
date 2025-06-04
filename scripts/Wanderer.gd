# Wanderer.gd
extends CharacterBody2D

signal state_changed(new_state: String)
signal navigation_failed

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var path_line: Line2D = $PathLine

# Agent properties
var speed: float = 100.0
var start_position: Vector2
var current_state: String = "IDLE"

# Wander properties
var wander_radius: float = 400.0
var min_idle_time: float = 1.5
var max_idle_time: float = 4.0
var current_idle_timer: float = 0.0

# Flee properties
var flee_trigger_radius: float = 180.0
var flee_distance: float = 300.0
var flee_cooldown_duration: float = 2.5
var current_flee_cooldown_timer: float = 0.0
var flee_behavior_active: bool = true

var player_agent: CharacterBody2D
var follower_agent: CharacterBody2D

var stuck_timer: float = 0.0
var stuck_threshold: float = 4.0
var last_position: Vector2
var stuck_check_timer: float = 0.0

# Navigation map readiness
var nav_map_ready: bool = false
var waiting_for_initial_map: bool = true # Flag to only set initial idle timer once


func _ready():
	start_position = global_position
	last_position = global_position

	# --- Navigation Map Readiness Setup ---
	if not NavigationServer2D.is_connected("map_changed", Callable(self, "_on_nav_map_changed")):
		NavigationServer2D.map_changed.connect(_on_nav_map_changed)
	
	# Check if map is already usable (e.g., if Wanderer added to an already running scene with a map)
	var current_map_rid = get_world_2d().navigation_map
	if current_map_rid.is_valid() and NavigationServer2D.map_get_iteration_id(current_map_rid) > 0:
		_set_nav_map_ready(current_map_rid) # Call our handler directly
	# --- End Navigation Map Readiness Setup ---

	navigation_agent.path_desired_distance = 5.0
	navigation_agent.target_desired_distance = 5.0
	navigation_agent.path_max_distance = 60.0
	navigation_agent.avoidance_enabled = true
	navigation_agent.radius = 10

	navigation_agent.navigation_finished.connect(_on_navigation_completed)
	navigation_agent.target_reached.connect(_on_navigation_completed)
	navigation_agent.waypoint_reached.connect(_on_waypoint_reached)

	_setup_sprite()
	_setup_path_line()

	_change_state("IDLE")
	# If map isn't ready yet, set a long idle timer; _on_nav_map_changed will shorten it.
	if not nav_map_ready:
		current_idle_timer = 99999.0 # Effectively wait
		print("Wanderer: Waiting for initial navigation map synchronization.")
	else:
		current_idle_timer = 0 # Map was already ready, start wandering


func _set_nav_map_ready(map_rid_changed: RID):
	# This function is called by _on_nav_map_changed or by _ready if map is already good
	var current_world_map_rid = get_world_2d().navigation_map
	if map_rid_changed == current_world_map_rid and not nav_map_ready:
		nav_map_ready = true
		print("Wanderer: Navigation map is ready (RID: %s)." % str(map_rid_changed))
		
		# If we were in IDLE and waiting for the map, trigger wander logic
		if waiting_for_initial_map and current_state == "IDLE":
			current_idle_timer = 0.0 # Start wandering immediately or after min_idle_time
			waiting_for_initial_map = false # Only do this once for the initial load


func _on_nav_map_changed(map_rid_changed: RID):
	# This is the signal callback
	_set_nav_map_ready(map_rid_changed)


func _exit_tree():
	# Important: Disconnect signals when the node is removed to prevent errors
	if NavigationServer2D.is_connected("map_changed", Callable(self, "_on_nav_map_changed")):
		NavigationServer2D.map_changed.disconnect(_on_nav_map_changed)


func _physics_process(delta):
	if not nav_map_ready:
		# If map isn't ready, don't do any navigation-dependent logic
		# Optionally, can have a timeout here to go into a permanent error state
		return

	if flee_behavior_active and current_state != "FLEEING" and current_state != "COOLDOWN_AFTER_FLEEING":
		if _check_for_threats_and_initiate_flee():
			return

	match current_state:
		"IDLE":
			velocity = Vector2.ZERO
			current_idle_timer -= delta
			if current_idle_timer <= 0:
				_pick_random_wander_target()
		"WANDERING":
			_handle_movement(delta)
			_check_if_stuck(delta)
		"FLEEING":
			_handle_movement(delta)
			_check_if_stuck(delta)
			if not _is_threat_nearby(flee_trigger_radius * 0.8):
				_change_state("COOLDOWN_AFTER_FLEEING")
				current_flee_cooldown_timer = flee_cooldown_duration
		"COOLDOWN_AFTER_FLEEING":
			velocity = Vector2.ZERO
			current_flee_cooldown_timer -= delta
			if flee_behavior_active and _check_for_threats_and_initiate_flee():
				return
			if current_flee_cooldown_timer <= 0:
				_change_state("IDLE")
		"STUCK":
			velocity = Vector2.ZERO
			current_idle_timer -= delta
			if current_idle_timer <= -1.0:
				_change_state("IDLE")
				current_idle_timer = 0

	_update_path_visualization()


func _pick_random_wander_target():
	if not nav_map_ready: # Double check, though physics_process should gate this
		print("Wanderer: Attempted to pick target, but nav map not ready.")
		_change_state("IDLE")
		current_idle_timer = 0.5 # Retry soon
		return

	var map_rid = get_world_2d().navigation_map # Should be valid if nav_map_ready is true
	if not map_rid.is_valid(): # Should not happen if nav_map_ready is true, but defensive
		print("Wanderer: Invalid navigation map RID in _pick_random_wander_target despite nav_map_ready=true.")
		_change_state("IDLE")
		current_idle_timer = 1.0
		return

	var random_offset = Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	var potential_target = global_position + random_offset
	var navigable_target = NavigationServer2D.map_get_closest_point(map_rid, potential_target)

	if potential_target.distance_to(navigable_target) > 50.0:
		potential_target = start_position + Vector2(randf_range(-wander_radius/2, wander_radius/2), randf_range(-wander_radius/2, wander_radius/2))
		navigable_target = NavigationServer2D.map_get_closest_point(map_rid, potential_target)

	if global_position.distance_to(navigable_target) < 10.0 :
		current_idle_timer = 0.1
		_change_state("IDLE") # Re-enter IDLE to try picking again shortly
		return

	navigation_agent.target_position = navigable_target
	_change_state("WANDERING")


# --- The rest of the functions remain the same as before ---
# _setup_sprite, _setup_path_line, _handle_movement, _check_if_stuck,
# _check_for_threats_and_initiate_flee, _is_threat_nearby, set_flee_behavior,
# reset_to_start, set_path_visible, get_current_state, _change_state,
# _update_path_visualization, _on_navigation_completed, _on_waypoint_reached
# Ensure set_target_position is also present if you copied it.

# (Paste the rest of your Wanderer.gd functions here, starting from _setup_sprite)
# For brevity, I'm not repeating all of them. Just make sure they are included.
# The key changes are in _ready, _exit_tree, _on_nav_map_changed, _set_nav_map_ready,
# and the top of _physics_process and _pick_random_wander_target.

# Ensure these methods are present and unchanged from the previous full script:
func _setup_sprite():
	# Create a simple diamond sprite or different color
	var texture = ImageTexture.new()
	var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.MAGENTA) # Distinct color
	texture.set_image(image)
	sprite.texture = texture
	sprite.rotation_degrees = 45

func _setup_path_line():
	path_line.width = 2.0
	path_line.default_color = Color.PINK
	path_line.visible = true

func _handle_movement(delta):
	if navigation_agent.is_navigation_finished():
		if current_state == "WANDERING" or current_state == "FLEEING":
			_on_navigation_completed()
		return

	var current_agent_position = global_position
	var next_path_position = navigation_agent.get_next_path_position()

	var direction = (next_path_position - current_agent_position).normalized()
	velocity = direction * speed
	move_and_slide()

	if velocity.length() > 0:
		rotation = velocity.angle()

func _check_if_stuck(delta):
	stuck_check_timer += delta
	if stuck_check_timer >= 0.5:
		var distance_moved = global_position.distance_to(last_position)
		if distance_moved < 2.0: 
			stuck_timer += stuck_check_timer
		else:
			stuck_timer = 0.0
		last_position = global_position
		stuck_check_timer = 0.0

	if stuck_timer >= stuck_threshold:
		if current_state != "STUCK": 
			_change_state("STUCK")
			navigation_failed.emit()
			current_idle_timer = 0 
			stuck_timer = 0.0 

func _check_for_threats_and_initiate_flee() -> bool:
	if not (player_agent and is_instance_valid(player_agent)) and \
	   not (follower_agent and is_instance_valid(follower_agent) and follower_agent.visible):
		return false 

	var threat_source: Node2D = null
	var closest_threat_distance_sq = flee_trigger_radius * flee_trigger_radius 

	if player_agent and is_instance_valid(player_agent):
		var dist_sq = global_position.distance_squared_to(player_agent.global_position)
		if dist_sq < closest_threat_distance_sq:
			threat_source = player_agent
			closest_threat_distance_sq = dist_sq

	if follower_agent and is_instance_valid(follower_agent) and follower_agent.visible:
		var dist_sq = global_position.distance_squared_to(follower_agent.global_position)
		if dist_sq < closest_threat_distance_sq: 
			threat_source = follower_agent
	
	if threat_source:
		var map_rid = get_world_2d().navigation_map
		if not map_rid.is_valid(): return false

		var flee_direction = (global_position - threat_source.global_position).normalized()
		if flee_direction == Vector2.ZERO: 
			flee_direction = Vector2(randf_range(-1.0,1.0), randf_range(-1.0,1.0)).normalized()
		
		var flee_target_pos = global_position + flee_direction * flee_distance
		var navigable_flee_target = NavigationServer2D.map_get_closest_point(map_rid, flee_target_pos)

		if global_position.distance_to(navigable_flee_target) < 10.0:
			navigable_flee_target = NavigationServer2D.map_get_closest_point(map_rid, global_position + Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * flee_distance)

		navigation_agent.target_position = navigable_flee_target
		_change_state("FLEEING")
		stuck_timer = 0.0 
		# print("Wanderer fleeing from: ", threat_source.name, " to ", navigable_flee_target) # Keep for debugging
		return true
	return false

func _is_threat_nearby(radius: float = -1.0) -> bool:
	var check_radius_sq = (flee_trigger_radius + 30.0) * (flee_trigger_radius + 30.0) 
	if radius > 0.0:
		check_radius_sq = radius * radius

	if player_agent and is_instance_valid(player_agent):
		if global_position.distance_squared_to(player_agent.global_position) < check_radius_sq:
			return true
	if follower_agent and is_instance_valid(follower_agent) and follower_agent.visible:
		if global_position.distance_squared_to(follower_agent.global_position) < check_radius_sq:
			return true
	return false

func set_flee_behavior(active: bool):
	flee_behavior_active = active
	# print("Wanderer flee behavior set to: ", active) # Keep for debugging
	if not active and (current_state == "FLEEING" or current_state == "COOLDOWN_AFTER_FLEEING"):
		_change_state("IDLE")
		current_idle_timer = 0 

func set_target_position(_target: Vector2):
	pass # Wanderer manages its own targets

func reset_to_start():
	global_position = start_position
	last_position = start_position
	if navigation_agent: 
		# A more robust way to reset the agent's pathing without re-adding:
		navigation_agent.target_position = global_position # Set target to current to stop pathing
		# Forcing a re-evaluation of path can be tricky.
		# The following is still a bit hacky but often works better than remove/add child.
		# It tries to force the agent to re-request a path if it needs one next.
		if nav_map_ready: # Only if map is ready
			navigation_agent.target_position = NavigationServer2D.map_get_closest_point(get_world_2d().navigation_map, global_position)
		else:
			navigation_agent.target_position = global_position


	_change_state("IDLE")
	if nav_map_ready:
		current_idle_timer = 0.1 # Start wandering soon after reset if map is ready
	else:
		current_idle_timer = 99999.0 # Wait for map if not ready
		waiting_for_initial_map = true # Reset this flag on reset

	stuck_timer = 0.0
	current_flee_cooldown_timer = 0.0
	path_line.clear_points()

func set_path_visible(visible: bool):
	path_line.visible = visible

func get_current_state() -> String:
	return current_state

func _change_state(new_state: String):
	if current_state != new_state:
		# print("Wanderer state: ", current_state, " -> ", new_state) # Verbose debugging
		current_state = new_state
		state_changed.emit(new_state)

func _update_path_visualization():
	if not path_line.visible or not is_instance_valid(navigation_agent):
		path_line.clear_points()
		return

	var path = navigation_agent.get_current_navigation_path()
	path_line.clear_points()
	if path.size() > 0:
		path_line.add_point(to_local(global_position))
		for point in path:
			path_line.add_point(to_local(point))

func _on_navigation_completed():
	if current_state == "WANDERING":
		_change_state("IDLE")
		current_idle_timer = randf_range(min_idle_time, max_idle_time)
	elif current_state == "FLEEING":
		if not _is_threat_nearby():
			_change_state("COOLDOWN_AFTER_FLEEING")
			current_flee_cooldown_timer = flee_cooldown_duration
		else:
			_change_state("IDLE") 
			current_idle_timer = 0.5 

func _on_waypoint_reached(details: Dictionary):
	pass
