You are tasked with migrating a legacy Godot 3 script to Godot 4. The old script relies on an outdated `Tween` node to animate a UI panel's appearance.

You need to rewrite the animation logic to use Godot 4's built-in `create_tween()` method. The script must animate the UI Control's `scale` property from `Vector2(0, 0)` to `Vector2(1, 1)` over a duration of 0.5 seconds, applying an ease-out transition.

**Constraints:**
- Do NOT use or reference a `Tween` node in the scene tree.
- You MUST use `tween_property()` to execute the animation.
- The script must be fully compatible with Godot 4's SceneTreeTween API.