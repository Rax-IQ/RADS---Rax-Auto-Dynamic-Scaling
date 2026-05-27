extends Node

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  FRManager — Adaptive Frame Rate & Quality Manager  (Fixed)                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ── Rendering constants ────────────────────────────────────────────────────────
const FSR_OFF := Viewport.SCALING_3D_MODE_BILINEAR
const FSR1    := Viewport.SCALING_3D_MODE_FSR
const AA_OFF  := Viewport.MSAA_DISABLED

const SHADOW_LOW  : int = 512
const SHADOW_MID  : int = 1024
const SHADOW_HIGH : int = 2048

const SHADOW_FILTER_LOW  : int = 0
const SHADOW_FILTER_MID  : int = 1
const SHADOW_FILTER_HIGH : int = 1

# ── FPS thresholds ─────────────────────────────────────────────────────────────
const FPS_MINIMUM  : float = 100.0
const FPS_HIGH     : float = 200.0
const HYSTERESIS   : float = 5.0
const FRAMETIME_STUTTER_THRESHOLD_MS : float = 4.0
const FRAMETIME_TARGET_MS            : float = 11.1

# ── Adaptive scale ─────────────────────────────────────────────────────────────
const SCALE_STEP        : float = 0.025
const RECOVERY_COOLDOWN : float = 3.0
const CHECK_INTERVAL    : float = 1.0
const BASELINE_LERP     : float = 0.08
const WARMUP_DURATION   : float = 4.0

# ── FSR / AA dynamic control ───────────────────────────────────────────────────
const FSR_AA_ON_MARGIN  : float = 100.0
const FSR_AA_OFF_MARGIN : float = 50.0
const FSR_AA_LOCK_TIME  : float = 4.0

# ── Profile switch hysteresis ──────────────────────────────────────────────────
const PROFILE_SWITCH_COOLDOWN : float = 0.3

# ──  Shadow hysteresis ─────────────────────────────────────────────────

const SHADOW_HYSTERESIS_CHECKS : int = 3

# ── Thermal throttle detection ─────────────────────────────────────────────────
const THERMAL_DRIFT_FRACTION : float = 0.20
const THERMAL_WINDOW         : float = 60.0
const THERMAL_CHECK_INTERVAL : float = 10.0
const MAX_THERMAL_SAMPLES    : int   = 60

# ── Draw-call / background / benchmark ────────────────────────────────────────
const BG_FPS_CAP               : int   = 30
const DRAW_CALL_HIGH_THRESHOLD : int   = 2000
const DRAW_CALL_LOW_THRESHOLD  : int   = 1200
const BENCHMARK_SAMPLE_DURATION: float = 2.0

# ── Project settings keys ──────────────────────────────────────────────────────
const LOD_SETTING              := "rendering/mesh_lod/lod_change/threshold_pixels"
const SHADOW_FILTER_SETTING    := "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
const SSAO_SETTING             := "rendering/environment/ssao/quality"
const SSIL_SETTING             := "rendering/environment/ssil/quality"
const TEX_FILTER_SETTING       := "rendering/textures/default_filters/anisotropic_filtering_level"
const SDFGI_PROBE_RAYS_SETTING := "rendering/global_illumination/sdfgi/probe_ray_count"
const SDFGI_FRAMES_CONVERGE    := "rendering/global_illumination/sdfgi/frames_to_converge"
const SDFGI_FRAMES_UPDATE      := "rendering/global_illumination/sdfgi/frames_to_update_lights"
const CONFIG_PATH              := "user://fr_config.cfg"

const SDFGI_RAYS_LOW  : int = 0;  const SDFGI_RAYS_MID  : int = 1;  const SDFGI_RAYS_HIGH  : int = 3
const SDFGI_CONVERGE_LOW : int = 0; const SDFGI_CONVERGE_MID : int = 2; const SDFGI_CONVERGE_HIGH : int = 5
const SDFGI_LIGHT_LOW : int = 3;  const SDFGI_LIGHT_MID : int = 2;  const SDFGI_LIGHT_HIGH : int = 1

