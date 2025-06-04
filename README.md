# Godot 4.2+ 2D Navigation Testbed

This project is a testbed for exploring and demonstrating 2D navigation features in Godot Engine (version 4.2 and newer). It showcases basic agent movement, pathfinding, dynamic obstacle avoidance, a follower agent, and a wandering NPC-like agent with flee behavior.

## Features

*   **Main Agent Control:**
    *   Click to set a destination for the main agent.
    *   Visual path rendering (toggleable).
    *   Agent rotates to face its movement direction.
    *   Stuck detection: If the agent fails to make progress, its state changes to "STUCK".
*   **Follower Agent:**
    *   A second agent that attempts to follow the main agent, maintaining a set distance.
    *   Also visualizes its path and has stuck detection.
    *   Can be toggled on/off.
    *   Can be given a manual destination with a right-click, temporarily overriding follow behavior.
*   **Wanderer Agent (NPC/Guard):**
    *   An autonomous agent that wanders pseudo-randomly around the navigable area.
    *   **Flee Behavior:** Can be configured to flee from the main agent or the follower if they come within a defined trigger radius.
        *   After fleeing, it enters a cooldown period before resuming wandering.
        *   Flee behavior can be toggled on/off.
    *   Visualizes its path and has stuck detection.
    *   Utilizes `NavigationServer2D.map_changed` signal to ensure navigation map is ready before pathfinding.
*   **Dynamic Obstacles:**
    *   Obstacles that move along predefined paths (horizontal or vertical).
    *   Agents with `NavigationAgent2D.avoidance_enabled = true` will attempt to navigate around them.
    *   Movement of dynamic obstacles can be toggled on/off.
*   **Static Obstacles:**
    *   Non-moving obstacles that carve out the navigation mesh.
*   **Navigation Region Visualization:**
    *   The `NavigationRegion2D`'s navigable area is visualized with a semi-transparent overlay.
*   **UI Controls & Info:**
    *   Labels displaying the current state of the Main Agent, Follower, and Wanderer.
    *   Label displaying the distance between the Follower and the Main Agent.
    *   Label displaying the Main Agent's current target position.
    *   Buttons to:
        *   Reset all agents to their starting positions.
        *   Toggle the movement of dynamic obstacles.
        *   Toggle the visibility of navigation paths.
        *   Toggle the Follower agent's active state.
        *   Toggle the Wanderer agent's flee behavior.
*   **Keyboard Shortcuts:**
    *   **Left Mouse Click:** Set destination for the Main Agent.
    *   **Right Mouse Click:** Set manual destination for the Follower Agent.
    *   **R:** Reset all agents.
    *   **P:** Toggle path visualization.
    *   **F:** Toggle Follower agent.
    *   **D:** Toggle dynamic obstacles movement (Note: previously Space).
    *   **G:** Toggle Wanderer agent's flee behavior.

## Scene Structure Overview

*   **Main:** The root node containing all elements, UI, and main game logic.
*   **NavigationRegion2D:** Defines the walkable area for agents.
    *   **NavigationVisualizer:** A `Polygon2D` child that draws the navigation mesh.
    *   **StaticObstacle(s):** `StaticBody2D` nodes with `NavigationObstacle2D` that are part of the baked navigation mesh.
*   **Agent:** A `CharacterBody2D` representing the player-controlled agent.
    *   `NavigationAgent2D`: Handles pathfinding requests.
    *   `Sprite2D`: Visual representation.
    *   `Line2D`: Draws the current path.
*   **Follower:** A `CharacterBody2D` similar to Agent, but with logic to follow another agent.
    *   `NavigationAgent2D`, `Sprite2D`, `Line2D`.
*   **Wanderer:** A `CharacterBody2D` with autonomous wandering and flee behaviors.
    *   `NavigationAgent2D`, `Sprite2D`, `Line2D`.
*   **DynamicObstacle(s):** `CharacterBody2D` nodes that move and have a `NavigationObstacle2D` component, forcing agents to re-route.
*   **TargetMarker:** A `Sprite2D` to visualize the main agent's current destination.
*   **UI:** CanvasLayer with VBoxContainer for labels and buttons.

## Scripts

*   **`Main.gd`:** Manages the overall scene, UI interactions, agent spawning/setup, and input handling.
*   **`Agent.gd`:** Logic for the main controllable agent, including movement, path request, state changes, and stuck detection.
*   **`Follower.gd`:** Logic for the follower agent, including targeting the main agent, maintaining distance, pathfinding, and state management.
*   **`Wanderer.gd`:** Logic for the autonomous wandering agent, including random point selection, flee behavior from threats, state management, and handling `NavigationServer2D.map_changed`.
*   **`DynamicObstacle.gd`:** Controls the movement of dynamic obstacles.
*   **`StaticObstacle.gd`:** Basic setup for static obstacle visuals (logic is mainly in its `NavigationObstacle2D` node).
*   **`NavigationVisualizer.gd`:** Draws the outline of the parent `NavigationRegion2D`'s polygon.

## How to Use

1.  Open the project in Godot Engine (4.2 or newer).
2.  Run the `Main.tscn` scene.
3.  Interact using the mouse and keyboard shortcuts listed above.
4.  Observe agent behaviors and pathfinding around static and dynamic obstacles.

## Future Exploration / Potential Improvements

*   More complex agent behaviors (patrolling specific routes for wanderer, chasing).
*   Group behaviors.
*   Performance testing with many agents.
*   Different navigation mesh update strategies (e.g., real-time updates vs. baking).
*   Integration with tilemaps for navigation.

This project serves as a foundational example for building more complex navigation-based gameplay.
