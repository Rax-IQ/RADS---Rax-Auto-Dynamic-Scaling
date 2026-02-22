extends Node3D

@onready var label: Label = $Label

var timer   := 0.0
var enabled : bool = false


func _process(delta: float) -> void:
	timer += delta

	if timer >= 0.2:
		label.text = "FPS: " + str(Engine.get_frames_per_second())
		timer = 0.0

	$Label2.text = str(RADSManager.get_mode())
	$Label3.text = str(RADSManager.get_fsr())
	$Label4.text = str(RADSManager.get_aa())
	$Label5.text = str(RADSManager.get_shadow())
	$Label6.text = str(RADSManager.get_scale())
	$Label7.text = "Frame Gen = " + str(enabled)


func _on_performance_pressed() -> void:
	RADSManager.Performance()

func _on_balanced_pressed() -> void:
	RADSManager.Balanced()

func _on_qualtiy_pressed() -> void:
	RADSManager.Quality()


func _on_frame_gen_toggled(toggled_on: bool) -> void:
	enabled = toggled_on          # <-- الـ bug كان هنا، مكنتش بتغير enabled
	if enabled:
		RADSManager.enable_frame_gen()
	else:
		RADSManager.disable_frame_gen()