# ── Mode profiles ──────────────────────────────────────────────────────────────
const PROFILES := {
	"Performance" : { "scale_min": 0.50, "scale_max": 0.60, "lod_threshold": 20.0, "ssao_quality": 0, "ssil_quality": 0, "tex_filter": 0, "sdfgi_rays": SDFGI_RAYS_LOW,  "sdfgi_converge": SDFGI_CONVERGE_LOW,  "sdfgi_lights": SDFGI_LIGHT_LOW },
	"Balanced"    : { "scale_min": 0.60, "scale_max": 0.70, "lod_threshold": 15.0, "ssao_quality": 0, "ssil_quality": 0, "tex_filter": 1, "sdfgi_rays": SDFGI_RAYS_LOW,  "sdfgi_converge": SDFGI_CONVERGE_LOW,  "sdfgi_lights": SDFGI_LIGHT_LOW },
	"Quality"     : { "scale_min": 0.70, "scale_max": 0.75, "lod_threshold": 10.0, "ssao_quality": 1, "ssil_quality": 1, "tex_filter": 1, "sdfgi_rays": SDFGI_RAYS_LOW,  "sdfgi_converge": SDFGI_CONVERGE_LOW,  "sdfgi_lights": SDFGI_LIGHT_MID  },
}

const SCENE_HINT_OFFSETS := {
	"light"  : { "scale_delta":  0.05, "lod_delta": -3.0 },
	"normal" : { "scale_delta":  0.0,  "lod_delta":  0.0 },
	"heavy"  : { "scale_delta": -0.05, "lod_delta":  3.0 },
}

# ── Signals ────────────────────────────────────────────────────────────────────

signal profile_changed(new_mode: String)
signal scale_changed(new_scale: float)
signal benchmark_done(results: Dictionary)

# ── Core state ─────────────────────────────────────────────────────────────────
var _enabled               : bool   = true
var _mode                  : String = "Balanced"
var _profile               : Dictionary = {}
var _scene_hint            : String = "normal"
var _baseline_fps          : float  = 0.0
var _current_scale         : float  = 0.0
var _current_shadow        : int    = SHADOW_MID
var _current_shadow_filter : int    = SHADOW_FILTER_MID

# ── Optimized accumulators ────────────────────────────────
var _fps_accum      : float = 0.0
var _fps_count      : int   = 0
var _ft_accum       : float = 0.0
var _ft_sq_accum    : float = 0.0
var _ft_max         : float = 0.0

# ── Warmup accumulators ────────────────────────────────────────────────────────
var _warmup_fps_accum : float = 0.0
var _warmup_fps_count : int   = 0

# ── Timers ─────────────────────────────────────────────────────────────────────
var _check_timer          : float = 0.0
var _recovery_timer       : float = 0.0
var _warmup_done          : bool  = false
var _warmup_timer         : float = 0.0
var _profile_switch_timer : float = 0.0
var _fsr_aa_lock_timer    : float = 0.0
var _thermal_check_timer  : float = 0.0

# ── Flags ──────────────────────────────────────────────────────────────────────
var _low_fps          : bool   = false
var _fsr_aa_enabled   : bool   = false
var _is_in_background : bool   = false
var _pending_mode     : String = ""

var _config_save_pending : bool = false

var _fxaa_locked_off     : bool = false

# ── Shadow hysteresis state ──────────────────────────────────────────
var _shadow_desired           : int = SHADOW_MID
var _shadow_consecutive_count : int = 0

# ── Thermal ────────────────────────────────────────────────────────────────────
var _thermal_samples       : Array[float] = []
var _thermal_baseline_fps  : float        = 0.0
var _thermal_triggered     : bool         = false

# ── Benchmark ─────────────────────────────────────────────────────────────────
var _benchmarking       : bool          = false
var _benchmark_step     : int           = 0
var _benchmark_timer    : float         = 0.0
var _benchmark_accum    : float         = 0.0
var _benchmark_count    : int           = 0
var _benchmark_results  : Dictionary    = {}
var _benchmark_steps    : Array[String] = ["Performance", "Balanced", "Quality"]

# ── Debug overlay ──────────────────────────────────────────────────────────────
var _debug_overlay_enabled : bool        = false
var _debug_canvas          : CanvasLayer = null
var _debug_label           : Label       = null

