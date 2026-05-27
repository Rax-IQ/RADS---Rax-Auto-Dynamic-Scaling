@tool
extends EditorPlugin

# ──────────────────────────────────────────────
#  FR – FrameReflex  |  plugin.gd
#  Bottom Panel with Performance / Balanced / Quality
# ──────────────────────────────────────────────

const AUTOLOAD_NAME := "FRManager"
const AUTOLOAD_PATH := "res://addons/fr/FRManager.gd"
const MODE_SETTING  := "fr/mode"

# LOD threshold per mode — must match PROFILES in FRManager.gd
const MODE_LOD_THRESHOLD := {
	"Performance": 15.0,
	"Balanced":    10.0,
	"Quality":     5.0,
}

var _panel : HBoxContainer

# ── Lifecycle ──────────────────────────────────
func _enter_tree() -> void:
	if _panel != null:
		return
	_build_panel()
	add_control_to_bottom_panel(_panel, "FR Modes | Addon")
	_register_autoload()

func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
	_unregister_autoload()

# ── Autoload ───────────────────────────────────
func _register_autoload() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _unregister_autoload() -> void:
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)

# ── UI ─────────────────────────────────────────
func _build_panel() -> void:
	_panel = HBoxContainer.new()
	_panel.name = "FR Modes | Addon"
	_panel.add_theme_constant_override("separation", 12)

	# -- Label
	var lbl := Label.new()
	lbl.text = "FR   |"
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_panel.add_child(lbl)

	# -- Current mode indicator
	var current_lbl := Label.new()
	current_lbl.name = "CurrentMode"
	_refresh_mode_label(current_lbl)
	_panel.add_child(current_lbl)
	_panel.add_child(VSeparator.new())

	# -- Mode buttons
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
		btn.pressed.connect(_on_mode_pressed.bind(m[0], current_lbl))
		_panel.add_child(btn)

	_panel.add_child(VSeparator.new())

	# -- Info label (AA / Scale)
	var info := Label.new()
	info.name = "InfoLabel"
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_refresh_info_label(info)
	_panel.add_child(info)

	_panel.add_child(VSeparator.new())

	# -- LOD label
	var lod_lbl := Label.new()
	lod_lbl.name = "LODLabel"
	lod_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 0.9))
	_refresh_lod_label(lod_lbl)
	_panel.add_child(lod_lbl)

# ── Button pressed ─────────────────────────────
func _on_mode_pressed(mode: String, lbl: Label) -> void:
	ProjectSettings.set_setting(MODE_SETTING, mode)
	ProjectSettings.save()

	var cfg := ConfigFile.new()
	cfg.set_value("fr", "mode", mode)
	cfg.save("user://fr_config.cfg")

	_refresh_mode_label(lbl)

	var info := _panel.get_node_or_null("InfoLabel")
	if info:
		_refresh_info_label(info)

	var lod_lbl := _panel.get_node_or_null("LODLabel")
	if lod_lbl:
		_refresh_lod_label(lod_lbl)

# ── Helpers ────────────────────────────────────
func _refresh_mode_label(lbl: Label) -> void:
	var mode := ProjectSettings.get_setting(MODE_SETTING, "Balanced") as String
	var colors := {
		"Performance": Color(0.9, 0.45, 0.3),
		"Balanced":    Color(0.9, 0.8,  0.3),
		"Quality":     Color(0.3, 0.8,  0.5),
	}
	lbl.text = "[ " + mode + " ]"
	lbl.add_theme_color_override("font_color", colors.get(mode, Color.WHITE))

func _refresh_info_label(lbl: Label) -> void:
	var mode := ProjectSettings.get_setting(MODE_SETTING, "Balanced") as String
	var info := {
		"Performance": "FSR OFF | FXAA       | Scale 55-65%",
		"Balanced":    "FSR 1   | FXAA       | Scale 55 - 65%",
		"Quality":     "FSR 1   | FXAA       | Scale 65-75%",
	}
	lbl.text = info.get(mode, "")

func _refresh_lod_label(lbl: Label) -> void:
	var mode := ProjectSettings.get_setting(MODE_SETTING, "Balanced") as String
	var t : float = MODE_LOD_THRESHOLD.get(mode, 1.0)
	lbl.text = "LOD  %.2f px" % t
