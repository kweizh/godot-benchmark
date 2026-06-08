extends Node

## Emitted on every publish/publish_once call regardless of middleware (including drops).
signal event_published(channel: StringName, payload: Variant)

## Internal subscription data.
var _next_id: int = 1
var _subscriptions: Dictionary = {}          # channel (StringName) -> Array[Dictionary]
var _id_to_channel: Dictionary = {}           # subscription_id -> StringName
var _middleware: Array[Callable] = []          # ordered middleware chain

## Subscribe a callable to a channel. Returns a subscription id.
## Multiple subscribers per channel are allowed.
func subscribe(channel: StringName, callable: Callable) -> int:
	var sub_id: int = _next_id
	_next_id += 1

	if not _subscriptions.has(channel):
		_subscriptions[channel] = []
	_subscriptions[channel].append({
		"id": sub_id,
		"callable": callable,
	})
	_id_to_channel[sub_id] = channel
	return sub_id

## Unsubscribe by subscription id. Returns true if found and removed.
func unsubscribe(subscription_id: int) -> bool:
	if not _id_to_channel.has(subscription_id):
		return false

	var channel: StringName = _id_to_channel[subscription_id]
	_id_to_channel.erase(subscription_id)

	var subs: Array = _subscriptions[channel]
	for i in range(subs.size()):
		if subs[i]["id"] == subscription_id:
			subs.remove_at(i)
			break

	if subs.is_empty():
		_subscriptions.erase(channel)

	return true

## Publish a payload to all subscribers on the given channel.
## Middleware runs before dispatch. If middleware returns null, the event is
## dropped (subscribers are NOT invoked), but event_published still fires.
func publish(channel: StringName, payload: Variant) -> void:
	# Always emit event_published, even if the event will be dropped.
	event_published.emit(channel, payload)

	# Run middleware chain.
	var current_payload: Variant = payload
	for mw: Callable in _middleware:
		var result: Variant = mw.call(channel, current_payload)
		if result == null:
			# Middleware dropped the event — do not dispatch to subscribers.
			return
		current_payload = result

	_dispatch(channel, current_payload)

## Publish once, then unsubscribe every subscriber on that channel.
func publish_once(channel: StringName, payload: Variant) -> void:
	# Always emit event_published, even if the event will be dropped.
	event_published.emit(channel, payload)

	# Run middleware chain.
	var current_payload: Variant = payload
	for mw: Callable in _middleware:
		var result: Variant = mw.call(channel, current_payload)
		if result == null:
			# Middleware dropped the event — still clear the channel.
			clear_channel(channel)
			return
		current_payload = result

	_dispatch(channel, current_payload)
	clear_channel(channel)

## Add a middleware callable. Middleware receives (channel, payload) and
## returns either a (possibly modified) payload, or null to drop the event.
func add_middleware(callable: Callable) -> void:
	_middleware.append(callable)

## Remove all middleware.
func clear_middleware() -> void:
	_middleware.clear()

## Remove all subscriptions on a specific channel.
func clear_channel(channel: StringName) -> void:
	if _subscriptions.has(channel):
		for sub: Dictionary in _subscriptions[channel]:
			_id_to_channel.erase(sub["id"])
		_subscriptions.erase(channel)

## Return the number of subscribers on a channel.
func subscription_count(channel: StringName) -> int:
	if not _subscriptions.has(channel):
		return 0
	return _subscriptions[channel].size()

## Internal: dispatch payload to all live subscribers on channel.
## Auto-prunes subscriptions whose target Object has been freed.
func _dispatch(channel: StringName, payload: Variant) -> void:
	if not _subscriptions.has(channel):
		return

	var subs: Array = _subscriptions[channel]
	var to_remove: Array[int] = []

	for i in range(subs.size()):
		var sub: Dictionary = subs[i]
		var callable: Callable = sub["callable"]

		# If the callable's target is a freed Object, mark for pruning.
		var obj: Object = callable.get_object() as Object
		if obj == null or not is_instance_valid(obj):
			to_remove.append(i)
			continue

		callable.call(payload)

	# Remove pruned subscriptions in reverse order to keep indices valid.
	for idx: int in to_remove:
		var removed_sub: Dictionary = subs[idx]
		_id_to_channel.erase(removed_sub["id"])
		subs.remove_at(idx)

	if subs.is_empty():
		_subscriptions.erase(channel)