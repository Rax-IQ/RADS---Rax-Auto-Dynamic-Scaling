## RADSManager.gd
## -----------------------------------------------------------------------------
##  RADS - Rax Auto Dynamic Scaling  |  Runtime Autoload
##
##  Modes
##  -----
##  Performance  -> FSR OFF | AA OFF          | Scale 25% / 35%
##  Balanced     -> FSR 1/2 | FXAA            | Scale 35% / 60%
##  Quality      -> FSR 1/2 | TAA + MSAA 4x  | Scale 50% / 75%
##
##  Shadow Atlas (all modes, FPS-based):
##  - FPS < 60   -> 524
##  - FPS >= 60  -> 2024
##  - FPS >= 300 -> 4028
##
##  Public API:
##    RADSManager.Performance()
##    RADSManager.Balanced()
##    RADSManager.Quality()
##    RADSManager.enable_frame_gen()
##    RADSManager.disable_frame_gen()
## -----------------------------------------------------------------------------
extends Node

# -- Constants -----------------------------------------------------------------

const FRAME_GEN_PATH := "res://addons/rads/Frame_Gen.gd"

const FSR_OFF := Viewport.SCALING_3D_MODE_BILINEAR
const FSR1    := Viewport.SCALING_3D_MODE_FSR
const FSR2    := Viewport.SCALING_3D_MODE_FSR2

const AA_OFF  := Viewport.MSAA_DISABLED
const AA_4X   := Viewport.MSAA_2X

const SHADOW_LOW  : int = 524
const SHADOW_MID  : int = 2024
const SHADOW_HIGH : int = 4028

const FPS_MINIMUM           : float = 80.0
const FPS_HIGH              : float = 300.0
const FPS_DROP_THRESHOLD    : float = 10.0
const FPS_RECOVER_THRESHOLD : float = 10.0
const CHECK_INTERVAL        : float = 1.0
const BASELINE_LERP         : float = 0.08

# -- Mode Profiles -------------------------------------------------------------

const PROFILES := {
	"Performance" : {
		"low_scale" : 0.55, "low_fsr" : FSR_OFF,
		"high_scale": 0.65, "high_fsr": FSR_OFF,
		"msaa": AA_OFF, "taa": false, "fxaa": true,
	},
	"Balanced" : {
		"low_scale" : 0.6, "low_fsr" : FSR_OFF,
		"high_scale": 0.6, "high_fsr": FSR1,
		"msaa": AA_OFF, "taa": false, "fxaa": true,
	},
	"Quality" : {
		"low_scale" : 0.7, "low_fsr" : FSR1,
		"high_scale": 0.9, "high_fsr": FSR1,
		"msaa": AA_4X, "taa": false, "fxaa": true,
	},
}

# -- State ---------------------------------------------------------------------

var _mode              : String     = "Balanced"
var _profile           : Dictionary = {}
var _baseline_fps      : float      = 0.0
var _current_scale     : float      = 0.0
var _current_fsr       : int        = FSR_OFF
var _current_shadow    : int        = SHADOW_MID
var _fps_samples       : Array[float] = []
var _check_timer       : float      = 0.0
var _warmup_done       : bool       = false
var _frame_gen_enabled : bool       = false


# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_load_mode(ProjectSettings.get_setting("rads/mode", "Balanced"))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_fps_samples.append(float(Engine.get_frames_per_second()))
	_check_timer += delta

	if _check_timer < CHECK_INTERVAL:
		return

	_check_timer = 0.0
	_evaluate()


# -- Core ----------------------------------------------------------------------

func _evaluate() -> void:
	if _fps_samples.is_empty():
		return

	var avg : float = 0.0
	for s in _fps_samples:
		avg += s
	avg /= float(_fps_samples.size())
	_fps_samples.clear()

	if not _warmup_done:
		_baseline_fps = avg
		_warmup_done  = true
		_apply_shadow(_fps_to_shadow(avg))
		return

	var drop    := _baseline_fps - avg
	var recover := avg - _baseline_fps

	_apply_shadow(_fps_to_shadow(avg))

	if avg < FPS_MINIMUM:
		if _current_fsr != FSR_OFF or _current_scale != _profile["low_scale"]:
			var vp := get_viewport()
			if vp:
				vp.msaa_3d         = AA_OFF
				vp.use_taa         = false
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			_apply(_profile["low_scale"], FSR_OFF)

	elif drop >= FPS_DROP_THRESHOLD:
		_apply(_profile["low_scale"], _profile["low_fsr"])

	elif recover >= FPS_RECOVER_THRESHOLD:
		_apply(_profile["high_scale"], _profile["high_fsr"])

	_baseline_fps = lerp(_baseline_fps, avg, BASELINE_LERP)


