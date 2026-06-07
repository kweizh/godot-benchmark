You are building a simple platformer prototype where a player moves around and collects coins.

You need to write a GDScript for a `CharacterBody2D` that handles basic left/right movement, jumping, and gravity. Additionally, you must implement a function to connect to an `Area2D`'s `body_entered` signal dynamically via code to increment a local score variable when the player touches a coin.

**Constraints:**
- You MUST use Godot 4 signal syntax (e.g., `signal_name.connect(callable)`).
- You MUST use standard 2D physics methods like `move_and_slide()` and `is_on_floor()`.
- Do NOT use the editor UI to connect the signal; it must be done entirely in script.