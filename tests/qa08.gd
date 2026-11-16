extends SceneTree

func _initialize() -> void:
	root.add_child(preload("res://tests/qa_08.gd").new())
