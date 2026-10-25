extends SceneTree
const Generator = preload("res://scripts/hashi_generator.gd")
var output: FileAccess

func _initialize() -> void:
	call_deferred("run")

func emit_row(row: Dictionary) -> void:
	var line := JSON.stringify(row)
	print(line)
	if output != null:
		output.store_line(line)

func run() -> void:
	var options := {"width": 5, "height": 5, "island_count": 10, "max_attempts": 100, "max_time_ms": 1500, "solver_max_nodes": 100000}
	var seed_value := 1
	var count := 10
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() != 2:
			printerr("Expected --name=value")
			quit(2)
			return
		if pair[0] == "output":
			output = FileAccess.open(pair[1], FileAccess.WRITE)
			if output == null:
				printerr("Cannot write output file")
				quit(2)
				return
		elif not pair[1].is_valid_int():
			printerr("Expected integer option")
			quit(2)
			return
		elif pair[0] == "seed":
			seed_value = pair[1].to_int()
		elif pair[0] == "count":
			count = pair[1].to_int()
		elif options.has(pair[0]):
			options[pair[0]] = pair[1].to_int()
		else:
			printerr("Unknown option")
			quit(2)
			return
	if count < 1 or count > 1000 or seed_value < -2147483646 or seed_value > 2147482646:
		printerr("count must be 1..1000 and initial seed in -2147483646..2147482646")
		quit(2)
		return
	emit_row({"type": "environment", "godot": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "algorithm_version": Generator.ALGORITHM_VERSION, "parameters": options})
	var times: Array = []
	var successes := 0
	var total := 0.0
	for index in count:
		var result := Generator.new().generate(seed_value + index, options)
		result.type = "board"
		result.seed = seed_value + index
		result.dimensions = [options.width, options.height]
		emit_row(result)
		times.append(result.elapsed_ms)
		total += float(result.elapsed_ms)
		if result.status == "success":
			successes += 1
	times.sort()
	emit_row({"type": "summary", "count": count, "successes": successes, "failures": count - successes,
		"mean_ms": total / count, "median_ms": (float(times[(count - 1) / 2]) + float(times[count / 2])) / 2.0,
		"p95_ms": times[maxi(0, ceili(count * 0.95) - 1)], "max_ms": times.back()})
	if output != null:
		output.close()
	quit(0 if successes == count else 1)
