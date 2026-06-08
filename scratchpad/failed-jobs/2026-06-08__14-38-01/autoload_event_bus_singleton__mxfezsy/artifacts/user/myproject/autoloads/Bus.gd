# Bus.gd
extends Node
class_name Bus

signal event_published(channel: StringName, payload: Variant)

# Dictionary of subscription_id (int) -> Dictionary with "channel" (StringName) and "callable" (Callable)
var _subscriptions: Dictionary = {}

# Dictionary of channel (StringName) -> Array of subscription_ids [int]
var _channels: Dictionary = {}

# Array of Callable for middleware
var _middlewares: Array[Callable] = []

var _next_sub_id: int = 1

func subscribe(channel: StringName, callable: Callable) -> int:
	var sub_id = _next_sub_id
	_next_sub_id += 1
	_subscriptions[sub_id] = {
		"channel": channel,
		"callable": callable
	}
	if not _channels.has(channel):
		_channels[channel] = []
	_channels[channel].append(sub_id)
	return sub_id

func unsubscribe(subscription_id: int) -> bool:
	var sub = _subscriptions.get(subscription_id)
	if sub == null:
		return false
	var channel = sub["channel"]
	_subscriptions.erase(subscription_id)
	if _channels.has(channel):
		_channels[channel].erase(subscription_id)
		if _channels[channel].is_empty():
			_channels.erase(channel)
	return true

func publish(channel: StringName, payload: Variant) -> void:
	# Signal is emitted on every publish/publish_once call regardless of middleware (including drops)
	event_published.emit(channel, payload)
	
	_prune_channel(channel)
	
	# Run middleware
	var current_payload = payload
	for middleware in _middlewares:
		if _is_callable_valid(middleware):
			var result = middleware.call(channel, current_payload)
			if result == null:
				return # Dropped
			current_payload = result
			
	if not _channels.has(channel):
		return
		
	# Duplicate the list of subscriber IDs to avoid issues if subscribers unsubscribe during dispatch
	var sub_ids = _channels[channel].duplicate()
	for sub_id in sub_ids:
		var sub = _subscriptions.get(sub_id)
		if sub != null and _is_callable_valid(sub["callable"]):
			sub["callable"].call(current_payload)

func publish_once(channel: StringName, payload: Variant) -> void:
	# Signal is emitted on every publish/publish_once call regardless of middleware (including drops)
	event_published.emit(channel, payload)
	
	_prune_channel(channel)
	
	var sub_ids = []
	if _channels.has(channel):
		sub_ids = _channels[channel].duplicate()
		
	# Run middleware
	var current_payload = payload
	var dropped = false
	for middleware in _middlewares:
		if _is_callable_valid(middleware):
			var result = middleware.call(channel, current_payload)
			if result == null:
				dropped = true
				break
			current_payload = result
			
	if not dropped:
		for sub_id in sub_ids:
			var sub = _subscriptions.get(sub_id)
			if sub != null and _is_callable_valid(sub["callable"]):
				sub["callable"].call(current_payload)
				
	# Unsubscribe every subscriber on that channel
	for sub_id in sub_ids:
		unsubscribe(sub_id)

func add_middleware(callable: Callable) -> void:
	_middlewares.append(callable)

func clear_middleware() -> void:
	_middlewares.clear()

func clear_channel(channel: StringName) -> void:
	if _channels.has(channel):
		var sub_ids = _channels[channel].duplicate()
		for sub_id in sub_ids:
			_subscriptions.erase(sub_id)
		_channels.erase(channel)

func subscription_count(channel: StringName) -> int:
	_prune_channel(channel)
	if _channels.has(channel):
		return _channels[channel].size()
	return 0

func _prune_channel(channel: StringName) -> void:
	if not _channels.has(channel):
		return
	var valid_subs: Array = []
	for sub_id in _channels[channel]:
		var sub = _subscriptions.get(sub_id)
		if sub != null:
			if _is_callable_valid(sub["callable"]):
				valid_subs.append(sub_id)
			else:
				_subscriptions.erase(sub_id)
	if valid_subs.is_empty():
		_channels.erase(channel)
	else:
		_channels[channel] = valid_subs

func _is_callable_valid(callable: Callable) -> bool:
	if not callable.is_valid():
		return false
	var obj = callable.get_object()
	if obj != null and not is_instance_valid(obj):
		return false
	return true
