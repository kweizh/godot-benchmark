# Godot 4 Autoload Event Bus

Build a generic autoload Event Bus with namespaced subscriptions and signal middleware.

## Acceptance Criteria

- Project path: `/home/user/myproject`.
- The project boots cleanly under `godot --headless`.
- An autoload named `Bus` is registered in `project.godot` and resolves to `res://autoloads/Bus.gd`. The script declares `class_name Bus`.
- The `Bus` autoload exposes:
  - `subscribe(channel: StringName, callable: Callable) -> int` — returns a subscription id; multiple subscribers per channel are allowed.
  - `unsubscribe(subscription_id: int) -> bool`.
  - `publish(channel: StringName, payload: Variant)` — invokes every subscriber on `channel` with the payload.
  - `publish_once(channel: StringName, payload: Variant)` — dispatches, then unsubscribes every subscriber on that channel.
  - `add_middleware(callable: Callable)` — middleware receives `(channel, payload)` and returns either a (possibly modified) payload, or `null` to drop the event. Runs before subscriber dispatch.
  - `clear_middleware()`, `clear_channel(channel: StringName)`.
  - `subscription_count(channel: StringName) -> int` helper.
- Signal `event_published(channel, payload)` is emitted on every publish/publish_once call regardless of middleware (including drops).
- Subscribing twice to a channel and publishing a payload invokes both subscribers with that payload.
- After unsubscribing one, publishing on the same channel invokes only the remaining subscriber.
- `publish_once` with two subscribers invokes both once; a subsequent publish invokes neither.
- Middleware returning `null` drops subscriber dispatch, but `event_published` still fires.
- Middleware returning a modified payload reaches subscribers with the modified payload.
- Subscribing a `Callable` bound to an `Object`, then freeing that `Object`, then publishing on the channel must not crash, and the subscription must be auto-pruned (verifiable via `subscription_count`).
