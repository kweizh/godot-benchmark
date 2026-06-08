extends Node

## Emitted on every publish/publish_once call, regardless of middleware drops.
signal event_published(channel: StringName, payload: Variant)

## Internal counter for generating unique subscription IDs.
var _next_id := 0

## Maps subscription_id -> { channel: StringName, callable: Callable }
var _subscriptions := {}

## Maps channel -> Array[subscription_id]
var _channel_index := {}

## Ordered list of middleware Callables.
var _middlewares: Array[Callable] = []


func subscribe(channel: StringName, callable: Callable) -> int:
	_next_id += 1
	var sid := _next_id
	_subscriptions[sid] = { "channel": channel, "callable": callable }
	if not _channel_index.has(channel):
		_channel_index[channel] = []
	_channel_index[channel].push_back(sid)
	return sid


func unsubscribe(subscription_id: int) -> bool:
	if not _subscriptions.has(subscription_id):
		return false
	var entry = _subscriptions[subscription_id]
	var channel: StringName = entry["channel"]
	_subscriptions.erase(subscription_id)
	if _channel_index.has(channel):
		_channel_index[channel].erase(subscription_id)
		if _channel_index[channel].is_empty():
			_channel_index.erase(channel)
	return true


func publish(channel: StringName, payload: Variant) -> void:
	event_published.emit(channel, payload)

	if not _channel_index.has(channel):
		return

	# Snapshot IDs to safely iterate even if a subscriber unsubscribes during dispatch.
	var ids: Array = _channel_index[channel].duplicate()
	var final_payload = _run_middleware(channel, payload)
	if final_payload == null:
		# Middleware dropped the event — do not dispatch to subscribers.
		return

	for sid: int in ids:
		if not _subscriptions.has(sid):
			# Subscription was removed (e.g. unsubscribed during iteration, or object freed).
			continue
		var callable: Callable = _subscriptions[sid]["callable"]
		if not _is_callable_valid(callable):
			_unsubscribe_internal(sid)
			continue
		callable.call(final_payload)


func publish_once(channel: StringName, payload: Variant) -> void:
	event_published.emit(channel, payload)

	if not _channel_index.has(channel):
		return

	var ids: Array = _channel_index[channel].duplicate()
	var final_payload = _run_middleware(channel, payload)
	if final_payload == null:
		# Middleware dropped the event; still unsub all subscribers on this channel.
		for sid: int in ids:
			_unsubscribe_internal(sid)
		return

	for sid: int in ids:
		if not _subscriptions.has(sid):
			continue
		var callable: Callable = _subscriptions[sid]["callable"]
		if not _is_callable_valid(callable):
			_unsubscribe_internal(sid)
			continue
		callable.call(final_payload)
		_unsubscribe_internal(sid)


func add_middleware(callable: Callable) -> void:
	_middlewares.push_back(callable)


func clear_middleware() -> void:
	_middlewares.clear()


func clear_channel(channel: StringName) -> void:
	if not _channel_index.has(channel):
		return
	var ids: Array = _channel_index[channel].duplicate()
	for sid: int in ids:
		_unsubscribe_internal(sid)


func subscription_count(channel: StringName) -> int:
	if not _channel_index.has(channel):
		return 0
	return _channel_index[channel].size()


## Runs the payload through all middleware in order.
## Returns the (possibly modified) payload, or null to drop the event.
func _run_middleware(channel: StringName, payload: Variant) -> Variant:
	var result = payload
	for mw: Callable in _middlewares:
		if not mw.is_valid():
			continue
		result = mw.call(channel, result)
		if result == null:
			return null
	return result


## Checks whether a Callable is still safe to invoke (its bound Object hasn't been freed).
func _is_callable_valid(callable: Callable) -> bool:
	var obj = callable.get_object()
	if obj == null:
		# No bound object, or it's a static/lambda — always valid.
		return true
	return is_instance_valid(obj)


## Internal unsubscribe without the bool return (used during iteration).
func _unsubscribe_internal(sid: int) -> void:
	if not _subscriptions.has(sid):
		return
	var channel: StringName = _subscriptions[sid]["channel"]
	_subscriptions.erase(sid)
	if _channel_index.has(channel):
		_channel_index[channel].erase(sid)
		if _channel_index[channel].is_empty():
			_channel_index.erase(channel)
