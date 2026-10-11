extends Node
# Esegue le funzioni test_* dei file tests/test_*.gd.
# Un test fallisce se registra un fallimento o se durante la sua esecuzione
# compare un errore di script (catturato dal Logger), salvo allow_errors().

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

var catcher := ErrorCatcher.new()

func _ready() -> void:
	OS.add_logger(catcher)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	if has_node("/root/Save"):
		get_node("/root/Save").set("path", "user://test_save.json")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
		get_node("/root/Save").call("load_save")
	var passed := 0
	var failed: Array[String] = []
	var files := Array(DirAccess.get_files_at("res://tests")).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for f in files:
		if only != "" and not f.contains(only) and not FileAccess.get_file_as_string("res://tests/" + f).contains(only):
			continue
		catcher.errors.clear()
		var script: GDScript = load("res://tests/" + f)
		# un file che non si compila è un fallimento, non zero test
		if script == null or not script.can_instantiate() or not catcher.errors.is_empty():
			failed.append("%s: il file non si compila\n    %s" % [f, "\n    ".join(catcher.errors)])
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			if only != "" and not (f.contains(only) or name.contains(only)):
				continue
			var t: TestCase = script.new()
			catcher.errors.clear()
			await t.before()
			await t.call(name)
			await t.after()
			var errs := [] if t.errors_allowed else catcher.errors.duplicate()
			if t.failures.is_empty() and errs.is_empty():
				passed += 1
			else:
				failed.append("%s::%s\n    %s" % [f, name, "\n    ".join(t.failures + errs)])
	for line in failed:
		print("FAIL ", line)
	print("\n%d superati, %d falliti" % [passed, failed.size()])
	OS.remove_logger(catcher)
	get_tree().quit(1 if failed.size() > 0 else 0)