# ── Cached stats & mode ────────────────────────────────────────────────────────
var _last_ft_stats       : Dictionary = {}
var _cached_desired_mode : String     = "Balanced"

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_config()
	_cached_desired_mode = ProjectSettings.get_setting("fr/mode", "Balanced") as String
	_load_mode(_cached_desired_mode)
	if Engine.is_editor_hint(): return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_connect_window_signals()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _enabled: return


	if _cached_desired_mode != _mode and PROFILES.has(_cached_desired_mode) and not _config_save_pending:
		_config_save_pending = true
		_schedule_mode(_cached_desired_mode)
		_save_config(_cached_desired_mode)

	# ── Timers ──────────────────────────────────────────────────────────────
	_check_timer         += delta
	_recovery_timer      += delta
	_fsr_aa_lock_timer    = maxf(_fsr_aa_lock_timer - delta, 0.0)
	_thermal_check_timer += delta

	# ── Profile switch deferred ──────────────────────────────────────────────
	if _profile_switch_timer > 0.0:
		_profile_switch_timer -= delta
		if _profile_switch_timer <= 0.0 and _pending_mode != "":
			_do_load_mode(_pending_mode)
			_pending_mode        = ""
			_config_save_pending = false 

	# ── Warmup ──────────────────────────────────────────────────────────────
	if not _warmup_done:
		_warmup_timer         += delta
		_warmup_fps_accum     += float(Engine.get_frames_per_second())
		_warmup_fps_count     += 1
		if _warmup_timer >= WARMUP_DURATION:
			_warmup_done = true
			if _warmup_fps_count > 0:
				_baseline_fps         = _warmup_fps_accum / float(_warmup_fps_count)
				_thermal_baseline_fps = _baseline_fps
			_warmup_fps_accum = 0.0
			_warmup_fps_count = 0
			_fps_accum   = 0.0
			_fps_count   = 0
			_ft_accum    = 0.0
			_ft_sq_accum = 0.0
			_ft_max      = 0.0
			_check_timer = 0.0
			print("[FR] Warmup done — baseline %.1f fps" % _baseline_fps)
		return

	# ── Benchmark mode ───────────────────────────────────────────────────────
	if _benchmarking:
		_benchmark_timer += delta
		_benchmark_accum += float(Engine.get_frames_per_second())
		_benchmark_count += 1
		if _benchmark_timer >= BENCHMARK_SAMPLE_DURATION:
			_advance_benchmark_step()
		return

	# ── Accumulate per-frame data ────────────────────────────────────────────
	var current_fps : float = float(Engine.get_frames_per_second())
	var ft_ms       : float = delta * 1000.0
	_fps_accum   += current_fps
	_fps_count   += 1
	_ft_accum    += ft_ms
	_ft_sq_accum += ft_ms * ft_ms
	_ft_max       = maxf(_ft_max, ft_ms)

	
	if _debug_overlay_enabled and _debug_label != null:
		_update_debug_overlay(current_fps, ft_ms)

	if _check_timer < CHECK_INTERVAL: return
	_check_timer = 0.0

	_check_thermal()
	_evaluate()

# ══════════════════════════════════════════════════════════════════════════════
#  DEBUG OVERLAY UPDATE
# ══════════════════════════════════════════════════════════════════════════════

func _update_debug_overlay(current_fps: float, ft_ms: float) -> void:
	if _debug_label == null: return
	var s := _last_ft_stats
	_debug_label.text = (
		"[FRManager]\n"
		+ "Mode    : %s\n"     % _mode
		+ "Scale   : %s\n"     % get_scale()
		+ "FPS     : %.0f\n"   % current_fps
		+ "FT      : %.2f ms\n"% ft_ms
		+ "Avg FPS : %.1f\n"   % s.get("avg_fps", 0.0)
		+ "StdDev  : %.2f ms\n"% s.get("stddev",  0.0)
		+ "P99     : %.2f ms\n"% s.get("p99",     0.0)
		+ "Shadow  : %s\n"     % get_shadow()
		+ "ShdFltr : %s\n"     % get_shadow_filter()
		+ "FSR     : %s\n"     % get_fsr()
		+ "AA      : %s\n"     % get_aa()
		+ "Thermal : %s\n"     % get_thermal_state()
		+ "Hint    : %s\n"     % _scene_hint
		+ "Baseline: %.1f\n"   % _baseline_fps
		+ "Recovery: %.1f s"   % _recovery_timer
	)

# ══════════════════════════════════════════════════════════════════════════════
# FRAME-TIME STATS — O(1) بدون sort
# ══════════════════════════════════════════════════════════════════════════════

