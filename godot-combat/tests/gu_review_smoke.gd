extends SceneTree

const GuReviewScene = preload("res://gu_review.tscn")
var failed := false


func _initialize() -> void:
	call_deferred("run_checks")


func verify(condition: bool, msg: String) -> void:
	if condition:
		return
	failed = true
	push_error(msg)


func run_checks() -> void:
	var scene := GuReviewScene.instantiate()
	root.add_child(scene)
	await process_frame

	verify(scene.NGOC_BI_ATLAS.get_size() == Vector2(768, 384), "ngoc-bi-co.png must be 768x384")
	verify(scene.SINH_CO_ATLAS.get_size() == Vector2(1024, 128), "sinh-co-diep.png must be 1024x128")
	verify(scene.NGOC_BI_ICON.get_size() == Vector2(32, 32), "ngoc-bi-co-icon.png must be 32x32")
	verify(scene.SINH_CO_ICON.get_size() == Vector2(32, 32), "sinh-co-diep-icon.png must be 32x32")

	var n_cast: Dictionary = scene.sample_ngoc_bi(250.0, "cast")
	verify(n_cast.row == 0 and n_cast.col == 2, "Ngoc Bi cast lock frame mismatch")
	var n_sustain: Dictionary = scene.sample_ngoc_bi(220.0, "sustain")
	verify(n_sustain.row == 1 and n_sustain.col == 2, "Ngoc Bi sustain frame mismatch")
	var n_hit: Dictionary = scene.sample_ngoc_bi(20.0, "impact_flash")
	verify(n_hit.row == 2 and n_hit.col == 0 and n_hit.is_contact, "Ngoc Bi contact flash mismatch")

	var s_peak: Dictionary = scene.sample_sinh_co_diep(245.0)
	verify(s_peak.col == 3 and s_peak.is_peak, "Sinh Co Diep peak heal frame mismatch")

	quit(1 if failed else 0)
