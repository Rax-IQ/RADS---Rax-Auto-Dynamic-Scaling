@tool
extends EditorPlugin

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  FR – FrameReflex  |  plugin.gd                                              ║
# ║  Bottom Panel with Performance / Balanced / Quality / Custom                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

const AUTOLOAD_NAME     := "FRManager"
const AUTOLOAD_PATH     := "res://addons/Frame Reflex/FRManager.gd"
const MODE_SETTING      := "fr/mode"
const CUSTOM_CFG_PATH   := "user://fr_custom_mode.cfg"

# LOD threshold per built-in mode
const MODE_LOD_THRESHOLD := {
	"Performance": 15.0,
	"Balanced":    10.0,
	"Quality":     5.0,
}

# ── CUSTOM MODE DEFAULTS (mirrors FRManager.gd) ────────────────────────────────
const CUSTOM_DEFAULTS := {
	"name":              "Custom",
	"scale_min":         0.65,
	"scale_max":         0.75,
	"shadow_min":        1024,
	"shadow_max":        2048,
	"shadow_filter_min": 0,
	"shadow_filter_max": 1,
	"fps_min":           60.0,
	"fps_max":           144.0,
	"tex_viewport":      1,
	"aa_mode":           1,
	"aa_min":            0,
	"aa_max":            1,
	"sdfgi_enabled":     false,
	"sdfgi_rays":        0,
	"sdfgi_converge":    0,
	"sdfgi_lights":      3,
	"ssil_enabled":      false,
	"ssil_quality":      0,
	"ssao_enabled":      false,
	"ssao_quality":      0,
	"ssr_enabled":       false,
	"ssr_quality":       0,
	"lod_min":           5.0,
	"lod_max":           15.0,
	"lod_threshold":     10.0,
	"smooth_time":       1.5,
	"compatibility_mode": false,
	"mobile_mode":       false,
	"show_prints":       true,
	"tex_filter":        1,
	"fsr_enabled":       true,
	"fsr_scale_min":     0.50,
	"fsr_scale_max":     0.75,
}

# ── Root panel ─────────────────────────────────────────────────────────────────
var _root_panel : Control = null  # TabContainer lives here

# Custom mode config (editor-side copy)
var _custom : Dictionary = {}

# ── Ref to controls we need to read/write ─────────────────────────────────────
var _name_edit         : LineEdit       = null
var _current_mode_lbl  : Label          = null

# resolution
var _res_min_spin      : SpinBox        = null
var _res_max_spin      : SpinBox        = null

# shadow atlas
var _shadow_min_opt    : OptionButton   = null
var _shadow_max_opt    : OptionButton   = null

# shadow filter
var _sfilter_min_opt   : OptionButton   = null
var _sfilter_max_opt   : OptionButton   = null

# fps
var _fps_min_spin      : SpinBox        = null
var _fps_max_spin      : SpinBox        = null

# tex viewport
var _tex_vp_opt        : OptionButton   = null

# AA
var _aa_min_opt        : OptionButton   = null
var _aa_max_opt        : OptionButton   = null

# FSR
var _fsr_check         : CheckBox       = null
var _fsr_scale_min_spin: SpinBox        = null
var _fsr_scale_max_spin: SpinBox        = null

# SDFGI
var _sdfgi_check       : CheckBox       = null
var _sdfgi_rays_opt    : OptionButton   = null
var _sdfgi_conv_opt    : OptionButton   = null
var _sdfgi_light_opt   : OptionButton   = null

# SSIL
var _ssil_check        : CheckBox       = null
var _ssil_min_opt      : OptionButton   = null
var _ssil_max_opt      : OptionButton   = null

# SSAO
var _ssao_check        : CheckBox       = null
var _ssao_min_opt      : OptionButton   = null
var _ssao_max_opt      : OptionButton   = null

# SSR
var _ssr_check         : CheckBox       = null
var _ssr_min_opt       : OptionButton   = null
var _ssr_max_opt       : OptionButton   = null

# LOD
var _lod_min_spin      : SpinBox        = null
var _lod_max_spin      : SpinBox        = null

# Smooth time
var _smooth_spin       : SpinBox        = null

# Flags
var _compat_check      : CheckBox       = null
var _mobile_check      : CheckBox       = null
var _prints_check      : CheckBox       = null

# Export / Import output
var _export_text       : TextEdit       = null
var _import_text       : TextEdit       = null
var _import_status_lbl : Label          = null

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _enter_tree() -> void:
	if _root_panel != null:
		return
	_load_custom_cfg()
	_build_root_panel()
	add_control_to_bottom_panel(_root_panel, "FR Modes | Addon")
	_register_autoload()


func _exit_tree() -> void:
	if _root_panel != null:
		remove_control_from_bottom_panel(_root_panel)
		_root_panel.queue_free()
		_root_panel = null
	_unregister_autoload()

# ══════════════════════════════════════════════════════════════════════════════
# AUTOLOAD
# ══════════════════════════════════════════════════════════════════════════════

func _register_autoload() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _unregister_autoload() -> void:
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)

# ══════════════════════════════════════════════════════════════════════════════
# CUSTOM CONFIG
# ══════════════════════════════════════════════════════════════════════════════