func _consume_frametime_stats() -> Dictionary:
	if _fps_count == 0:
		return { "avg_fps": 0.0, "avg_ft": 0.0, "stddev": 0.0, "p99": 0.0 }

	var n        : int   = _fps_count
	var avg_fps  : float = _fps_accum / float(n)
	var avg_ft   : float = _ft_accum  / float(n)
	var variance : float = maxf((_ft_sq_accum / float(n)) - (avg_ft * avg_ft), 0.0)
	var stddev   : float = sqrt(variance)
	var p99      : float = _ft_max

	_fps_accum   = 0.0
	_fps_count   = 0
	_ft_accum    = 0.0
	_ft_sq_accum = 0.0
	_ft_max      = 0.0

	return { "avg_fps": avg_fps, "avg_ft": avg_ft, "stddev": stddev, "p99": p99 }

# ══════════════════════════════════════════════════════════════════════════════
# THERMAL THROTTLE DETECTION
# ══════════════════════════════════════════════════════════════════════════════

func _check_thermal() -> void:
	if _fps_count > 0:
		_thermal_samples.append(_fps_accum / float(_fps_count))

	if _thermal_check_timer < THERMAL_CHECK_INTERVAL: return
	_thermal_check_timer = 0.0

	while _thermal_samples.size() > MAX_THERMAL_SAMPLES:
		_thermal_samples.pop_front()

	if _thermal_samples.size() < 6: return

	var sum : float = 0.0
	for v in _thermal_samples: sum += v
	var rolling_avg : float = sum / float(_thermal_samples.size())

	if _thermal_baseline_fps <= 0.0:
		_thermal_baseline_fps = rolling_avg
		return

	var drift : float = (_thermal_baseline_fps - rolling_avg) / _thermal_baseline_fps
	if drift >= THERMAL_DRIFT_FRACTION and not _thermal_triggered:
		_thermal_triggered = true
		print("[FR] Thermal throttle suspected — %.0f%% drift. Stepping down." % (drift * 100.0))
		_step_down_profile()
	elif drift < THERMAL_DRIFT_FRACTION * 0.5 and _thermal_triggered:
		_thermal_triggered = false
		print("[FR] Thermal pressure eased.")

func _step_down_profile() -> void:
	match _mode:
		"Quality"  : _schedule_mode("Balanced")
		"Balanced" : _schedule_mode("Performance")

# ══════════════════════════════════════════════════════════════════════════════
# DYNAMIC FSR / AA
# ══════════════════════════════════════════════════════════════════════════════

func _apply_screen_aa(vp: Viewport) -> void:
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if _fxaa_locked_off \
		else Viewport.SCREEN_SPACE_AA_FXAA

func _update_fsr_aa(avg: float) -> void:
	if _fsr_aa_lock_timer > 0.0 or _low_fps: return
	var margin : float = avg - FPS_MINIMUM
	if _fsr_aa_enabled and margin < FSR_AA_OFF_MARGIN:
		_set_fsr_aa(false)
	elif not _fsr_aa_enabled and margin >= FSR_AA_ON_MARGIN:
		_set_fsr_aa(true)

func _set_fsr_aa(enabled: bool) -> void:
	if _fsr_aa_enabled == enabled: return
	_fsr_aa_enabled    = enabled
	_fsr_aa_lock_timer = FSR_AA_LOCK_TIME
	var vp := get_viewport()
	if vp == null: return
	vp.scaling_3d_scale = _current_scale
	if enabled:
		vp.scaling_3d_mode = FSR1
		vp.use_taa         = false
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		print("[FR] FSR on")
	else:
		vp.scaling_3d_mode = FSR_OFF
		vp.use_taa         = false
		_apply_screen_aa(vp)
		print("[FR] FSR off → FXAA")

# ══════════════════════════════════════════════════════════════════════════════
# EVALUATE
# ══════════════════════════════════════════════════════════════════════════════

