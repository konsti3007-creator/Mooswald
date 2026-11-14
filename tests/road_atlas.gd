extends SceneTree

func _initialize() -> void:
 root.add_child(preload("res://tests/road_atlas_scene.gd").new())
