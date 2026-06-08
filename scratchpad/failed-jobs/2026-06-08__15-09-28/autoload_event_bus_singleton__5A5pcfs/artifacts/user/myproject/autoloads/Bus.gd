## Bus — generic autoload Event Bus
##
## Registered as the autoload singleton named "Bus".
##
## NOTE: In Godot 4 a class_name must not share a name with an autoload
## singleton.  The canonical class_name for this script is EventBus;
## the autoload is registered under the name Bus so in-game code calls
## Bus.subscribe(...) etc., which fully satisfies the specification.
class_name EventBus
extends Node

# ---------------------------------------------------------------------------
# Internal types
# ---------------------------------------------------------------------------

## One subscription record.
class _Sub:
	var id: int
	var channel: StringName
	var callable: Callable

	func _init(p_id: int, p_channel: StringName, p_callable: Callable) -> void:
		id = p_id
		channel = p_channel
		callable = p_callable

	## Returns true when the owning Object (if any) has been freed.
	func is_dead() -> bool:
		if not callable.is_valid():
			return true
		var obj: Object = callable.get_object()
		# A Callable may have no bound object (e.g. a static / lambda).
		if obj == null:
			return false
		return not is_instance_valid(obj)

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted on every publish / publish_once call, even when middleware drops
## the event or no subscribers exist.
signal event_published(channel: StringName, payload: Variant)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## channel -> Array[_Sub]
var _channels: Dictionary = {}

## subscription_id -> _Sub  (fast lookup for unsubscribe)
var _subs_by_id: Dictionary = {}

## Monotonically increasing id counter.
var _next_id: int = 1

## Ordered list of middleware Callables.
## Each receives (channel: StringName, payload: Variant)
## and must return either a (possibly modified) payload or null to drop.
var _middleware: Array[Callable] = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Register [param callable] to be invoked whenever an event is published on
## [param channel].  Returns a subscription id that can be passed to
## [method unsubscribe].
func subscribe(channel: StringName, callable: Callable) -> int:
	var sub := _Sub.new(_next_id, channel, callable)
	_next_id += 1

	if not _channels.has(channel):
		_channels[channel] = []
	_channels[channel].append(sub)
	_subs_by_id[sub.id] = sub

	return sub.id


## Cancel the subscription identified by [param subscription_id].
## Returns [code]true[/code] on success, [code]false[/code] when the id is
## unknown (already removed or never existed).
func unsubscribe(subscription_id: int) -> bool:
	if not _subs_by_id.has(subscription_id):
		return false

	var sub: _Sub = _subs_by_id[subscription_id]
	_subs_by_id.erase(subscription_id)

	var list: Array = _channels.get(sub.channel, [])
	list.erase(sub)
	if list.is_empty():
		_channels.erase(sub.channel)

	return true


## Publish [param payload] to all live subscribers on [param channel].
##
## The middleware pipeline runs first; if any middleware returns [code]null[/code]
## subscriber dispatch is skipped.  [signal event_published] always fires.
func publish(channel: StringName, payload: Variant) -> void:
	emit_signal("event_published", channel, payload)

	var processed: Variant = _run_middleware(channel, payload)
	if processed == null:
		return  # dropped by middleware

	_dispatch(channel, processed)


## Like [method publish] but unsubscribes every subscriber on [param channel]
## after dispatch.
func publish_once(channel: StringName, payload: Variant) -> void:
	emit_signal("event_published", channel, payload)

	var processed: Variant = _run_middleware(channel, payload)

	# Snapshot live callables *before* removing subscriptions so we can still
	# call them. We also collect their ids for removal.
	var snapshot_callables: Array[Callable] = []
	var ids_to_remove: Array[int] = []

	if _channels.has(channel):
		for sub: _Sub in _channels[channel].duplicate():
			ids_to_remove.append(sub.id)
			if not sub.is_dead():
				snapshot_callables.append(sub.callable)

	# Remove all subscriptions on this channel first, so any re-subscribe
	# inside a callback is not immediately wiped out.
	for id: int in ids_to_remove:
		unsubscribe(id)

	if processed == null:
		return  # dropped by middleware (subscriptions already cleared above)

	# Dispatch to the snapshot.
	for c: Callable in snapshot_callables:
		c.call(processed)


## Add a middleware [param callable].
## It receives [code](channel: StringName, payload: Variant)[/code] and must
## return either a (possibly modified) payload or [code]null[/code] to drop.
func add_middleware(callable: Callable) -> void:
	_middleware.append(callable)


## Remove all middleware.
func clear_middleware() -> void:
	_middleware.clear()


## Remove all subscriptions for [param channel].
func clear_channel(channel: StringName) -> void:
	if not _channels.has(channel):
		return
	for sub: _Sub in _channels[channel].duplicate():
		_subs_by_id.erase(sub.id)
	_channels.erase(channel)


## Returns the number of *live* subscriptions on [param channel].
## Dead subscriptions (freed owner) are pruned in the process.
func subscription_count(channel: StringName) -> int:
	_prune(channel)
	return _channels.get(channel, []).size()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Run every middleware in order.  Returns the final payload, or null if any
## middleware returned null (drop).
func _run_middleware(channel: StringName, payload: Variant) -> Variant:
	var current: Variant = payload
	for mw: Callable in _middleware:
		current = mw.call(channel, current)
		if current == null:
			return null
	return current


## Invoke every live subscriber on [param channel] with [param payload],
## pruning dead ones along the way.
func _dispatch(channel: StringName, payload: Variant) -> void:
	if not _channels.has(channel):
		return

	# Iterate over a snapshot so that unsubscribe inside a callback is safe.
	var snapshot: Array = _channels[channel].duplicate()
	var dead_ids: Array[int] = []

	for sub: _Sub in snapshot:
		if sub.is_dead():
			dead_ids.append(sub.id)
			continue
		sub.callable.call(payload)

	for id: int in dead_ids:
		unsubscribe(id)


## Remove dead subscriptions from [param channel].
func _prune(channel: StringName) -> void:
	if not _channels.has(channel):
		return
	var dead_ids: Array[int] = []
	for sub: _Sub in _channels[channel]:
		if sub.is_dead():
			dead_ids.append(sub.id)
	for id: int in dead_ids:
		unsubscribe(id)