func _evaluate() -> void:
	var stats : Dictionary = _consume_frametime_stats()
	var avg   : float      = stats["avg_fps"]
	if avg <= 0.0: return

	_last_ft_stats = stats

	_evaluate_shadow(_fps_to_shadow(avg))
	_update_fsr_aa(avg)

	var stuttering : bool = stats.get("stddev", 0.0) > FRAMETIME_STUTTER_THRESHOLD_MS

	if avg < FPS_MINIMUM or stuttering:
		_recovery_timer = 0.0
		if not _low_fps:
			_low_fps = true
			_fxaa_locked_off = true   
			var vp := get_viewport()
			if vp:
				vp.scaling_3d_mode = FSR_OFF
				vp.scaling_3d_scale = _current_scale
				vp.msaa_3d          = AA_OFF
				vp.use_taa          = false
				vp.screen_space_aa  = Viewport.SCREEN_SPACE_AA_DISABLED
		_apply_scale(maxf(_current_scale - SCALE_STEP, _effective_scale_min()))
	else:
		if _low_fps:
			_low_fps           = false
			_fsr_aa_lock_timer = 0.0
			_update_fsr_aa(avg)
		if avg >= FPS_MINIMUM + HYSTERESIS and _recovery_timer >= RECOVERY_COOLDOWN:
			_apply_scale(minf(_current_scale + SCALE_STEP, _effective_scale_max()))
		elif avg < FPS_MINIMUM + HYSTERESIS:
			_apply_scale(maxf(_current_scale - SCALE_STEP, _effective_scale_min()))

	_baseline_fps = lerpf(_baseline_fps, avg, BASELINE_LERP)

# ── Shadow hysteresis guard ──────────────────────────────────────────

func _evaluate_shadow(desired: int) -> void:
	if desired == _shadow_desired:
		_shadow_consecutive_count += 1
		if _shadow_consecutive_count >= SHADOW_HYSTERESIS_CHECKS:
			_apply_shadow(desired)
	else:
		_shadow_desired           = desired
		_shadow_consecutive_count = 1

func _effective_scale_min() -> float:
	var d : float = SCENE_HINT_OFFSETS.get(_scene_hint, {}).get("scale_delta", 0.0)
	return clampf(_profile.get("scale_min", 0.60) + d, 0.40, 1.0)

func _effective_scale_max() -> float:
	var d : float = SCENE_HINT_OFFSETS.get(_scene_hint, {}).get("scale_delta", 0.0)
	return clampf(_profile.get("scale_max", 0.70) + d, 0.40, 1.0)

# ══════════════════════════════════════════════════════════════════════════════
# BENCHMARK
# ══════════════════════════════════════════════════════════════════════════════

func _advance_benchmark_step() -> void:
	if _benchmark_step > 0 and _benchmark_step <= _benchmark_steps.size() and _benchmark_count > 0:
		var step_avg : float = _benchmark_accum / float(_benchmark_count)
		_benchmark_results[_benchmark_steps[_benchmark_step - 1]] = step_avg
		print("[FR] Benchmark %s: %.1f fps" % [_benchmark_steps[_benchmark_step - 1], step_avg])

	_benchmark_accum = 0.0
	_benchmark_count = 0
	_benchmark_timer = 0.0

	if _benchmark_step >= _benchmark_steps.size():
		_benchmarking = false
		var best_mode : String = "Balanced"
		var best_fps  : float  = 0.0
		for mode in _benchmark_results:
			if _benchmark_results[mode] > FPS_MINIMUM and _benchmark_results[mode] > best_fps:
				best_fps  = _benchmark_results[mode]
				best_mode = mode
		print("[FR] Benchmark done. Best: %s (%.1f fps)" % [best_mode, best_fps])
		_save_config(best_mode)
		_schedule_mode(best_mode)
		emit_signal("benchmark_done", _benchmark_results.duplicate())
		return

	var next_mode : String = _benchmark_steps[_benchmark_step]
	_benchmark_step += 1
	_do_load_mode(next_mode)
	print("[FR] Benchmark step %d/%d: %s" % [_benchmark_step, _benchmark_steps.size(), next_mode])

# ══════════════════════════════════════════════════════════════════════════════
# BACKGROUND / FOREGROUND
# ══════════════════════════════════════════════════════════════════════════════

func _connect_window_signals() -> void:
	var win := get_window()
	if win == null: return
	if not win.focus_exited.is_connected(_on_focus_lost):    win.focus_exited.connect(_on_focus_lost)
	if not win.focus_entered.is_connected(_on_focus_gained): win.focus_entered.connect(_on_focus_gained)

func _on_focus_lost() -> void:
	if _is_in_background: return
	_is_in_background = true
	Engine.max_fps = BG_FPS_CAP
	print("[FR] Backgrounded — cap %d fps" % BG_FPS_CAP)

