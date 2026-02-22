# RADS---Rax-Auto-Dynamic-Scaling

RADS – Rax Auto Dynamic Scaling
Version: 1.0
Engine: Godot 4.3+ | Renderer: Forward+ or Mobile (required for FSR)

WHAT IS RADS?
RADS is a DLSS-like addon that automatically adjusts your game's rendering quality in real time based on current FPS, so the game always runs as smoothly as possible without manual tweaking.

It controls four things at the same time:

3D Resolution Scale (how many pixels are rendered before upscaling)

FSR mode (FSR 2 = quality, FSR 1 = fast, OFF = native)

Anti-Aliasing (TAA + MSAA / FXAA / OFF depending on mode)

Shadow Atlas Size (shadow quality based on FPS tier)

INSTALLATION

Copy the folder addons/rss/ into your project's res://addons/ folder.

Your structure should look like this:

res://
└── addons/
└── rss/
├── plugin.cfg
├── plugin.gd
└── rss_manager.gd

Open Project → Project Settings → Plugins

Enable "RADS – Rax Auto Dynamic Scaling"

A new tab called "RADS" appears in the bottom panel

Done. RADS runs automatically in gameplay.

BOTTOM PANEL

After enabling the plugin you will see the RADS tab in the bottom panel.

RADS | [ Balanced ] | Performance Balanced Quality | (info)

Click any button to switch the default mode.
The selection is saved in Project Settings under rads/mode.

MODES

PERFORMANCE

FSR: OFF

AA: OFF

Scale low: 25%

Scale high: 35%

Best for low-end devices

BALANCED

FSR: FSR 1 on drop / FSR 2 on recover

AA: FXAA

Scale low: 35%

Scale high: 60%

Recommended default

QUALITY

FSR: FSR 1 on drop / FSR 2 on recover

AA: MSAA 4x + TAA

Scale low: 50%

Scale high: 75%

Best image quality

SHADOW ATLAS

FPS < 60 → Shadow atlas = 524
FPS ≥ 60 → Shadow atlas = 2024
FPS ≥ 300 → Shadow atlas = 4028

Both Omni/Spot and Directional lights are affected.

FPS RULES

FPS < 60 → FSR OFF + lowest scale + AA OFF + shadow 524
FPS drops 5+ below baseline → low scale + FSR 1
FPS recovers 5+ above baseline → high scale + FSR 2

Baseline is a rolling average to avoid sudden switching.

AUTOLOAD

When enabled, the plugin registers an Autoload called RADSManager.

You can call it from anywhere:

RADSManager.Performance()
RADSManager.Balanced()
RADSManager.Quality()

It is removed automatically when the plugin is disabled.

PUBLIC FUNCTIONS

Mode Switchers:

RADSManager.Performance()
RADSManager.Balanced()
RADSManager.Quality()

Info Getters:

RADSManager.get_mode() → String
RADSManager.get_scale() → String
RADSManager.get_fsr() → String
RADSManager.get_aa() → String
RADSManager.get_shadow() → String

USAGE EXAMPLES

Switch via UI:

func _on_performance_button_pressed() -> void:
RADSManager.Performance()

func _on_balanced_button_pressed() -> void:
RADSManager.Balanced()

func _on_quality_button_pressed() -> void:
RADSManager.Quality()

Show info:

func _process(_delta) -> void:
$Label.text = "%s | %s | %s | Shadow %s" % [
RADSManager.get_mode(),
RADSManager.get_scale(),
RADSManager.get_fsr(),
RADSManager.get_shadow()
]

Platform-based switch:

func _ready() -> void:
if OS.get_name() == "Android" or OS.get_name() == "iOS":
RADSManager.Performance()
else:
RADSManager.Balanced()

NOTES

FSR 2 requires Forward+ or Mobile renderer.

Not compatible with Compatibility renderer.

TAA may cause ghosting.

RADS writes to ProjectSettings for persistence.

Does not run inside the editor (Engine.is_editor_hint guard).

Runs only during gameplay.