func _load_custom_cfg() -> void:
	_custom = {}
	for k in CUSTOM_DEFAULTS:
		_custom[k] = CUSTOM_DEFAULTS[k]
	var cfg := ConfigFile.new()
	if cfg.load(CUSTOM_CFG_PATH) == OK:
		for k in CUSTOM_DEFAULTS:
			if cfg.has_section_key("custom", k):
				_custom[k] = cfg.get_value("custom", k)


func _save_custom_cfg() -> void:
	var cfg := ConfigFile.new()
	for k in _custom:
		cfg.set_value("custom", k, _custom[k])
	cfg.save(CUSTOM_CFG_PATH)

	ProjectSettings.set_setting("fr/custom_name", _custom.get("name", "Custom"))
	ProjectSettings.save()

# ══════════════════════════════════════════════════════════════════════════════
# ROOT PANEL — TabContainer with two tabs
# ══════════════════════════════════════════════════════════════════════════════

func _build_root_panel() -> void:
	_root_panel      = Control.new()
	_root_panel.name = "FR Modes | Addon"
	_root_panel.set_custom_minimum_size(Vector2(0, 120))

	var tabs := TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_panel.add_child(tabs)

	# ── Tab 0: Quick switch ─────────────────────────────────────────────────
	var quick_tab := _build_quick_tab()
	quick_tab.name = "Modes"
	tabs.add_child(quick_tab)

	# ── Tab 1: Custom mode editor ───────────────────────────────────────────
	var custom_tab := _build_custom_tab()
	custom_tab.name = "Custom Mode"
	tabs.add_child(custom_tab)


# ══════════════════════════════════════════════════════════════════════════════
# TAB 0 — Quick switch
# ══════════════════════════════════════════════════════════════════════════════

func _build_quick_tab() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var title_lbl := Label.new()
	title_lbl.text = "FR   |"
	title_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(title_lbl)

	_current_mode_lbl      = Label.new()
	_current_mode_lbl.name = "CurrentMode"
	_refresh_mode_label()
	hbox.add_child(_current_mode_lbl)
	hbox.add_child(VSeparator.new())

	var modes := [
		["Performance", Color(0.9, 0.45, 0.3)],
		["Balanced",    Color(0.9, 0.8,  0.3)],
		["Quality",     Color(0.3, 0.8,  0.5)],
	]
	for m in modes:
		var btn := Button.new()
		btn.text = m[0]
		btn.flat = true
		btn.add_theme_color_override("font_color", m[1])
		btn.pressed.connect(_on_builtin_mode_pressed.bind(m[0]))
		hbox.add_child(btn)

	var custom_btn := Button.new()
	custom_btn.text = _custom.get("name", "Custom")
	custom_btn.flat = true
	custom_btn.add_theme_color_override("font_color", Color(0.6, 0.5, 1.0))
	custom_btn.pressed.connect(_on_custom_mode_quick_pressed.bind(custom_btn))
	custom_btn.name = "CustomQuickBtn"
	hbox.add_child(custom_btn)

	hbox.add_child(VSeparator.new())

	var info := Label.new()
	info.name = "InfoLabel"
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_refresh_info_label(info)
	hbox.add_child(info)

	hbox.add_child(VSeparator.new())

	var lod_lbl := Label.new()
	lod_lbl.name = "LODLabel"
	lod_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 0.9))
	_refresh_lod_label(lod_lbl)
	hbox.add_child(lod_lbl)

	return hbox


# ══════════════════════════════════════════════════════════════════════════════
# TAB 1 — Custom Mode Editor
# ══════════════════════════════════════════════════════════════════════════════