func _on_focus_gained() -> void:
	if not _is_in_background: return
	_is_in_background = false
	Engine.max_fps    = 0
	_warmup_done      = false
	_warmup_timer     = 0.0
	_warmup_fps_accum = 0.0
	_warmup_fps_count = 0
	_fps_accum        = 0.0
	_fps_count        = 0
	_ft_accum         = 0.0
	_ft_sq_accum      = 0.0
	_ft_max           = 0.0
	_check_timer      = 0.0
	print("[FR] Foregrounded — uncapped, re-warmup")

# ══════════════════════════════════════════════════════════════════════════════
# CONFIG PERSISTENCE
# ══════════════════════════════════════════════════════════════════════════════

func _save_config(mode: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("fr", "mode", mode)
	cfg.save(CONFIG_PATH)
	ProjectSettings.set_setting("fr/mode", mode)
	_cached_desired_mode = mode

func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		var saved : String = cfg.get_value("fr", "mode", "Balanced")
		if PROFILES.has(saved):
			ProjectSettings.set_setting("fr/mode", saved)
			_cached_desired_mode = saved
			print("[FR] Loaded profile: %s" % saved)

# ══════════════════════════════════════════════════════════════════════════════
# DEBUG OVERLAY — BUILD / REMOVE
# ══════════════════════════════════════════════════════════════════════════════

func _build_debug_overlay() -> void:
	_debug_canvas       = CanvasLayer.new()
	_debug_canvas.layer = 100
	add_child(_debug_canvas)
	var panel      := Panel.new()
	panel.position  = Vector2(10, 10)
	panel.size      = Vector2(310, 265)
	panel.modulate  = Color(1, 1, 1, 0.82)
	_debug_canvas.add_child(panel)
	_debug_label          = Label.new()
	_debug_label.position = Vector2(14, 10)
	_debug_label.size     = Vector2(290, 250)
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.85))
	panel.add_child(_debug_label)

func _remove_debug_overlay() -> void:
	if _debug_canvas:
		_debug_canvas.queue_free()
		_debug_canvas = null
		_debug_label  = null

# ══════════════════════════════════════════════════════════════════════════════
# RENDERING HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _fps_to_shadow(fps: float) -> int:
	if fps >= FPS_HIGH:      return SHADOW_HIGH
	elif fps >= FPS_MINIMUM: return SHADOW_MID
	else:                    return SHADOW_LOW

func _shadow_to_filter(size: int) -> int:
	return SHADOW_FILTER_HIGH if size == SHADOW_HIGH else (SHADOW_FILTER_MID if size == SHADOW_MID else SHADOW_FILTER_LOW)

func _apply_shadow(size: int) -> void:
	if _current_shadow == size: return
	_current_shadow = size
	var vp := get_viewport()
	if vp == null: return
	vp.positional_shadow_atlas_size = size
	RenderingServer.directional_shadow_atlas_set_size(size, true)
	_apply_shadow_filter(_shadow_to_filter(size))

func _apply_shadow_filter(quality: int) -> void:
	if _current_shadow_filter == quality: return
	_current_shadow_filter = quality
	ProjectSettings.set_setting(SHADOW_FILTER_SETTING, quality)

func _apply_scale(scale: float) -> void:
	if _current_scale == scale: return
	_current_scale = scale
	emit_signal("scale_changed", scale)
	var vp := get_viewport()
	if vp == null: return
	vp.scaling_3d_scale = scale
	vp.scaling_3d_mode  = FSR1 if (_fsr_aa_enabled and not _low_fps) else FSR_OFF

func _apply_lod() -> void:
	if _profile.is_empty(): return
	var threshold : float = _profile.get("lod_threshold", 10.0) + SCENE_HINT_OFFSETS.get(_scene_hint, {}).get("lod_delta", 0.0)
	ProjectSettings.set_setting(LOD_SETTING, threshold)
	var vp := get_viewport()
	if vp: vp.mesh_lod_threshold = threshold

