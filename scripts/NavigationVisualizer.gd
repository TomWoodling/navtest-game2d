extends Polygon2D

# This script visualizes the navigation region
func _ready():
	# Set semi-transparent green for navigable area
	color = Color(0.0, 1.0, 0.0, 0.3)
	
	# Get the navigation polygon from parent NavigationRegion2D
	var nav_region = get_parent() as NavigationRegion2D
	if nav_region and nav_region.navigation_polygon:
		polygon = nav_region.navigation_polygon.get_outline(0)
