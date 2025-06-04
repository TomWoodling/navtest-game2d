# Godot 2D Navigation Testbed Project

This is a complete Godot Engine project that creates an interactive 2D navigation testbed for testing pathfinding mechanics.

## Project Structure

```
NavigationTestbed/
├── project.godot
├── scenes/
│   ├── Main.tscn
│   ├── Agent.tscn
│   ├── StaticObstacle.tscn
│   └── DynamicObstacle.tscn
└── scripts/
    ├── Main.gd
    ├── Agent.gd
    ├── StaticObstacle.gd
    ├── DynamicObstacle.gd
    └── NavigationVisualizer.gd
```

## File Contents

### project.godot
```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="2D Navigation Testbed"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.2")

[display]

window/size/viewport_width=1024
window/size/viewport_height=768
window/size/resizable=true

[input]

ui_reset={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":82,"physical_keycode":0,"key_label":0,"unicode":114,"echo":false,"script":null)]
}

ui_toggle_path={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":80,"physical_keycode":0,"key_label":0,"unicode":112,"echo":false,"script":null)]
}

ui_toggle_dynamic={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":32,"echo":false,"script":null)]
}

[rendering]

renderer/rendering_method="gl_compatibility"
```

### scripts/Main.gd
```gdscript
extends Node2D

# UI References
@onready var agent_state_label: Label = $UI/VBoxContainer/AgentStateLabel
@onready var reset_button: Button = $UI/VBoxContainer/ResetButton
@onready var toggle_dynamic_button: Button = $UI/VBoxContainer/ToggleDynamicButton
@onready var toggle_path_button: Button = $UI/VBoxContainer/TogglePathButton
@onready var target_position_label: Label = $UI/VBoxContainer/TargetPositionLabel

# Game Objects
@onready var agent: CharacterBody2D = $Agent
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D
@onready var target_marker: Sprite2D = $TargetMarker

# Dynamic obstacles array
var dynamic_obstacles: Array[Node2D] = []
var dynamic_obstacles_moving: bool = false
var show_path: bool = true

# Target management
var current_target: Vector2
var has_target: bool = false

func _ready():
	# Setup UI connections
	reset_button.pressed.connect(_on_reset_pressed)
	toggle_dynamic_button.pressed.connect(_on_toggle_dynamic_pressed)
	toggle_path_button.pressed.connect(_on_toggle_path_pressed)
	
	# Setup agent connections
	agent.navigation_finished.connect(_on_agent_navigation_finished)
	agent.navigation_failed.connect(_on_agent_navigation_failed)
	agent.state_changed.connect(_on_agent_state_changed)
	
	# Find all dynamic obstacles
	_find_dynamic_obstacles()
	
	# Initialize UI
	_update_ui()
	target_marker.visible = false
	
	print("Navigation Testbed Ready!")
	print("Controls:")
	print("- Left Click: Set destination")
	print("- R: Reset agent")
	print("- P: Toggle path visualization")
	print("- Space: Toggle dynamic obstacles")

func _find_dynamic_obstacles():
	dynamic_obstacles.clear()
	for child in get_children():
		if child.has_method("set_moving"):
			dynamic_obstacles.append(child)

func _input(event):
	# Handle mouse clicks for setting destination
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_agent_destination(event.position)
	
	# Handle keyboard shortcuts
	if event.is_action_pressed("ui_reset"):
		_on_reset_pressed()
	elif event.is_action_pressed("ui_toggle_path"):
		_on_toggle_path_pressed()
	elif event.is_action_pressed("ui_toggle_dynamic"):
		_on_toggle_dynamic_pressed()

func _set_agent_destination(screen_pos: Vector2):
	# Convert screen position to world position
	var world_pos = screen_pos
	
	# Check if position is within navigation region
	if _is_position_navigable(world_pos):
		current_target = world_pos
		has_target = true
		
		# Update target marker
		target_marker.position = world_pos
		target_marker.visible = true
		
		# Send target to agent
		agent.set_target_position(world_pos)
		
		print("Target set to: ", world_pos)
	else:
		print("Target position is not navigable!")

func _is_position_navigable(pos: Vector2) -> bool:
	# Simple check - in a real project you might want more sophisticated validation
	var nav_map = navigation_region.get_navigation_map()
	return NavigationServer2D.map_get_closest_point(nav_map, pos).distance_to(pos) < 50.0

func _on_reset_pressed():
	# Reset agent to starting position
	agent.reset_to_start()
	has_target = false
	target_marker.visible = false
	print("Agent reset!")

func _on_toggle_dynamic_pressed():
	dynamic_obstacles_moving = !dynamic_obstacles_moving
	for obstacle in dynamic_obstacles:
		obstacle.set_moving(dynamic_obstacles_moving)
	print("Dynamic obstacles moving: ", dynamic_obstacles_moving)

func _on_toggle_path_pressed():
	show_path = !show_path
	agent.set_path_visible(show_path)
	print("Path visualization: ", show_path)

func _on_agent_navigation_finished():
	has_target = false
	target_marker.visible = false
	print("Agent reached target!")

func _on_agent_navigation_failed():
	print("Agent failed to reach target!")

func _on_agent_state_changed(new_state: String):
	_update_ui()

func _update_ui():
	# Update agent state
	agent_state_label.text = "Agent State: " + agent.get_current_state()
	
	# Update target position
	if has_target:
		target_position_label.text = "Target: (" + str(int(current_target.x)) + ", " + str(int(current_target.y)) + ")"
	else:
		target_position_label.text = "Target: None"
	
	# Update button states
	toggle_dynamic_button.text = "Dynamic Obstacles: " + ("ON" if dynamic_obstacles_moving else "OFF")
	toggle_path_button.text = "Show Path: " + ("ON" if show_path else "OFF")
```