func _build_custom_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_custom_minimum_size(Vector2(0, 100))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Mode Name ───────────────────────────────────────────────────────────
	var name_row := _hrow("Mode Name")
	_name_edit = LineEdit.new()
	_name_edit.text = _custom.get("name", "Custom")
	_name_edit.set_custom_minimum_size(Vector2(140, 0))
	_name_edit.text_submitted.connect(_on_name_changed)
	name_row.add_child(_name_edit)
	vbox.add_child(name_row)

	vbox.add_child(_separator())

	# ── Resolution (scale) ──────────────────────────────────────────────────
	var res_row := _hrow("Resolution Scale  Min / Max  (%)")
	_res_min_spin = _spinbox(30, 100, 1, int(_custom.get("scale_min", 0.65) * 100.0))
	_res_max_spin = _spinbox(30, 100, 1, int(_custom.get("scale_max", 0.75) * 100.0))
	res_row.add_child(_res_min_spin)
	res_row.add_child(Label.new())  
	res_row.add_child(_res_max_spin)
	vbox.add_child(res_row)

	# ── Shadow Atlas ────────────────────────────────────────────────────────
	var sha_row := _hrow("Shadow Atlas  Min / Max")
	_shadow_min_opt = _option(["512", "1024", "2048"], _shadow_to_idx(_custom.get("shadow_min", 1024)))
	_shadow_max_opt = _option(["512", "1024", "2048"], _shadow_to_idx(_custom.get("shadow_max", 2048)))
	sha_row.add_child(_shadow_min_opt)
	sha_row.add_child(Label.new())
	sha_row.add_child(_shadow_max_opt)
	vbox.add_child(sha_row)

	# ── Shadow Filter ───────────────────────────────────────────────────────
	var sf_row := _hrow("Shadow Filter  Min / Max")
	_sfilter_min_opt = _option(["Low (off)", "Mid (PCF5)", "High (PCF13)"], _custom.get("shadow_filter_min", 0))
	_sfilter_max_opt = _option(["Low (off)", "Mid (PCF5)", "High (PCF13)"], _custom.get("shadow_filter_max", 1))
	sf_row.add_child(_sfilter_min_opt)
	sf_row.add_child(Label.new())
	sf_row.add_child(_sfilter_max_opt)
	vbox.add_child(sf_row)

	# ── FPS Range ───────────────────────────────────────────────────────────
	var fps_row := _hrow("FPS Range  Min / Max")
	_fps_min_spin = _spinbox(10, 500, 1, int(_custom.get("fps_min", 60.0)))
	_fps_max_spin = _spinbox(10, 500, 1, int(_custom.get("fps_max", 144.0)))
	fps_row.add_child(_fps_min_spin)
	fps_row.add_child(Label.new())
	fps_row.add_child(_fps_max_spin)
	vbox.add_child(fps_row)

	vbox.add_child(_separator())

	# ── Texture Viewport ────────────────────────────────────────────────────
	var tvp_row := _hrow("Texture Viewport")
	_tex_vp_opt = _option(["Nearest", "Linear"], _custom.get("tex_viewport", 1))
	tvp_row.add_child(_tex_vp_opt)
	vbox.add_child(tvp_row)

	# ── Anti-Aliasing ───────────────────────────────────────────────────────
	var aa_row := _hrow("Anti-Aliasing  Min / Max")
	_aa_min_opt = _option(["Off", "FXAA", "TAA"], _custom.get("aa_min", 0))
	_aa_max_opt = _option(["Off", "FXAA", "TAA"], _custom.get("aa_max", 1))
	aa_row.add_child(_aa_min_opt)
	aa_row.add_child(Label.new())
	aa_row.add_child(_aa_max_opt)
	vbox.add_child(aa_row)

	# ── FSR ─────────────────────────────────────────────────────────────────
	var fsr_row := _hrow("FSR (Upscaling)")
	_fsr_check = _checkbox("Enable", _custom.get("fsr_enabled", true))
	_fsr_check.toggled.connect(_on_fsr_toggled)
	fsr_row.add_child(_fsr_check)
	vbox.add_child(fsr_row)

	var fsr_detail_row := _hrow("  FSR Scale  Min / Max  (%)")
	_fsr_scale_min_spin = _spinbox(30, 100, 1, int(_custom.get("fsr_scale_min", 0.50) * 100.0))
	_fsr_scale_max_spin = _spinbox(30, 100, 1, int(_custom.get("fsr_scale_max", 0.75) * 100.0))
	fsr_detail_row.add_child(_fsr_scale_min_spin)
	fsr_detail_row.add_child(Label.new())
	fsr_detail_row.add_child(_fsr_scale_max_spin)
	vbox.add_child(fsr_detail_row)
	_update_fsr_controls_state()

	vbox.add_child(_separator())

	# ── LOD ─────────────────────────────────────────────────────────────────
	var lod_row := _hrow("LOD Threshold  Min / Max  (px)")
	_lod_min_spin = _spinboxf(0.0, 50.0, 0.5, _custom.get("lod_min", 5.0))
	_lod_max_spin = _spinboxf(0.0, 50.0, 0.5, _custom.get("lod_max", 15.0))
	lod_row.add_child(_lod_min_spin)
	lod_row.add_child(Label.new())
	lod_row.add_child(_lod_max_spin)
	vbox.add_child(lod_row)

	# ── Smooth Time ─────────────────────────────────────────────────────────
	var st_row := _hrow("Smooth Time  (s)")
	_smooth_spin = _spinboxf(0.1, 10.0, 0.1, _custom.get("smooth_time", 1.5))
	st_row.add_child(_smooth_spin)
	vbox.add_child(st_row)

	vbox.add_child(_separator())

	# ── SDFGI ───────────────────────────────────────────────────────────────
	var sdfgi_row := _hrow("SDFGI")
	_sdfgi_check = _checkbox("Enable", _custom.get("sdfgi_enabled", false))
	_sdfgi_check.toggled.connect(_on_sdfgi_toggled)
	sdfgi_row.add_child(_sdfgi_check)
	var sdfgi_detail_row := _hrow("  Rays / Converge / Lights")
	_sdfgi_rays_opt  = _option(["8", "16", "32", "64"], _custom.get("sdfgi_rays", 0))
	_sdfgi_conv_opt  = _option(["5f", "10f", "15f", "20f", "25f", "30f"], _custom.get("sdfgi_converge", 0))
	_sdfgi_light_opt = _option(["every 2f", "every 4f", "every 8f"], _sdfgi_lights_to_idx(_custom.get("sdfgi_lights", 3)))
	sdfgi_detail_row.add_child(_sdfgi_rays_opt)
	sdfgi_detail_row.add_child(_sdfgi_conv_opt)
	sdfgi_detail_row.add_child(_sdfgi_light_opt)
	vbox.add_child(sdfgi_row)
	vbox.add_child(sdfgi_detail_row)
	_update_sdfgi_controls_state()

	# ── SSIL ────────────────────────────────────────────────────────────────
	var ssil_row := _hrow("SSIL")
	_ssil_check = _checkbox("Enable", _custom.get("ssil_enabled", false))
	_ssil_check.toggled.connect(_on_ssil_toggled)
	ssil_row.add_child(_ssil_check)
	var ssil_detail_row := _hrow("  Quality  Min / Max")
	_ssil_min_opt = _option(["Very Low", "Low", "Low-Med", "Medium", "High"], 0)
	_ssil_max_opt = _option(["Very Low", "Low", "Low-Med", "Medium", "High"], _custom.get("ssil_quality", 0))
	ssil_detail_row.add_child(_ssil_min_opt)
	ssil_detail_row.add_child(Label.new())
	ssil_detail_row.add_child(_ssil_max_opt)
	vbox.add_child(ssil_row)
	vbox.add_child(ssil_detail_row)
	_update_ssil_controls_state()

	# ── SSAO ────────────────────────────────────────────────────────────────
	var ssao_row := _hrow("SSAO")
	_ssao_check = _checkbox("Enable", _custom.get("ssao_enabled", false))
	_ssao_check.toggled.connect(_on_ssao_toggled)
	ssao_row.add_child(_ssao_check)
	var ssao_detail_row := _hrow("  Quality  Min / Max")
	_ssao_min_opt = _option(["Very Low", "Low", "Low-Med", "Medium", "High"], 0)
	_ssao_max_opt = _option(["Very Low", "Low", "Low-Med", "Medium", "High"], _custom.get("ssao_quality", 0))
	ssao_detail_row.add_child(_ssao_min_opt)
	ssao_detail_row.add_child(Label.new())
	ssao_detail_row.add_child(_ssao_max_opt)
	vbox.add_child(ssao_row)
	vbox.add_child(ssao_detail_row)
	_update_ssao_controls_state()

	# ── SSR ─────────────────────────────────────────────────────────────────
	var ssr_row := _hrow("SSR")
	_ssr_check = _checkbox("Enable", _custom.get("ssr_enabled", false))
	_ssr_check.toggled.connect(_on_ssr_toggled)
	ssr_row.add_child(_ssr_check)
	var ssr_detail_row := _hrow("  Quality  Min / Max")
	_ssr_min_opt = _option(["Disabled", "Low", "Medium", "High", "Ultra"], 0)
	_ssr_max_opt = _option(["Disabled", "Low", "Medium", "High", "Ultra"], _custom.get("ssr_quality", 0))
	ssr_detail_row.add_child(_ssr_min_opt)
	ssr_detail_row.add_child(Label.new())
	ssr_detail_row.add_child(_ssr_max_opt)
	vbox.add_child(ssr_row)
	vbox.add_child(ssr_detail_row)
	_update_ssr_controls_state()

	vbox.add_child(_separator())

	# ── Compatibility / Mobile / Prints ─────────────────────────────────────
	var flags_row := HBoxContainer.new()
	flags_row.add_theme_constant_override("separation", 12)
	_compat_check  = _checkbox("Compatibility Mode", _custom.get("compatibility_mode", false))
	_mobile_check  = _checkbox("Mobile Mode",        _custom.get("mobile_mode",        false))
	_prints_check  = _checkbox("Show Prints",        _custom.get("show_prints",        true))
	_compat_check.toggled.connect(_on_compat_toggled)
	_mobile_check.toggled.connect(_on_mobile_toggled)
	flags_row.add_child(_compat_check)
	flags_row.add_child(_mobile_check)
	flags_row.add_child(_prints_check)
	vbox.add_child(flags_row)

	vbox.add_child(_separator())

	# ── Action buttons ───────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	var apply_btn := Button.new()
	apply_btn.text = "Apply Custom"
	apply_btn.add_theme_color_override("font_color", Color(0.6, 0.5, 1.0))
	apply_btn.pressed.connect(_on_apply_custom_pressed)
	btn_row.add_child(apply_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Default"
	reset_btn.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
	reset_btn.pressed.connect(_on_reset_custom_pressed)
	btn_row.add_child(reset_btn)

	var export_btn := Button.new()
	export_btn.text = "Export Mode"
	export_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.7))
	export_btn.pressed.connect(_on_export_pressed)
	btn_row.add_child(export_btn)

	vbox.add_child(btn_row)

	vbox.add_child(_separator())

	# ── Export area ─────────────────────────────────────────────────────────
	var exp_lbl := Label.new()
	exp_lbl.text = "► Export — copy this text to share your config:"
	exp_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.7))
	vbox.add_child(exp_lbl)

	_export_text = TextEdit.new()
	_export_text.set_custom_minimum_size(Vector2(0, 90))
	_export_text.editable        = false
	_export_text.wrap_mode       = TextEdit.LINE_WRAPPING_BOUNDARY
	_export_text.placeholder_text = "Click 'Export Mode' above to generate…"
	vbox.add_child(_export_text)

	vbox.add_child(_separator())

	# ── Import area ─────────────────────────────────────────────────────────
	var imp_lbl := Label.new()
	imp_lbl.text = "► Import — paste an exported config below then click Import:"
	imp_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	vbox.add_child(imp_lbl)

	_import_text = TextEdit.new()
	_import_text.set_custom_minimum_size(Vector2(0, 90))
	_import_text.wrap_mode        = TextEdit.LINE_WRAPPING_BOUNDARY
	_import_text.placeholder_text = "Paste exported config here…"
	vbox.add_child(_import_text)

	var imp_btn_row := HBoxContainer.new()
	imp_btn_row.add_theme_constant_override("separation", 8)

	var import_btn := Button.new()
	import_btn.text = "Import Mode"
	import_btn.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	import_btn.pressed.connect(_on_import_pressed)
	imp_btn_row.add_child(import_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.flat = true
	clear_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	clear_btn.pressed.connect(_on_import_clear_pressed)
	imp_btn_row.add_child(clear_btn)

	vbox.add_child(imp_btn_row)

	_import_status_lbl = Label.new()
	_import_status_lbl.text = ""
	_import_status_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_import_status_lbl)

	return scroll