# -- Internal ------------------------------------------------------------------

func _fps_to_shadow(fps: float) -> int:
	if fps >= FPS_HIGH:
		return SHADOW_HIGH
	elif fps >= FPS_MINIMUM:
		return SHADOW_MID
	else:
		return SHADOW_LOW


func _apply_shadow(size: int) -> void:
	if _current_shadow == size:
		return
	_current_shadow = size
	var vp := get_viewport()
	if vp == null:
		return
	vp.positional_shadow_atlas_size = size
	RenderingServer.directional_shadow_atlas_set_size(size, true)


func _load_mode(mode: String) -> void:
	if not PROFILES.has(mode):
		return
	_mode        = mode
	_profile     = PROFILES[mode]
	_warmup_done = false
	_fps_samples.clear()
	_apply(_profile["low_scale"], _profile["low_fsr"])


func _apply(scale: float, fsr: int) -> void:
	if _current_scale == scale and _current_fsr == fsr:
		return
	_current_scale = scale
	_current_fsr   = fsr
	var vp := get_viewport()
	if vp == null:
		return
	vp.scaling_3d_mode   = fsr
	vp.scaling_3d_scale  = scale
	vp.msaa_3d           = _profile["msaa"]
	vp.use_taa           = _profile["taa"]
	vp.screen_space_aa   = Viewport.SCREEN_SPACE_AA_FXAA if _profile["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED


# -- Public API ----------------------------------------------------------------

## Switch to Performance mode (FSR always OFF, max FPS)
func Performance() -> void:
	_load_mode("Performance")
	ProjectSettings.set_setting("rads/mode", "Performance")

## Switch to Balanced mode
func Balanced() -> void:
	_load_mode("Balanced")
	ProjectSettings.set_setting("rads/mode", "Balanced")

## Switch to Quality mode
func Quality() -> void:
	_load_mode("Quality")
	ProjectSettings.set_setting("rads/mode", "Quality")

## Enable experimental frame generation + disable VSync automatically
func enable_frame_gen() -> void:
	if _frame_gen_enabled:
		return
	
	if has_node("/root/FrameGen"):
		get_node("/root/FrameGen").enable()
	else:
		var fg_script := load(FRAME_GEN_PATH) as GDScript
		if fg_script == null:
			push_warning("[RADS] Frame_Gen.gd not found at: " + FRAME_GEN_PATH)
			return
		var node : Node = fg_script.new()
		node.name        = "FrameGen"
		node.auto_enable = false
		get_tree().root.add_child(node)
		node.enable()
	
	_frame_gen_enabled = true


func disable_frame_gen() -> void:
	if not _frame_gen_enabled:
		return
	
	var fg := get_node_or_null("/root/FrameGen")
	if fg:
		fg.disable()
	
	_frame_gen_enabled = false

## Returns true if frame gen is running
func is_frame_gen_enabled() -> bool:
	return _frame_gen_enabled

## Fine-tune frame gen:  blend / motion / sharpness  (all 0.0 - 1.0)
func set_frame_gen_params(blend: float = 0.75, motion: float = 0.85, sharp: float = 0.5) -> void:
	var fg := get_node_or_null("/root/FrameGen")
	if fg == null:
		return
	fg.set_blend(blend)
	fg.set_motion(motion)
	fg.set_sharpness(sharp)

## Returns current mode name
func get_mode() -> String:
	return _mode

## Returns current 3D scale e.g. "50%"
func get_scale() -> String:
	return "%d%%" % int(_current_scale * 100)

## Returns current shadow atlas size e.g. "2024"
func get_shadow() -> String:
	return str(_current_shadow)

## Returns current FSR mode e.g. "FSR 2" / "FSR 1" / "OFF"
func get_fsr() -> String:
	match _current_fsr:
		FSR2 : return "FSR 2"
		FSR1 : return "FSR 1"
		_    : return "OFF"

## Returns current AA method e.g. "TAA + MSAA 4x" / "FXAA" / "OFF"
func get_aa() -> String:
	if _profile.is_empty():
		return "OFF"
	if _profile["taa"]:
		return "TAA + MSAA 4x"
	if _profile["fxaa"]:
		return "FXAA"
	return "OFF"
