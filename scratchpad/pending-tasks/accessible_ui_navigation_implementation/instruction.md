You are developing a complex settings menu for a SaaS tool built in Godot. The menu must be fully accessible via both mouse clicks and keyboard/gamepad focus navigation.

You need to construct a UI script that manages a `GridContainer` populated with multiple `Button` nodes. The script must programmatically assign the focus neighbors (`focus_neighbor_left`, `focus_neighbor_right`, etc.) for every button in the grid so that directional input smoothly wraps around the edges of the grid (e.g., pressing right on the last item of a row focuses the first item of that row).

**Constraints:**
- You MUST dynamically calculate and assign the focus properties via script based on the `GridContainer`'s columns and child count.
- Do NOT hardcode the paths or names of specific buttons.
- The script must handle edge cases, such as an incomplete bottom row in the grid.