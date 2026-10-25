class_name HashiSequence
extends RefCounted
## Temporary catalog order. Replace this policy for future modes, not the UI.
## No Story, fixed-difficulty or automatic-progression modes implemented yet.
var ids: Array[String] = []

func _init(catalog: Array = []) -> void:
	for data in catalog:
		ids.append(str(data.id))

func next_id(current: String) -> String:
	var index := ids.find(current)
	if index < 0 or ids.is_empty():
		return ""
	return ids[(index + 1) % ids.size()]

func wraps_after(current: String) -> bool:
	return not ids.is_empty() and current == ids.back()
