You are debugging a project that fails to load due to a cyclical reference error. `Player.gd` and `Weapon.gd` strongly type reference each other using `class_name` (e.g., the Player script has a variable typed as `Weapon`, and the Weapon script has a variable typed as `Player`).

You need to refactor both scripts to successfully resolve the circular dependency while maintaining the ability for the `Weapon` to call a `take_damage()` method on the `Player`, and the `Player` to access the `Weapon`'s `damage` property.

**Constraints:**
- Both files MUST remain written in GDScript.
- You cannot combine both classes into a single file.
- The resulting code must compile and run without throwing parse errors or cyclic dependency warnings.