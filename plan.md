# Godot Engine Evaluation Dataset Research

### 1. Library Overview
*   **Description**: Godot Engine is a free, open-source, cross-platform 2D and 3D game engine. It features a unique node-and-scene architecture, a dedicated Python-like scripting language (GDScript), and support for C# and C++ (via GDExtension).
*   **Ecosystem Role**: A major competitor to Unity and Unreal Engine, favored for its lightweight nature, permissive MIT license, and excellent 2D capabilities. It is increasingly used for 3D games and non-game applications (tools, simulators).
*   **Project Setup**:
    1.  **Download**: Godot is a single executable. No installation required.
    2.  **Initialize**: Create a new folder and a `project.godot` file (automatically done via the Project Manager).
    3.  **CLI**: 
        *   Open editor: `godot -e`
        *   Run project: `godot`
        *   Export: `godot --export-release "Linux/X11" path/to/export`
    4.  **Structure**: Standard practice uses `res://` as the root. Common folders: `scenes/`, `scripts/`, `assets/`, `prefabs/`.

### 2. Core Primitives & APIs

*   **Nodes & Scenes**: Everything is a Node. Nodes are organized into Scenes. Scenes can be instanced within other scenes.
    *   [Nodes and Scenes Docs](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html)
*   **GDScript**: A high-level, dynamically typed language optimized for Godot.
    *   [GDScript Basics](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)
    *   **Snippet (Basic Player)**:
        ```gdscript
        extends CharacterBody2D

        @export var speed = 300.0
        @export var jump_velocity = -400.0

        func _physics_process(delta):
            # Add gravity
            if not is_on_floor():
                velocity += get_gravity() * delta

            # Handle Jump
            if Input.is_action_just_pressed("ui_accept") and is_on_floor():
                velocity.y = jump_velocity

            # Get input direction
            var direction = Input.get_axis("ui_left", "ui_right")
            if direction:
                velocity.x = direction * speed
            else:
                velocity.x = move_toward(velocity.x, 0, speed)

            move_and_slide()
        ```
*   **Signals**: The Observer pattern implementation. Used for decoupled communication.
    *   [Using Signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html)
    *   **Snippet (Connecting via Code)**:
        ```gdscript
        func _ready():
            var timer = get_node("Timer")
            timer.timeout.connect(_on_timer_timeout)

        func _on_timer_timeout():
            print("Timer finished!")
        ```
*   **Resources**: Data containers (e.g., Textures, Scripts, custom data).
    *   [Resources Docs](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)
    *   **Snippet (Custom Resource)**:
        ```gdscript
        # item_data.gd
        extends Resource
        class_name ItemData

        @export var name: String
        @export var icon: Texture2D
        @export var damage: int
        ```
*   **Networking**: High-level multiplayer API using RPCs and Synchronizers.
    *   [Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
    *   **Snippet (RPC)**:
        ```gdscript
        @rpc("any_peer", "call_local")
        func update_score(value):
            score += value
        ```
*   **GDExtension (C++)**: High-performance extension system without recompiling the engine.
    *   [GDExtension Docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/gdextension_cpp_example.html)
    *   **Key Concept**: Requires a `.gdextension` config file to map shared libraries to platforms.

### 3. Real-World Use Cases & Templates
*   **SaaS/Tool UI**: Using `Control` nodes, `GridContainer`, and `Theme` for complex editors.
*   **Multiplayer FPS/Platformer**: Utilizing `MultiplayerSynchronizer` for state and `MultiplayerSpawner` for dynamic entities.
*   **Procedural Generation**: Using `TileMapLayer` and `FastNoiseLite` for infinite worlds.
*   **Official Demos**: [Godot Demo Projects Repository](https://github.com/godotengine/godot-demo-projects).

### 4. Developer Friction Points
*   **Circular Dependencies**: GDScript can fail to load scripts if they reference each other in a loop (e.g., `A.gd` uses `B.gd` and vice versa). [Issue Discussion](https://github.com/godotengine/godot/issues/78040).
*   **Tween API Changes**: Migration from Godot 3 `Tween` node to Godot 4 `create_tween()` method is a frequent source of confusion.
*   **GDExtension Setup**: The boilerplate for C++ (SCons, godot-cpp, registration macros) is significantly steeper than GDScript.
*   **NavigationServer**: Handling dynamic obstacles with `NavigationAgent` and `NavigationRegion` often requires complex setup of baking/avoidance layers.

### 5. Evaluation Ideas
*   **Basic**: Implement a "Coin Collector" logic where a player (CharacterBody2D) collects items (Area2D) and updates a UI label.
*   **Intermediate**: Create a custom `Resource` for "Enemy Stats" and a system that loads these resources to spawn different enemy types.
*   **Intermediate**: Build a nested UI menu that supports both mouse clicking and keyboard/gamepad focus navigation.
*   **Advanced**: Implement a "Dissolve" shader effect using `VisualShader` or GDShader code that triggers when an enemy dies.
*   **Advanced**: Set up a basic client-server lobby where players can join, and their positions are synced using `MultiplayerSynchronizer`.
*   **Advanced**: Refactor a GDScript-based heavy calculation (e.g., pathfinding or mesh generation) into a GDExtension C++ class.

### 6. Sources
1. [Godot Official Documentation](https://docs.godotengine.org/en/stable/) - Primary source for all API details.
2. [Godot 4.6 branch index](https://docs.godotengine.org/en/stable/index.html) - Documentation root.
3. [GDScript Basics](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) - Language reference.
4. [GDExtension C++ Example](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/gdextension_cpp_example.html) - C++ integration guide.
5. [High-level Multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) - Networking API.
6. [Godot GitHub Issues](https://github.com/godotengine/godot/issues) - Source for friction points and bugs.
7. [GDQuest Tutorials](https://www.gdquest.com/) - Best practices for signals and architecture.