class_name HashiQualityWorker
extends Node
## One durable prefix at a time; UI stays responsive while expensive work runs.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Judge = preload("res://scripts/hashi_extension_judge.gd")
var host: Control
var uncertain := false
# Optional work limits support deterministic incomplete-path validation.
var limits: Dictionary = {}
var _task := -1
var _serial := -1
var _attempt := 0
var _mutex := Mutex.new()
var _result: Dictionary = {}
var _blocked := false
func _process(_delta: float) -> void:
	if host == null or host.session == null:
		return
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_mutex.lock()
		var result := _result.duplicate(true)
		_result.clear()
		_mutex.unlock()
		if result.status == "indeterminate" and _attempt < 2:
			return
		uncertain = result.status not in ["viable", "impossible"]
		_blocked = true
		host._accept_quality_verdict(result)
		return
	if host.session.quality.pending.is_empty():
		uncertain = false
		_serial = -1
		_attempt = 0
		_blocked = false
		return
	var event: Dictionary = host.session.quality.pending[0]
	if int(event.serial) != _serial:
		_serial = int(event.serial)
		_attempt = 0
		_blocked = false
		uncertain = false
	if _blocked:
		return
	var definition: Dictionary = {}
	for value in host.session.catalog:
		if value.id == event.id:
			definition = value
	if definition.is_empty():
		return
	var puzzle := Puzzle.new(definition)
	puzzle.bridges = event.bridges.duplicate(true)
	_attempt += 1
	_task = WorkerThreadPool.add_task(_judge.bind(puzzle, _serial, 1000 if _attempt == 1 else 5000, limits.duplicate(true)))
func _judge(puzzle: Puzzle, serial: int, time_ms: int, overrides: Dictionary) -> void:
	var budget := {"max_time_ms": time_ms, "max_nodes": 1000000}
	budget.merge(overrides, true)
	var verdict := Judge.new().judge(puzzle, budget)
	verdict.serial = serial
	_mutex.lock()
	_result = verdict
	_mutex.unlock()
func retry() -> void:
	_blocked = false
	uncertain = false
	_attempt = 1
func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