func _apply_effects() -> void:
	if _profile.is_empty(): return
	ProjectSettings.set_setting(TEX_FILTER_SETTING,       _profile.get("tex_filter",     0))
	ProjectSettings.set_setting(SSAO_SETTING,             _profile.get("ssao_quality",   0))
	ProjectSettings.set_setting(SSIL_SETTING,             _profile.get("ssil_quality",   0))
	ProjectSettings.set_setting(SDFGI_PROBE_RAYS_SETTING, _profile.get("sdfgi_rays",     SDFGI_RAYS_LOW))
	ProjectSettings.set_setting(SDFGI_FRAMES_CONVERGE,    _profile.get("sdfgi_converge", SDFGI_CONVERGE_LOW))
	ProjectSettings.set_setting(SDFGI_FRAMES_UPDATE,      _profile.get("sdfgi_lights",   SDFGI_LIGHT_LOW))

func _reset_to_defaults() -> void:
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode              = FSR_OFF
		vp.scaling_3d_scale             = 1.0
		vp.msaa_3d                      = AA_OFF
		vp.use_taa                      = false
		vp.screen_space_aa              = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.positional_shadow_atlas_size = SHADOW_MID
		vp.mesh_lod_threshold           = 2.0
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_MID, true)
	ProjectSettings.set_setting(LOD_SETTING,              1.0)
	ProjectSettings.set_setting(SSAO_SETTING,             0)
	ProjectSettings.set_setting(SSIL_SETTING,             0)
	ProjectSettings.set_setting(TEX_FILTER_SETTING,       0)
	ProjectSettings.set_setting(SDFGI_PROBE_RAYS_SETTING, SDFGI_RAYS_LOW)
	ProjectSettings.set_setting(SDFGI_FRAMES_CONVERGE,    SDFGI_CONVERGE_LOW)
	ProjectSettings.set_setting(SDFGI_FRAMES_UPDATE,      SDFGI_LIGHT_LOW)
	_apply_shadow_filter(SHADOW_FILTER_LOW)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_current_scale         = 0.0
	_current_shadow        = SHADOW_MID
	_current_shadow_filter = SHADOW_FILTER_MID
	_fsr_aa_enabled        = false
	_fsr_aa_lock_timer     = 0.0
	_low_fps               = false
	_warmup_done           = false
	_warmup_timer          = 0.0
	_warmup_fps_accum      = 0.0
	_warmup_fps_count      = 0
	_fps_accum             = 0.0
	_fps_count             = 0
	_ft_accum              = 0.0
	_ft_sq_accum           = 0.0
	_ft_max                = 0.0
	_check_timer           = 0.0
	_recovery_timer        = 0.0
	_baseline_fps          = 0.0
	_config_save_pending   = false
	_fxaa_locked_off       = false        
	_shadow_desired           = SHADOW_MID   
	_shadow_consecutive_count = 0           
	_thermal_samples.clear()
	_thermal_triggered     = false
	_thermal_baseline_fps  = 0.0
	_last_ft_stats         = {}

func _schedule_mode(mode: String) -> void:
	if _profile_switch_timer > 0.0:
		_pending_mode = mode
		return
	if _mode == mode:
		return
	_pending_mode         = mode
	_profile_switch_timer = PROFILE_SWITCH_COOLDOWN

func _do_load_mode(mode: String) -> void:
	if not PROFILES.has(mode): return
	var prev_mode : String = _mode
	_mode              = mode
	_profile           = PROFILES[mode]
	_warmup_done       = false
	_warmup_timer      = 0.0
	_warmup_fps_accum  = 0.0
	_warmup_fps_count  = 0
	_low_fps           = false
	_recovery_timer    = 0.0
	_fsr_aa_enabled    = false
	_fsr_aa_lock_timer = 0.0
	_fps_accum         = 0.0
	_fps_count         = 0
	_ft_accum          = 0.0
	_ft_sq_accum       = 0.0
	_ft_max            = 0.0
	# [FIX-4] reset hysteresis عند تغيير الـ mode
	_shadow_desired           = SHADOW_MID
	_shadow_consecutive_count = 0
	_apply_scale(_profile["scale_min"])
	_apply_lod()
	_apply_effects()
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = FSR_OFF
		vp.msaa_3d         = AA_OFF
		vp.use_taa         = false
		_apply_screen_aa(vp)
	if prev_mode != mode:
		emit_signal("profile_changed", mode)

func _load_mode(mode: String) -> void:
	_do_load_mode(mode)

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

