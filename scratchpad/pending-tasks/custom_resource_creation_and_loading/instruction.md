You are designing a data-driven system for defining different enemy types without duplicating scene nodes.

You need to create a custom GDScript `Resource` named `EnemyStats` that defines exported properties for an enemy's name (String), health (int), and speed (float). Following this, write a separate spawner script that exports an array of `EnemyStats` resources and iterates through them on `_ready()`, printing each enemy's name to the console.

**Constraints:**
- The custom resource MUST use the `class_name EnemyStats` declaration.
- You MUST use the `@export` annotation to expose the variables to the inspector.
- Do NOT instantiate any physical nodes in the spawner script; only handle the resource data.