### scripts/Agent.gd
```gdscript
extends CharacterBody2D

signal navigation_finished
signal navigation_failed
signal state_changed(new_state: String)

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var path_line: Line2D = $PathLine

# Agent properties
var speed: float = 200.0
var start_position: Vector2
var current_state: String = "IDLE"

# Navigation state
var target_reached: bool = false
var stuck_timer: float = 0.0
var stuck_threshold: float = 3.0
var last_position: Vector2
var stuck_check_timer: float = 0.0

func _ready():
	# Store starting position
	start_position = global_position
	
	# Setup navigation agent
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
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
	# Create a simple triangle sprite pointing right
	var texture = ImageTexture.new()
	var image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)
	
	# Simple approach: create a colored rectangle
	texture.set_image(image)
	sprite.texture = texture

func _setup_path_line():
	path_line.width = 3.0
	path_line.default_color = Color.YELLOW
	path_line.visible = true

func _physics_process(delta):
	match current_state:
		"MOVING":
			_handle_movement(delta)
			_check_if_stuck(delta)
		"IDLE":
			pass
		"TARGET_REACHED":
			pass
		"STUCK":
			pass

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

func set_target_position(target: Vector2):
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

func _change_state(new_state: String):
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)
		print("Agent state changed to: ", new_state)

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
	_change_state("TARGET_REACHED")
	navigation_finished.emit()

func _on_target_reached():
	_change_state("TARGET_REACHED")
	navigation_finished.emit()

func _on_waypoint_reached(details: Dictionary):
	print("Waypoint reached: ", details)
```

### scripts/StaticObstacle.gd
```gdscript
extends StaticBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	_setup_visual()

func _setup_visual():
	# Create a simple colored rectangle
	var texture = ImageTexture.new()
	var image = Image.create(50, 50, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	
	texture.set_image(image)
	sprite.texture = texture
	
	# Setup collision shape
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 50)
	collision_shape.shape = shape
```

### scripts/DynamicObstacle.gd
```gdscript
extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var navigation_obstacle: NavigationObstacle2D = $NavigationObstacle2D

# Movement properties
var move_speed: float = 100.0
var move_distance: float = 200.0
var start_position: Vector2
var target_position: Vector2
var moving: bool = false
var move_direction: int = 1  # 1 for right/up, -1 for left/down
var movement_axis: String = "horizontal"  # "horizontal" or "vertical"

func _ready():
	start_position = global_position
	_setup_visual()
	_setup_movement()

func _setup_visual():
	# Create a simple colored circle
	var texture = ImageTexture.new()
	var image = Image.create(40, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.ORANGE)
	
	texture.set_image(image)
	sprite.texture = texture
	
	# Setup collision shape
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision_shape.shape = shape

func _setup_movement():
	# Set up patrol path based on position
	if randf() > 0.5:
		movement_axis = "vertical"
	
	_calculate_target_position()

func _calculate_target_position():
	if movement_axis == "horizontal":
		target_position = start_position + Vector2(move_distance * move_direction, 0)
	else:
		target_position = start_position + Vector2(0, move_distance * move_direction)

func _physics_process(delta):
	if not moving:
		return
	
	# Move towards target
	var direction = (target_position - global_position).normalized()
	velocity = direction * move_speed
	
	move_and_slide()
	
	# Check if reached target
	if global_position.distance_to(target_position) < 10.0:
		# Reverse direction
		move_direction *= -1
		_calculate_target_position()

func set_moving(should_move: bool):
	moving = should_move
	if not moving:
		velocity = Vector2.ZERO
```