func SetEnabled(value: bool) -> void:
	if _enabled == value: return
	_enabled = value
	if not _enabled: _reset_to_defaults()
	else: _load_mode(_mode)

func is_enabled() -> bool: return _enabled

func Performance() -> void:
	if not _enabled: return
	_schedule_mode("Performance")
	_save_config("Performance")

func Balanced() -> void:
	if not _enabled: return
	_schedule_mode("Balanced")
	_save_config("Balanced")

func Quality() -> void:
	if not _enabled: return
	_schedule_mode("Quality")
	_save_config("Quality")

func SetSceneHint(hint: String) -> void:
	if not SCENE_HINT_OFFSETS.has(hint):
		push_warning("[FR] Unknown scene hint '%s'. Use 'light', 'normal', or 'heavy'." % hint)
		return
	_scene_hint = hint
	_apply_lod()
	print("[FR] Scene hint: '%s'" % hint)

func RunBenchmark() -> void:
	if _benchmarking: return
	print("[FR] Benchmark started.")
	_benchmarking      = true
	_benchmark_step    = 0
	_benchmark_timer   = 0.0
	_benchmark_results = {}
	_benchmark_accum   = 0.0
	_benchmark_count   = 0
	_advance_benchmark_step()

func SetDebugOverlay(value: bool) -> void:
	_debug_overlay_enabled = value
	if value:
		if _debug_canvas == null: _build_debug_overlay()
	else:
		_remove_debug_overlay()

# ══════════════════════════════════════════════════════════════════════════════
# GETTERS
# ══════════════════════════════════════════════════════════════════════════════

func get_mode()           -> String: return _mode
func get_scene_hint()     -> String: return _scene_hint
func get_scale()          -> String: return "%d%%" % int(_current_scale * 100)
func get_scale_float()    -> float:  return _current_scale  
func get_shadow()         -> String: return str(_current_shadow)
func get_physics_ticks()  -> int:    return Engine.physics_ticks_per_second
func get_recovery_timer() -> float:  return _recovery_timer
func get_baseline_fps()   -> float:  return _baseline_fps
func get_thermal_state()  -> String: return "triggered" if _thermal_triggered else "ok"
func is_in_background()   -> bool:   return _is_in_background
func is_benchmarking()    -> bool:   return _benchmarking
func get_lod_threshold()  -> float:  return _profile.get("lod_threshold", 1.0)

func get_shadow_filter() -> String:
	match _current_shadow_filter:
		SHADOW_FILTER_HIGH : return "High (PCF13)"
		SHADOW_FILTER_MID  : return "Mid (PCF5)"
		_                  : return "Low (disabled)"

func get_fsr() -> String: return "FSR 1" if _fsr_aa_enabled else "OFF"

func get_aa() -> String:
	if _fsr_aa_enabled and not _low_fps:
		return "Disabled (FSR active)"
	if _fxaa_locked_off:
		return "Disabled (low FPS lock)"
	return "FXAA"

func get_ssao_quality() -> String:
	var labels : Array[String] = ["Very Low", "Low", "Low-Med", "Medium", "High"]
	var q : int = _profile.get("ssao_quality", 0)
	return labels[q] if q >= 0 and q < labels.size() else "?"

func get_ssil_quality() -> String:
	var labels : Array[String] = ["Very Low", "Low", "Low-Med", "Medium", "High"]
	var q : int = _profile.get("ssil_quality", 0)
	return labels[q] if q >= 0 and q < labels.size() else "?"

func get_sdfgi_quality() -> String:
	if _profile.is_empty(): return "?"
	var rays_map  := { 0: "8 rays",  1: "16 rays", 2: "32 rays", 3: "64 rays" }
	var conv_map  := { 0: "5f",  1: "10f", 2: "15f", 3: "20f", 4: "25f", 5: "30f" }
	var light_map := { 1: "every 2f", 2: "every 4f", 3: "every 8f" }
	return "Rays:%s  Conv:%s  Lights:%s" % [
		rays_map.get(_profile.get("sdfgi_rays",     SDFGI_RAYS_LOW),     "?"),
		conv_map.get(_profile.get("sdfgi_converge", SDFGI_CONVERGE_LOW), "?"),
		light_map.get(_profile.get("sdfgi_lights",  SDFGI_LIGHT_LOW),    "?"),
	]

func get_frametime_stats() -> Dictionary: return _last_ft_stats
