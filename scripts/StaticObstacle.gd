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
