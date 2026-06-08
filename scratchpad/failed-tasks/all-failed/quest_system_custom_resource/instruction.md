# Quest Tracking System (Godot 4)

Build a data-driven quest tracking system in the Godot 4 project at
`/home/user/quest_project`. The headless `godot` binary (Godot 4) is
already on `PATH`.

## Criteria

- Custom `Resource` `scripts/QuestObjective.gd` (`class_name
  QuestObjective`) with `@export`s `description: String`, `target_count:
  int`, `current_count: int` (default `0`) and method `is_complete() ->
  bool`.
- Custom `Resource` `scripts/Quest.gd` (`class_name Quest`) with
  `@export`s `id: StringName`, `title: String`, `description: String`,
  `objectives: Array[QuestObjective]`,
  `prerequisite_quest_ids: Array[StringName]`, `reward_gold: int`,
  `reward_items: Array[StringName]`, and methods `is_complete() -> bool`
  and `get_progress() -> float` (range `0.0`..`1.0`).
- Three `.tres` quests under `resources/quests/`: `quest_a.tres`,
  `quest_b.tres` (prerequisite: `quest_a`), `quest_c.tres` (prerequisite:
  `quest_b`). Each quest must contain at least one objective.
- Autoload `QuestManager` registered in `project.godot` as
  `res://autoloads/QuestManager.gd`, exposing:
  - `register_quest(quest: Quest)`
  - `can_start(quest_id: StringName) -> bool` (true iff every
    prerequisite is in `completed_ids`)
  - `start_quest(quest_id: StringName) -> bool` (fails if `can_start` is
    false; otherwise emits `quest_started(id)`)
  - `report_progress(objective_key: StringName, amount: int = 1)` — for
    every active quest, increments `current_count` on each objective
    whose `description` (as `StringName`) matches `objective_key`, capped
    at `target_count`; emits `quest_progress(id, progress)`.
  - `complete_quest(quest_id: StringName) -> bool` — succeeds only when
    `quest.is_complete()`; on success emits `quest_completed(id,
    reward_gold, reward_items)` and records the quest in `completed_ids`.
  - Signals: `quest_started(id)`, `quest_progress(id, progress)`,
    `quest_completed(id, reward_gold, reward_items)`.

Verification injects a harness scene into the project and runs `godot
--headless --path /home/user/quest_project res://__verify__/run.tscn`.
