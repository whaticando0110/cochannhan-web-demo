extends SceneTree

const ReviewScene = preload("res://guard_review.tscn")
var failed := false


func _initialize() -> void:
	call_deferred("run_checks")


func verify(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func run_checks() -> void:
	var scene := ReviewScene.instantiate()
	root.add_child(scene)
	await process_frame

	verify(scene.GUARD_ATLAS != null, "Missing guard atlas texture")
	verify(scene.GUARD_ATLAS.get_size() == Vector2(1024, 256), "Expected 1024x256 guard atlas")

	var s_brace: Dictionary = scene.sample_exchange(160.0)
	verify(s_brace.phase == "brace" and s_brace.hero_frame == 2 and s_brace.wolf_frame == 0,
		"Brace sample mismatch at 160ms")

	var s_coil: Dictionary = scene.sample_exchange(300.0)
	verify(s_coil.phase == "wolf_lunge" and s_coil.hero_frame == 3 and s_coil.wolf_frame == 8,
		"Wolf coil sample mismatch at 300ms")

	var s_leap: Dictionary = scene.sample_exchange(450.0)
	verify(s_leap.phase == "wolf_lunge" and s_leap.hero_frame == 3 and s_leap.wolf_frame == 9,
		"Wolf leap sample mismatch at 450ms")

	var s_contact: Dictionary = scene.sample_exchange(520.0)
	verify(s_contact.phase == "block_impact" and s_contact.is_contact, "Expected contact phase at 520ms")
	verify(s_contact.hero_frame == 4 and s_contact.ward_fx_frame == 12 and s_contact.wolf_frame == 10,
		"Contact frame indices mismatch at 520ms")
	verify(s_contact.sleeve_block_point.x > s_contact.hero_point.x,
		"Sleeve block point must lie in front of hero toward attacking wolf")

	var s_push: Dictionary = scene.sample_exchange(650.0)
	verify(s_push.phase == "block_impact" and s_push.hero_frame == 5 and s_push.wolf_frame == 11,
		"Counter-push sample mismatch at 650ms")

	var s_recover: Dictionary = scene.sample_exchange(860.0)
	verify(s_recover.phase == "recover" and s_recover.hero_frame == 7 and s_recover.wolf_frame == 0,
		"Recovery sample mismatch at 860ms")

	scene.step_to_frame(4)
	verify(scene.current_sample.hero_frame == 4 and not scene.playing, "Manual step to contact frame 4 failed")

	quit(1 if failed else 0)
