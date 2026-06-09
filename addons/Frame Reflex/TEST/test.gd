extends Node3D

## NOTE : Delete this scene if you don't need it ..! 
@onready var label_2: Label = $CanvasLayer/Label2
@onready var label_3: Label = $CanvasLayer/Label3
@onready var label_4: Label = $CanvasLayer/Label4
@onready var label_5: Label = $CanvasLayer/Label5
@onready var label_6: Label = $CanvasLayer/Label6
@onready var label_7: Label = $CanvasLayer/Label7
@onready var label_8: Label = $CanvasLayer/Label8
@onready var label_9: Label = $CanvasLayer/Label9
@onready var sdfgi_label: Label = $CanvasLayer/Label10
@onready var ssil_label: Label = $CanvasLayer/Label11
@onready var ssao_label: Label = $CanvasLayer/Label12
@onready var ssr_label: Label = $CanvasLayer/Label14

## ==== Variables ===
var timer   := 0.0
var enabled : bool = false
@onready var Day_cycle: AnimationPlayer =	$"Enviroment/Day Cycle"
var timer2 : int = 60

## ==== Proccess ===
var target : float = -0.8

func _ready() -> void:
	$CanvasLayer2/Scale/Custom.text = str(FRManager.get_custom_name())
	
func _process(delta):
	## === animation ===
	var distance = abs($Objects/Monke.position.z - target)

	if distance < 0.05:
		if target == -0.8:
			target = -9.7
		elif target == -9.7:
			target = -0.8

	$Objects/Monke.position.z = lerp($Objects/Monke.position.z, target, 3 * delta)
		
	timer2 -= 1
	if timer2 == 0.0:
		$Objects/MeshInstance3D5.rotation.y += 0.1
		timer2 = 10
	## === text ===
	label_2.text = str(FRManager.get_mode())
	label_3.text = str(FRManager.get_fsr())
	label_4.text = str(FRManager.get_aa())
	label_5.text = str(FRManager.get_shadow())
	label_6.text = str(FRManager.get_scale())
	label_7.text = str(FRManager.get_ssao_quality())
	label_8.text = str(FRManager.get_sdfgi_quality())
	label_9.text = str(FRManager.get_lod_threshold())
	sdfgi_label.text = "SDFGI "+str(sdfgi)
	ssil_label.text = "SSIL "+str(ssil)
	ssao_label.text = "SSAO "+ str(ssao)
	ssr_label.text = "SSR "+ str(ssr)
	var fps        := Performance.get_monitor(Performance.TIME_FPS)
	var cpu_ms     := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var vmem_mb    := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1_048_576.0
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	$CanvasLayer/Label13.text = "FPS        : %.0f\nCPU (ms)   : %.2f\nGPU Vmem   : %.1f MB\nDraw Calls : %.0f" % [fps, cpu_ms, vmem_mb, draw_calls]
	
## ==== FR - FrameReflex ===
func _on_performance_pressed() -> void:
	FRManager.Performance()

func _on_balanced_pressed() -> void:
	FRManager.Balanced()

func _on_qualtiy_pressed() -> void:
	FRManager.Quality()
func _on_custom_pressed() -> void:
	FRManager.Custom()
	
func _on_toggle_toggled(toggled_on: bool) -> void:
	FRManager.SetEnabled(toggled_on)

## ==== Day Cycle ===
func _on_night_pressed() -> void:
	Day_cycle.play("Day Cycle")
	Day_cycle.seek(28.0, true)
	Day_cycle.pause()
func _on_day_pressed() -> void:
	Day_cycle.play("Day Cycle")
	Day_cycle.seek(0.1, true)
	Day_cycle.pause()

## ==== Graphics buttons ===
## NOTE : Only in Forward+ render 

var ssao: bool = false
func _on_ssao_pressed() -> void:
	if ssao == false : 
		$Enviroment/WorldEnvironment.environment.ssao_enabled = true
		ssao = true
	elif ssao == true : 
		$Enviroment/WorldEnvironment.environment.ssao_enabled = false
		ssao = false

var ssil : bool = false
func _on_ssil_pressed() -> void:
	if ssil == false : 
		$Enviroment/WorldEnvironment.environment.ssil_enabled = true
		ssil = true
	elif ssil == true : 
		$Enviroment/WorldEnvironment.environment.ssil_enabled = false
		ssil = false

var sdfgi : bool = false 
func _on_sdfgi_pressed() -> void:
	if sdfgi == false:
		$Enviroment/WorldEnvironment.environment.sdfgi_enabled = true
		sdfgi = true
	elif sdfgi == true : 
		$Enviroment/WorldEnvironment.environment.sdfgi_enabled = false
		sdfgi = false

var ssr : bool = false
func _on_ssr_pressed() -> void:
	if ssr == false:
		$Enviroment/WorldEnvironment.environment.ssr_enabled = true
		ssr = true
	elif ssr == true : 
		$Enviroment/WorldEnvironment.environment.ssr_enabled = false
		ssr = false

var ref : bool = false
func _on_reflection_pressed() -> void:

	if ref == false:
		$Objects/Reflection.visible  = true
		$Objects/Floor.visible = false
		ref = true
	elif ref == true : 
		$Objects/Reflection.visible = false
		$Objects/Floor.visible = true
		ref = false
