class_name Bus
extends Node

signal event_published(channel: StringName, payload: Variant)

var _subscriptions: Dictionary = {}
var _middlewares: Array[Callable] = []
var _next_id: int = 1

func subscribe(channel: StringName, callable: Callable) -> int:
	if not _subscriptions.has(channel):
		_subscriptions[channel] = []
	var id = _next_id
	_next_id += 1
	_subscriptions[channel].append({"id": id, "callable": callable})
	return id

func unsubscribe(subscription_id: int) -> bool:
	for channel in _subscriptions:
		var subs = _subscriptions[channel]
		for i in range(subs.size()):
			if subs[i].id == subscription_id:
				subs.remove_at(i)
				return true
	return false

func _prune_channel(channel: StringName) -> Array:
	if not _subscriptions.has(channel):
		return []
	var subs = _subscriptions[channel]
	var i = subs.size() - 1
	while i >= 0:
		if not subs[i].callable.is_valid():
			subs.remove_at(i)
		elif subs[i].callable.get_object() != null and not is_instance_valid(subs[i].callable.get_object()):
			subs.remove_at(i)
		i -= 1
	return subs

func publish(channel: StringName, payload: Variant) -> void:
	event_published.emit(channel, payload)
	
	var modified_payload = payload
	var drop = false
	for i in range(_middlewares.size() - 1, -1, -1):
		var mw = _middlewares[i]
		if not mw.is_valid() or (mw.get_object() != null and not is_instance_valid(mw.get_object())):
			_middlewares.remove_at(i)
			
	for mw in _middlewares:
		modified_payload = mw.call(channel, modified_payload)
		if typeof(modified_payload) == TYPE_NIL:
			drop = true
			break
	
	if drop:
		return
		
	var subs = _prune_channel(channel)
	var subs_copy = subs.duplicate(true)
	for sub in subs_copy:
		var callable = sub.callable
		if callable.is_valid() and (callable.get_object() == null or is_instance_valid(callable.get_object())):
			callable.call(modified_payload)

func publish_once(channel: StringName, payload: Variant) -> void:
	event_published.emit(channel, payload)
	
	var modified_payload = payload
	var drop = false
	for i in range(_middlewares.size() - 1, -1, -1):
		var mw = _middlewares[i]
		if not mw.is_valid() or (mw.get_object() != null and not is_instance_valid(mw.get_object())):
			_middlewares.remove_at(i)
			
	for mw in _middlewares:
		modified_payload = mw.call(channel, modified_payload)
		if typeof(modified_payload) == TYPE_NIL:
			drop = true
			break
	
	var subs = _prune_channel(channel)
	_subscriptions.erase(channel)
	
	if drop:
		return
	
	for sub in subs:
		var callable = sub.callable
		if callable.is_valid() and (callable.get_object() == null or is_instance_valid(callable.get_object())):
			callable.call(modified_payload)

func add_middleware(callable: Callable) -> void:
	_middlewares.append(callable)

func clear_middleware() -> void:
	_middlewares.clear()

func clear_channel(channel: StringName) -> void:
	if _subscriptions.has(channel):
		_subscriptions.erase(channel)

func subscription_count(channel: StringName) -> int:
	return _prune_channel(channel).size()
