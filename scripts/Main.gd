# Main.gd
extends Node2D

# UI References
@onready var agent_state_label: Label = $UI/PanelContainer/VBoxContainer/AgentStateLabel
@onready var follower_state_label: Label = $UI/PanelContainer/VBoxContainer/FollowerStateLabel
@onready var follower_distance_label: Label = $UI/PanelContainer/VBoxContainer/FollowerDistanceLabel
@onready var wanderer_state_label: Label = $UI/PanelContainer/VBoxContainer/WandererStateLabel # NEW
@onready var reset_button: Button = $UI/PanelContainer/VBoxContainer/HBoxContainer/ResetButton
@onready var toggle_dynamic_button: Button = $UI/PanelContainer/VBoxContainer/HBoxContainer/ToggleDynamicButton
@onready var toggle_path_button: Button = $UI/PanelContainer/VBoxContainer/HBoxContainer/TogglePathButton
@onready var toggle_follower_button: Button = $UI/PanelContainer/VBoxContainer/HBoxContainer/ToggleFollowerButton
@onready var toggle_flee_button: Button = $UI/PanelContainer/VBoxContainer/HBoxContainer/ToggleFleeButton # NEW
@onready var target_position_label: Label = $UI/PanelContainer/VBoxContainer/TargetPositionLabel

# Game Objects
@onready var agent: CharacterBody2D = $Agent
@onready var follower: CharacterBody2D = $Follower
@onready var wanderer_agent: CharacterBody2D = $Wanderer # NEW (Make sure you've added Wanderer to scene)
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D
@onready var target_marker: Sprite2D = $TargetMarker

# Dynamic obstacles array
var dynamic_obstacles: Array[Node2D] = []
var dynamic_obstacles_moving: bool = false
var show_path: bool = true
var follower_enabled: bool = true
var wanderer_flee_active: bool = true # NEW

# Target management
var current_target: Vector2
var has_target: bool = false

func _ready():
	# Setup UI connections
	reset_button.pressed.connect(_on_reset_pressed)
	toggle_dynamic_button.pressed.connect(_on_toggle_dynamic_pressed)
	toggle_path_button.pressed.connect(_on_toggle_path_pressed)
	toggle_follower_button.pressed.connect(_on_toggle_follower_pressed)
	toggle_flee_button.pressed.connect(_on_toggle_flee_pressed) # NEW
	
	# Setup agent connections
	agent.navigation_finished.connect(_on_agent_navigation_finished)
	agent.navigation_failed.connect(_on_agent_navigation_failed)
	agent.state_changed.connect(_on_agent_state_changed)
	
	# Setup follower connections
	follower.navigation_finished.connect(_on_follower_navigation_finished)
	follower.navigation_failed.connect(_on_follower_navigation_failed)
	follower.state_changed.connect(_on_follower_state_changed)
	
	# Setup wanderer connections (NEW)
	if wanderer_agent: # Check if wanderer exists in scene
		wanderer_agent.state_changed.connect(_on_wanderer_state_changed)
		# Assign threats to Wanderer
		wanderer_agent.player_agent = agent
		wanderer_agent.follower_agent = follower
		wanderer_agent.set_flee_behavior(wanderer_flee_active)
		# wanderer_agent.start_wandering() # Wanderer's _ready now handles initial wander

	# Initialize follower to follow the main agent
	if follower_enabled and agent:
		follower.set_target_agent(agent)
	else:
		follower.set_target_agent(null)

	_find_dynamic_obstacles()
	
	_update_ui()
	target_marker.visible = false
	
	print("Navigation Testbed Ready!")
	print("Controls:")
	print("- Left Click: Set agent destination")
	print("- Right Click: Set follower destination (manual control)")
	print("- R: Reset agents")
	print("- P: Toggle path visualization")
	print("- F: Toggle follower")
	print("- D: Toggle dynamic obstacles (changed from Space for consistency with buttons)")
	print("- G: Toggle Wanderer Flee Behavior (NEW - map 'ui_toggle_flee' in Input Map)")


func _find_dynamic_obstacles():
	dynamic_obstacles.clear()
	# Assuming dynamic obstacles are direct children of Main or a specific group
	for child in get_children():
		if child is CharacterBody2D and child.has_method("set_moving"): # More specific check
			dynamic_obstacles.append(child)
	# Or use groups: get_tree().get_nodes_in_group("dynamic_obstacles")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_set_agent_destination(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_set_follower_destination(event.position)
	
	if event.is_action_pressed("ui_reset"): # Default: R
		_on_reset_pressed()
	elif event.is_action_pressed("ui_toggle_path"): # Default: P
		_on_toggle_path_pressed()
	elif event.is_action_pressed("ui_toggle_dynamic"): # Default: Space (or D as suggested)
		_on_toggle_dynamic_pressed()
	elif event.is_action_pressed("ui_toggle_follower"): # Default: F
		_on_toggle_follower_pressed()
	elif event.is_action_pressed("ui_toggle_flee"): # NEW - Map G to this
		_on_toggle_flee_pressed()


func _set_agent_destination(screen_pos: Vector2):
	var world_pos = screen_pos # Assuming UI is not fullscreen overlay / direct mapping
	if _is_position_navigable(world_pos):
		current_target = world_pos
		has_target = true
		target_marker.position = world_pos
		target_marker.visible = true
		agent.set_target_position(world_pos)
		print("Agent target set to: ", world_pos)
	else:
		print("Agent target position is not navigable!")

func _set_follower_destination(screen_pos: Vector2):
	if not follower_enabled or not follower: return
	var world_pos = screen_pos
	if _is_position_navigable(world_pos):
		follower.set_target_agent(null) # Manual control
		follower.set_target_position(world_pos)
		print("Follower manual target set to: ", world_pos)
	else:
		print("Follower target position is not navigable!")

