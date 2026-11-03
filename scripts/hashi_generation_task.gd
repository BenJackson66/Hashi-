class_name HashiGenerationTask
extends RefCounted
## One task, one generator, copied inputs and a mutex-protected handoff.
const FreePlay = preload("res://scripts/hashi_free_play.gd")
const Generator = preload("res://scripts/hashi_generator.gd")
var _task_id := -1
var _mutex := Mutex.new()
var _result: Dictionary = {}

func start(seed_value: int, parameters: Dictionary) -> bool:
	if _task_id != -1:
		return false
	_task_id = WorkerThreadPool.add_task(_generate.bind(seed_value, parameters.duplicate(true)), false, "Hashi generation")
	return _task_id != -1

func start_free(seed_value: int, profile: String, parameters: Dictionary, excluded_id: String) -> bool:
	if _task_id != -1:
		return false
	_task_id = WorkerThreadPool.add_task(_generate.bind(seed_value, parameters.duplicate(true), profile, excluded_id), false, "Hashi free play")
	return _task_id != -1

func _generate(seed_value: int, parameters: Dictionary, profile: String = "", excluded_id: String = "") -> void:
	var generated := Generator.new().generate(seed_value, parameters) if profile.is_empty() else FreePlay.new().generate(seed_value, profile, parameters, excluded_id)
	var playable: Dictionary
	if generated.status == "success":
		# Discard both solver witnesses inside the worker. Never hand them to UI/save.
		playable = {"status": "success", "recipe": {"seed": str(generated.seed),
			"algorithm_version": generated.algorithm_version,
			"identity_schema": Generator.IDENTITY_SCHEMA_VERSION,
			"parameters": generated.parameters.duplicate(true), "puzzle": generated.puzzle.duplicate(true)}}
	else:
		playable = {"status": "failure", "reason": generated.reason}
	_mutex.lock()
	_result = playable
	_mutex.unlock()

func poll() -> Dictionary:
	if _task_id == -1 or not WorkerThreadPool.is_task_completed(_task_id):
		return {}
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	_mutex.lock()
	var result := _result.duplicate(true)
	_result.clear()
	_mutex.unlock()
	if result.is_empty():
		return {"status": "failure", "reason": "worker_failed"}
	return result

func finish_on_shutdown() -> void:
	# Only scene teardown joins unfinished work, never the interactive frame loop.
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
	_mutex.lock()
	_result.clear()
	_mutex.unlock()
