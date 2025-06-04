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