### scripts/NavigationVisualizer.gd
```gdscript
extends Polygon2D

# This script visualizes the navigation region
func _ready():
	# Set semi-transparent green for navigable area
	color = Color(0.0, 1.0, 0.0, 0.3)
	
	# Get the navigation polygon from parent NavigationRegion2D
	var nav_region = get_parent() as NavigationRegion2D
	if nav_region and nav_region.navigation_polygon:
		polygon = nav_region.navigation_polygon.get_outline(0)
```

## Scene Setup Instructions

### Main.tscn Scene Structure:
```
Main (Node2D) [Main.gd]
├── NavigationRegion2D
│   ├── NavigationPolygonInstance
│   └── NavigationVisualizer (Polygon2D) [NavigationVisualizer.gd]
├── Agent (CharacterBody2D) [Agent.gd]
│   ├── NavigationAgent2D
│   ├── Sprite2D
│   ├── CollisionShape2D
│   └── PathLine (Line2D)
├── StaticObstacle1 (StaticBody2D) [StaticObstacle.gd]
│   ├── Sprite2D
│   └── CollisionShape2D
├── StaticObstacle2 (StaticBody2D) [StaticObstacle.gd]
│   ├── Sprite2D
│   └── CollisionShape2D
├── DynamicObstacle1 (CharacterBody2D) [DynamicObstacle.gd]
│   ├── NavigationObstacle2D
│   ├── Sprite2D
│   └── CollisionShape2D
├── DynamicObstacle2 (CharacterBody2D) [DynamicObstacle.gd]
│   ├── NavigationObstacle2D
│   ├── Sprite2D
│   └── CollisionShape2D
├── TargetMarker (Sprite2D)
└── UI (CanvasLayer)
    └── VBoxContainer
        ├── AgentStateLabel (Label)
        ├── TargetPositionLabel (Label)
        ├── ResetButton (Button)
        ├── ToggleDynamicButton (Button)
        └── TogglePathButton (Button)
```

## Setup Instructions

1. **Create New Godot Project**: Create a new 2D project in Godot 4.2+

2. **Create File Structure**: Set up the folders and files as shown above

3. **Configure Navigation Region**:
   - Add NavigationRegion2D node
   - Create a NavigationPolygon resource
   - Draw a large polygon covering most of the screen (leave space for obstacles)
   - Ensure the polygon is convex or properly handles concave areas

4. **Place Obstacles**:
   - Position static obstacles within the navigable area
   - Position dynamic obstacles with some space to patrol
   - Ensure obstacles are not overlapping the navigation polygon edges

5. **Configure Agent**:
   - Set NavigationAgent2D properties (path_desired_distance, target_desired_distance)
   - Position agent at a clear starting location

6. **Setup UI**:
   - Create UI elements in a CanvasLayer
   - Position them appropriately (top-left corner works well)

7. **Export Settings**:
   - Go to Project > Export
   - Add HTML5 export template
   - Configure for web deployment

## Controls

- **Left Mouse Click**: Set agent destination
- **R Key**: Reset agent to starting position
- **P Key**: Toggle path visualization
- **Space Key**: Toggle dynamic obstacle movement
- **UI Buttons**: Alternative to keyboard controls

## Features Demonstrated

✅ **Core Navigation**: NavigationAgent2D pathfinding with NavigationRegion2D
✅ **Static Obstacles**: StaticBody2D obstacles that block pathfinding
✅ **Dynamic Obstacles**: Moving obstacles with NavigationObstacle2D
✅ **Path Visualization**: Real-time display of agent's planned path
✅ **Interactive Controls**: Mouse and keyboard input handling
✅ **State Management**: Clear agent state tracking and display
✅ **Visual Feedback**: Distinct colors for different element types
✅ **Stuck Detection**: Agent detects when it can't reach target

This testbed provides a comprehensive demonstration of Godot's 2D navigation system with clean, readable code and interactive testing capabilities.