func _is_position_navigable(pos: Vector2) -> bool:
	if not navigation_region: return false
	var nav_map = navigation_region.get_navigation_map()
	if not nav_map.is_valid(): return false
	# Check if the closest point on the navmap to 'pos' is very close to 'pos' itself.
	# A small tolerance (e.g., 10-50) can be used. If it's far, 'pos' is likely outside.
	return NavigationServer2D.map_get_closest_point(nav_map, pos).distance_to(pos) < 50.0

func _on_reset_pressed():
	if agent: agent.reset_to_start()
	if follower: follower.reset_to_start()
	if wanderer_agent: wanderer_agent.reset_to_start() # NEW
	
	if follower_enabled and agent and follower:
		follower.set_target_agent(agent)
	
	# Reset wanderer flee state if desired, or let it persist
	# wanderer_flee_active = true # Optional: reset to default
	# if wanderer_agent: wanderer_agent.set_flee_behavior(wanderer_flee_active)

	has_target = false
	if target_marker: target_marker.visible = false
	_update_ui() # Update UI after reset
	print("All agents reset!")

func _on_toggle_dynamic_pressed():
	dynamic_obstacles_moving = !dynamic_obstacles_moving
	for obstacle in dynamic_obstacles:
		if is_instance_valid(obstacle) and obstacle.has_method("set_moving"):
			obstacle.set_moving(dynamic_obstacles_moving)
	toggle_dynamic_button.text = "Dynamic Obstacles: " + ("ON" if dynamic_obstacles_moving else "OFF")
	print("Dynamic obstacles moving: ", dynamic_obstacles_moving)

func _on_toggle_path_pressed():
	show_path = !show_path
	if agent: agent.set_path_visible(show_path)
	if follower: follower.set_path_visible(show_path)
	if wanderer_agent: wanderer_agent.set_path_visible(show_path) # NEW
	toggle_path_button.text = "Show Path: " + ("ON" if show_path else "OFF")
	print("Path visualization: ", show_path)

func _on_toggle_follower_pressed():
	follower_enabled = !follower_enabled
	if follower: follower.visible = follower_enabled
	
	if follower_enabled and agent and follower:
		follower.set_target_agent(agent)
		print("Follower enabled")
	elif follower:
		follower.set_target_agent(null) # Make it idle
		print("Follower disabled")
	toggle_follower_button.text = "Follower: " + ("ON" if follower_enabled else "OFF")

# NEW METHOD for Flee Toggle
func _on_toggle_flee_pressed():
	if not wanderer_agent: return
	wanderer_flee_active = !wanderer_flee_active
	wanderer_agent.set_flee_behavior(wanderer_flee_active)
	toggle_flee_button.text = "Wanderer Flee: " + ("ON" if wanderer_flee_active else "OFF")
	print("Wanderer flee behavior: ", wanderer_flee_active)

func _on_agent_navigation_finished():
	has_target = false
	if target_marker: target_marker.visible = false
	print("Agent reached target!")

func _on_agent_navigation_failed():
	print("Agent failed to reach target!")
	# Potentially clear target marker here too
	# has_target = false
	# if target_marker: target_marker.visible = false

func _on_agent_state_changed(new_state: String):
	_update_ui()

func _on_follower_navigation_finished():
	print("Follower reached target!")
	if follower_enabled and not follower.target_agent and agent and follower: # Was in manual mode
		await get_tree().create_timer(0.5).timeout # Short delay
		follower.set_target_agent(agent)
		print("Follower resuming follow behavior")

func _on_follower_navigation_failed():
	print("Follower failed to reach target!")

func _on_follower_state_changed(new_state: String):
	_update_ui()

# NEW METHOD for Wanderer State
func _on_wanderer_state_changed(new_state: String):
	_update_ui()
	# print("Wanderer state changed in Main: ", new_state) # Optional debug

func _update_ui():
	if agent and agent_state_label:
		agent_state_label.text = "Agent State: " + agent.get_current_state()
	
	if follower and follower_state_label:
		if follower_enabled:
			follower_state_label.text = "Follower State: " + follower.get_current_state()
			if agent:
				follower_distance_label.text = "Dist to Agent: " + str(int(follower.get_distance_to_target()))
			else:
				follower_distance_label.text = "Dist to Agent: N/A"
		else:
			follower_state_label.text = "Follower State: DISABLED"
			follower_distance_label.text = "Dist to Agent: N/A"

	# NEW UI Update for Wanderer
	if wanderer_agent and wanderer_state_label:
		wanderer_state_label.text = "Wanderer State: " + wanderer_agent.get_current_state()
	
	if target_position_label:
		if has_target and current_target:
			target_position_label.text = "Target: (" + str(int(current_target.x)) + ", " + str(int(current_target.y)) + ")"
		else:
			target_position_label.text = "Target: None"
	
	# Update button texts (some are updated in their toggle methods directly for immediate feedback)
	if toggle_dynamic_button: toggle_dynamic_button.text = "Dynamic Obstacles: " + ("ON" if dynamic_obstacles_moving else "OFF")
	if toggle_path_button: toggle_path_button.text = "Show Path: " + ("ON" if show_path else "OFF")
	if toggle_follower_button: toggle_follower_button.text = "Follower: " + ("ON" if follower_enabled else "OFF")
	if toggle_flee_button: toggle_flee_button.text = "Wanderer Flee: " + ("ON" if wanderer_flee_active else "OFF") # NEW

func _process(_delta): # Changed from _physics_process if UI doesn't need physics rate
	_update_ui() # Keep UI updated, especially for distances or dynamic states