# ══════════════════════════════════════════════════════════════════════════════
# UI HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _hrow(label_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.set_custom_minimum_size(Vector2(220, 0))
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	hbox.add_child(lbl)
	return hbox


func _separator() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = Color(0.3, 0.3, 0.3, 0.5)
	return s


func _spinbox(minv: int, maxv: int, step: int, value: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = minv
	sb.max_value = maxv
	sb.step      = step
	sb.value     = value
	sb.set_custom_minimum_size(Vector2(70, 0))
	return sb


func _spinboxf(minv: float, maxv: float, step: float, value: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = minv
	sb.max_value = maxv
	sb.step      = step
	sb.value     = value
	sb.set_custom_minimum_size(Vector2(80, 0))
	return sb


func _option(items: Array, selected: int) -> OptionButton:
	var ob := OptionButton.new()
	for item in items:
		ob.add_item(item)
	ob.selected = clamp(selected, 0, items.size() - 1)
	ob.set_custom_minimum_size(Vector2(110, 0))
	return ob


func _checkbox(label_text: String, checked: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text    = label_text
	cb.button_pressed = checked
	return cb


func _shadow_to_idx(size: int) -> int:
	match size:
		512:  return 0
		2048: return 2
		_:    return 1


func _idx_to_shadow(idx: int) -> int:
	match idx:
		0: return 512
		2: return 2048
		_: return 1024


func _sdfgi_lights_to_idx(val: int) -> int:
	match val:
		1: return 0
		2: return 1
		_: return 2

func _idx_to_sdfgi_lights(idx: int) -> int:
	match idx:
		0: return 1
		1: return 2
		_: return 3

# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — mode buttons
# ══════════════════════════════════════════════════════════════════════════════

func _on_builtin_mode_pressed(mode: String) -> void:
	ProjectSettings.set_setting(MODE_SETTING, mode)
	ProjectSettings.save()
	var cfg := ConfigFile.new()
	cfg.set_value("fr", "mode", mode)
	cfg.save("user://fr_config.cfg")
	_refresh_mode_label()
	_refresh_quick_tab_info()


func _on_custom_mode_quick_pressed(btn: Button) -> void:
	ProjectSettings.set_setting(MODE_SETTING, "Custom")
	ProjectSettings.save()
	var cfg := ConfigFile.new()
	cfg.set_value("fr", "mode", "Custom")
	cfg.save("user://fr_config.cfg")
	_refresh_mode_label()
	_refresh_quick_tab_info()

# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — custom tab
# ══════════════════════════════════════════════════════════════════════════════

func _on_name_changed(new_name: String) -> void:
	_custom["name"] = new_name
	_save_custom_cfg()
	# Update quick-switch button label
	if _root_panel != null:
		var tabs := _root_panel.get_child(0) as TabContainer
		if tabs:
			var quick_tab := tabs.get_child(0) as HBoxContainer
			if quick_tab:
				var qbtn := quick_tab.get_node_or_null("CustomQuickBtn") as Button
				if qbtn:
					qbtn.text = new_name


func _on_sdfgi_toggled(_pressed: bool) -> void:
	_update_sdfgi_controls_state()


func _on_ssil_toggled(_pressed: bool) -> void:
	_update_ssil_controls_state()


func _on_ssao_toggled(_pressed: bool) -> void:
	_update_ssao_controls_state()


func _on_ssr_toggled(_pressed: bool) -> void:
	_update_ssr_controls_state()


func _on_fsr_toggled(_pressed: bool) -> void:
	_update_fsr_controls_state()


func _on_compat_toggled(pressed: bool) -> void:
	if pressed and _mobile_check != null:
		_mobile_check.button_pressed = false


func _on_mobile_toggled(pressed: bool) -> void:
	if pressed and _compat_check != null:
		_compat_check.button_pressed = false


func _on_apply_custom_pressed() -> void:
	_collect_custom_from_ui()
	_save_custom_cfg()
	ProjectSettings.set_setting(MODE_SETTING, "Custom")
	ProjectSettings.save()
	var cfg := ConfigFile.new()
	cfg.set_value("fr", "mode", "Custom")
	cfg.save("user://fr_config.cfg")
	_refresh_mode_label()
	_refresh_quick_tab_info()
	print("[FR Plugin] Custom mode applied: %s" % _custom.get("name", "Custom"))


func _on_reset_custom_pressed() -> void:
	_custom = {}
	for k in CUSTOM_DEFAULTS:
		_custom[k] = CUSTOM_DEFAULTS[k]
	_save_custom_cfg()
	_populate_ui_from_custom()
	print("[FR Plugin] Custom mode reset to defaults.")


func _on_export_pressed() -> void:
	_collect_custom_from_ui()
	var lines : Array[String] = []
	lines.append("# FR Custom Mode Export — " + _custom.get("name", "Custom"))
	lines.append("{")
	for key in _custom:
		var val = _custom[key]
		if val is String:
			lines.append('\t"%s": "%s",' % [key, val])
		elif val is bool:
			lines.append('\t"%s": %s,' % [key, "true" if val else "false"])
		elif val is float:
			lines.append('\t"%s": %.4f,' % [key, val])
		else:
			lines.append('\t"%s": %s,' % [key, str(val)])
	lines.append("}")
	if _export_text != null:
		_export_text.text = "\n".join(lines)


func _on_import_pressed() -> void:
	if _import_text == null:
		return
	var raw : String = _import_text.text.strip_edges()
	if raw.is_empty():
		_set_import_status("Nothing to import — paste a config first.", false)
		return

	# Strip the comment header line if present
	var raw_lines : PackedStringArray = raw.split("\n")
	var cleaned_lines : PackedStringArray = PackedStringArray()
	for line in raw_lines:
		var l : String = (line as String).strip_edges()
		if l.begins_with("#"):
			continue
		cleaned_lines.append(line)
	var cleaned : String = "\n".join(cleaned_lines).strip_edges()

	# Parse with Godot's expression evaluator (safe — only parses literals)
	var expr := Expression.new()
	var err : int = expr.parse(cleaned)
	if err != OK:
		_set_import_status("Parse error — make sure you pasted the full exported block.", false)
		return

	var result = expr.execute([], null, true)
	if expr.has_execute_failed():
		_set_import_status("Execution error — invalid config format.", false)
		return

	if not result is Dictionary:
		_set_import_status("Error — pasted text is not a valid config dictionary.", false)
		return

	# Merge only known keys, coerce types to match defaults
	var parsed : Dictionary = result as Dictionary
	var merged : int = 0
	for key in CUSTOM_DEFAULTS:
		if parsed.has(key):
			var expected = CUSTOM_DEFAULTS[key]
			var incoming = parsed[key]
			# Safe type coercion
			if expected is float and incoming is int:
				incoming = float(incoming)
			elif expected is int and incoming is float:
				incoming = int(incoming)
			elif expected is bool and incoming is int:
				incoming = incoming != 0
			_custom[key] = incoming
			merged += 1

	if merged == 0:
		_set_import_status("No recognisable keys found — wrong format?", false)
		return

	_save_custom_cfg()
	_populate_ui_from_custom()

	var mode_name : String = _custom.get("name", "Custom")
	_set_import_status("✓ Imported '%s' (%d keys loaded)" % [mode_name, merged], true)
	print("[FR Plugin] Import success: '%s'  (%d keys)" % [mode_name, merged])


func _on_import_clear_pressed() -> void:
	if _import_text != null:
		_import_text.text = ""
	_set_import_status("", true)


func _set_import_status(msg: String, ok: bool) -> void:
	if _import_status_lbl == null:
		return
	_import_status_lbl.text = msg
	_import_status_lbl.add_theme_color_override(
		"font_color",
		Color(0.4, 0.9, 0.5) if ok else Color(1.0, 0.4, 0.4)
	)

# ══════════════════════════════════════════════════════════════════════════════
# COLLECT UI → _custom dict
# ══════════════════════════════════════════════════════════════════════════════

func _collect_custom_from_ui() -> void:
	if _name_edit       != null: _custom["name"]              = _name_edit.text
	if _res_min_spin    != null: _custom["scale_min"]         = _res_min_spin.value / 100.0
	if _res_max_spin    != null: _custom["scale_max"]         = _res_max_spin.value / 100.0
	if _shadow_min_opt  != null: _custom["shadow_min"]        = _idx_to_shadow(_shadow_min_opt.selected)
	if _shadow_max_opt  != null: _custom["shadow_max"]        = _idx_to_shadow(_shadow_max_opt.selected)
	if _sfilter_min_opt != null: _custom["shadow_filter_min"] = _sfilter_min_opt.selected
	if _sfilter_max_opt != null: _custom["shadow_filter_max"] = _sfilter_max_opt.selected
	if _fps_min_spin    != null: _custom["fps_min"]           = _fps_min_spin.value
	if _fps_max_spin    != null: _custom["fps_max"]           = _fps_max_spin.value
	if _tex_vp_opt      != null: _custom["tex_viewport"]      = _tex_vp_opt.selected
	if _aa_min_opt      != null: _custom["aa_min"]            = _aa_min_opt.selected
	if _aa_max_opt      != null:
		_custom["aa_max"]  = _aa_max_opt.selected
		_custom["aa_mode"] = _aa_max_opt.selected
	if _fsr_check           != null: _custom["fsr_enabled"]   = _fsr_check.button_pressed
	if _fsr_scale_min_spin  != null: _custom["fsr_scale_min"] = _fsr_scale_min_spin.value / 100.0
	if _fsr_scale_max_spin  != null: _custom["fsr_scale_max"] = _fsr_scale_max_spin.value / 100.0
	if _sdfgi_check     != null: _custom["sdfgi_enabled"]     = _sdfgi_check.button_pressed
	if _sdfgi_rays_opt  != null: _custom["sdfgi_rays"]        = _sdfgi_rays_opt.selected
	if _sdfgi_conv_opt  != null: _custom["sdfgi_converge"]    = _sdfgi_conv_opt.selected
	if _sdfgi_light_opt != null: _custom["sdfgi_lights"]      = _idx_to_sdfgi_lights(_sdfgi_light_opt.selected)
	if _ssil_check      != null: _custom["ssil_enabled"]      = _ssil_check.button_pressed
	if _ssil_max_opt    != null: _custom["ssil_quality"]      = _ssil_max_opt.selected
	if _ssao_check      != null: _custom["ssao_enabled"]      = _ssao_check.button_pressed
	if _ssao_max_opt    != null: _custom["ssao_quality"]      = _ssao_max_opt.selected
	if _ssr_check       != null: _custom["ssr_enabled"]       = _ssr_check.button_pressed
	if _ssr_max_opt     != null: _custom["ssr_quality"]       = _ssr_max_opt.selected
	if _lod_min_spin    != null: _custom["lod_min"]           = _lod_min_spin.value
	if _lod_max_spin    != null:
		_custom["lod_max"]       = _lod_max_spin.value
		_custom["lod_threshold"] = (_custom.get("lod_min", 5.0) + _lod_max_spin.value) * 0.5
	if _smooth_spin     != null: _custom["smooth_time"]       = _smooth_spin.value
	if _compat_check    != null: _custom["compatibility_mode"] = _compat_check.button_pressed
	if _mobile_check    != null: _custom["mobile_mode"]       = _mobile_check.button_pressed
	if _prints_check    != null: _custom["show_prints"]       = _prints_check.button_pressed
	# tex_filter follows tex_viewport for simplicity
	_custom["tex_filter"] = _custom.get("tex_viewport", 1)

# ══════════════════════════════════════════════════════════════════════════════
# POPULATE UI ← _custom dict
# ══════════════════════════════════════════════════════════════════════════════

func _populate_ui_from_custom() -> void:
	if _name_edit       != null: _name_edit.text               = _custom.get("name", "Custom")
	if _res_min_spin    != null: _res_min_spin.value            = _custom.get("scale_min", 0.65) * 100.0
	if _res_max_spin    != null: _res_max_spin.value            = _custom.get("scale_max", 0.75) * 100.0
	if _shadow_min_opt  != null: _shadow_min_opt.selected       = _shadow_to_idx(_custom.get("shadow_min", 1024))
	if _shadow_max_opt  != null: _shadow_max_opt.selected       = _shadow_to_idx(_custom.get("shadow_max", 2048))
	if _sfilter_min_opt != null: _sfilter_min_opt.selected      = clamp(_custom.get("shadow_filter_min", 0), 0, 2)
	if _sfilter_max_opt != null: _sfilter_max_opt.selected      = clamp(_custom.get("shadow_filter_max", 1), 0, 2)
	if _fps_min_spin    != null: _fps_min_spin.value            = _custom.get("fps_min", 60.0)
	if _fps_max_spin    != null: _fps_max_spin.value            = _custom.get("fps_max", 144.0)
	if _tex_vp_opt      != null: _tex_vp_opt.selected           = clamp(_custom.get("tex_viewport", 1), 0, 1)
	if _aa_min_opt      != null: _aa_min_opt.selected           = clamp(_custom.get("aa_min", 0), 0, 2)
	if _aa_max_opt      != null: _aa_max_opt.selected           = clamp(_custom.get("aa_max", 1), 0, 2)
	if _fsr_check           != null: _fsr_check.button_pressed      = _custom.get("fsr_enabled", true)
	if _fsr_scale_min_spin  != null: _fsr_scale_min_spin.value      = _custom.get("fsr_scale_min", 0.50) * 100.0
	if _fsr_scale_max_spin  != null: _fsr_scale_max_spin.value      = _custom.get("fsr_scale_max", 0.75) * 100.0
	if _sdfgi_check     != null: _sdfgi_check.button_pressed    = _custom.get("sdfgi_enabled", false)
	if _sdfgi_rays_opt  != null: _sdfgi_rays_opt.selected       = clamp(_custom.get("sdfgi_rays", 0), 0, 3)
	if _sdfgi_conv_opt  != null: _sdfgi_conv_opt.selected       = clamp(_custom.get("sdfgi_converge", 0), 0, 5)
	if _sdfgi_light_opt != null: _sdfgi_light_opt.selected      = _sdfgi_lights_to_idx(_custom.get("sdfgi_lights", 3))
	if _ssil_check      != null: _ssil_check.button_pressed     = _custom.get("ssil_enabled", false)
	if _ssil_max_opt    != null: _ssil_max_opt.selected         = clamp(_custom.get("ssil_quality", 0), 0, 4)
	if _ssao_check      != null: _ssao_check.button_pressed     = _custom.get("ssao_enabled", false)
	if _ssao_max_opt    != null: _ssao_max_opt.selected         = clamp(_custom.get("ssao_quality", 0), 0, 4)
	if _ssr_check       != null: _ssr_check.button_pressed      = _custom.get("ssr_enabled", false)
	if _ssr_max_opt     != null: _ssr_max_opt.selected          = clamp(_custom.get("ssr_quality", 0), 0, 4)
	if _lod_min_spin    != null: _lod_min_spin.value            = _custom.get("lod_min", 5.0)
	if _lod_max_spin    != null: _lod_max_spin.value            = _custom.get("lod_max", 15.0)
	if _smooth_spin     != null: _smooth_spin.value             = _custom.get("smooth_time", 1.5)
	if _compat_check    != null: _compat_check.button_pressed   = _custom.get("compatibility_mode", false)
	if _mobile_check    != null: _mobile_check.button_pressed   = _custom.get("mobile_mode", false)
	if _prints_check    != null: _prints_check.button_pressed   = _custom.get("show_prints", true)
	_update_sdfgi_controls_state()
	_update_ssil_controls_state()
	_update_ssao_controls_state()
	_update_ssr_controls_state()
	_update_fsr_controls_state()

# ══════════════════════════════════════════════════════════════════════════════
# CONTROL ENABLE / DISABLE  (based on checkbox state)
# ══════════════════════════════════════════════════════════════════════════════

func _update_sdfgi_controls_state() -> void:
	var on : bool = _sdfgi_check != null and _sdfgi_check.button_pressed
	if _sdfgi_rays_opt  != null: _sdfgi_rays_opt.disabled  = not on
	if _sdfgi_conv_opt  != null: _sdfgi_conv_opt.disabled  = not on
	if _sdfgi_light_opt != null: _sdfgi_light_opt.disabled = not on


func _update_ssil_controls_state() -> void:
	var on : bool = _ssil_check != null and _ssil_check.button_pressed
	if _ssil_min_opt != null: _ssil_min_opt.disabled = not on
	if _ssil_max_opt != null: _ssil_max_opt.disabled = not on


func _update_ssao_controls_state() -> void:
	var on : bool = _ssao_check != null and _ssao_check.button_pressed
	if _ssao_min_opt != null: _ssao_min_opt.disabled = not on
	if _ssao_max_opt != null: _ssao_max_opt.disabled = not on


func _update_ssr_controls_state() -> void:
	var on : bool = _ssr_check != null and _ssr_check.button_pressed
	if _ssr_min_opt != null: _ssr_min_opt.disabled = not on
	if _ssr_max_opt != null: _ssr_max_opt.disabled = not on


func _update_fsr_controls_state() -> void:
	var on : bool = _fsr_check != null and _fsr_check.button_pressed
	if _fsr_scale_min_spin != null: _fsr_scale_min_spin.editable = on
	if _fsr_scale_max_spin != null: _fsr_scale_max_spin.editable = on
	# Dim the spinboxes visually when FSR is off
	var alpha : float = 1.0 if on else 0.4
	if _fsr_scale_min_spin != null: _fsr_scale_min_spin.modulate = Color(1, 1, 1, alpha)
	if _fsr_scale_max_spin != null: _fsr_scale_max_spin.modulate = Color(1, 1, 1, alpha)

# ══════════════════════════════════════════════════════════════════════════════
# REFRESH LABELS — Quick tab
# ══════════════════════════════════════════════════════════════════════════════

func _refresh_mode_label() -> void:
	if _current_mode_lbl == null:
		return
	var mode := ProjectSettings.get_setting(MODE_SETTING, "Balanced") as String
	var display : String = mode
	if mode == "Custom":
		display = _custom.get("name", "Custom")
	var colors := {
		"Performance": Color(0.9, 0.45, 0.3),
		"Balanced":    Color(0.9, 0.8,  0.3),
		"Quality":     Color(0.3, 0.8,  0.5),
		"Custom":      Color(0.6, 0.5,  1.0),
	}
	_current_mode_lbl.text = "[ " + display + " ]"
	_current_mode_lbl.add_theme_color_override("font_color", colors.get(mode, Color.WHITE))


func _refresh_quick_tab_info() -> void:
	if _root_panel == null:
		return
	var tabs := _root_panel.get_child(0) as TabContainer
	if tabs == null:
		return
	var quick_tab := tabs.get_child(0)
	if quick_tab == null:
		return
	var info_lbl := quick_tab.get_node_or_null("InfoLabel") as Label
	if info_lbl:
		_refresh_info_label(info_lbl)
	var lod_lbl := quick_tab.get_node_or_null("LODLabel") as Label
	if lod_lbl:
		_refresh_lod_label(lod_lbl)


func _refresh_info_label(lbl: Label) -> void:
	var mode := ProjectSettings.get_setting(MODE_SETTING, "Balanced") as String
	if mode == "Custom":
		var s_min : int  = int(_custom.get("scale_min", 0.65) * 100.0)
		var s_max : int  = int(_custom.get("scale_max", 0.75) * 100.0)
		var aa    : int  = _custom.get("aa_mode", 1)
		var aa_str : String = ["Off", "FXAA", "TAA"][clamp(aa, 0, 2)]
		lbl.text = "AA: %s  |  Scale %d-%d%%" % [aa_str, s_min, s_max]
		return
	var info := {
		"Performance": "FSR OFF | FXAA | Scale 60-70%",
		"Balanced":    "FSR 1   | FXAA | Scale 65-75%",
		"Quality":     "FSR 1   | FXAA | Scale 75-80%",
	}
	lbl.text = info.get(mode, "")


func _refresh_lod_label(lbl: Label) -> void:
	var mode := ProjectSettings.get_setting(MODE_SETTING, "Balanced") as String
	if mode == "Custom":
		var t : float = _custom.get("lod_threshold", 10.0)
		lbl.text = "LOD  %.2f px" % t
		return
	var t : float = MODE_LOD_THRESHOLD.get(mode, 1.0)
	lbl.text = "LOD  %.2f px" % t
