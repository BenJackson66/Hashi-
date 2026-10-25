class_name HashiRules
extends RefCounted
const Puzzle = preload("res://scripts/hashi_puzzle.gd")

static func position(item: Dictionary) -> Vector2:
	return Vector2(item.x, item.y)

static func valid_definition(puzzle: Puzzle) -> bool:
	if puzzle.islands.is_empty():
		return false
	var ids := {}
	var positions := {}
	for item in puzzle.islands:
		if not item.has_all(["id", "x", "y", "target"]):
			return false
		var id := str(item.id)
		var point := position(item)
		if id.is_empty() or ":" in id or ids.has(id) or positions.has(point):
			return false
		if float(item.target) != int(item.target) or item.target < 1 or item.target > 8:
			return false
		ids[id] = true
		positions[point] = true
	return true

static func aligned_neighbors(puzzle: Puzzle, a: String, b: String) -> bool:
	var first := puzzle.island(a)
	var second := puzzle.island(b)
	if a == b or first.is_empty() or second.is_empty():
		return false
	var p := position(first)
	var q := position(second)
	if p.x != q.x and p.y != q.y:
		return false
	for item in puzzle.islands:
		var r := position(item)
		if (p.x == q.x and r.x == p.x and r.y > minf(p.y, q.y) and r.y < maxf(p.y, q.y)) or (p.y == q.y and r.y == p.y and r.x > minf(p.x, q.x) and r.x < maxf(p.x, q.x)):
			return false
	return true

static func crosses(p: Vector2, q: Vector2, r: Vector2, s: Vector2) -> bool:
	if p.x == q.x and r.y == s.y:
		return p.x > minf(r.x, s.x) and p.x < maxf(r.x, s.x) and r.y > minf(p.y, q.y) and r.y < maxf(p.y, q.y)
	if p.y == q.y and r.x == s.x:
		return crosses(r, s, p, q)
	return false

static func move_error(puzzle: Puzzle, a: String, b: String, count: int) -> String:
	if count < 0 or count > 2:
		return "Máximo dos puentes."
	if not aligned_neighbors(puzzle, a, b):
		return "Elige dos islas vecinas en la misma fila o columna."
	if count == 0:
		return ""
	var p := position(puzzle.island(a))
	var q := position(puzzle.island(b))
	for edge in puzzle.bridges:
		if edge == puzzle.key(a, b) or int(puzzle.bridges[edge]) == 0:
			continue
		var ids: PackedStringArray = edge.split(":")
		if crosses(p, q, position(puzzle.island(ids[0])), position(puzzle.island(ids[1]))):
			return "Los puentes no pueden cruzarse."
	return ""

static func cycle_bridge(puzzle: Puzzle, a: String, b: String) -> String:
	var count := (puzzle.bridge_count(a, b) + 1) % 3
	var error := move_error(puzzle, a, b, count)
	if error.is_empty():
		if count == 0:
			puzzle.bridges.erase(puzzle.key(a, b))
		else:
			puzzle.bridges[puzzle.key(a, b)] = count
	return error

static func network_connected(puzzle: Puzzle) -> bool:
	if puzzle.islands.is_empty():
		return false
	var visited := {str(puzzle.islands[0].id): true}
	var pending: Array[String] = [str(puzzle.islands[0].id)]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		for edge in puzzle.bridges:
			if int(puzzle.bridges[edge]) <= 0:
				continue
			var ids: PackedStringArray = edge.split(":")
			if current in ids:
				var other: String = ids[1] if ids[0] == current else ids[0]
				if not visited.has(other):
					visited[other] = true
					pending.append(other)
	return visited.size() == puzzle.islands.size()

static func is_solved(puzzle: Puzzle) -> bool:
	if not valid_definition(puzzle):
		return false
	for edge in puzzle.bridges:
		var ids: PackedStringArray = edge.split(":")
		if ids.size() != 2 or puzzle.key(ids[0], ids[1]) != edge:
			return false
		var count := int(puzzle.bridges[edge])
		if count != puzzle.bridges[edge] or not move_error(puzzle, ids[0], ids[1], count).is_empty():
			return false
	for item in puzzle.islands:
		if puzzle.degree(str(item.id)) != int(item.target):
			return false
	return network_connected(puzzle)
