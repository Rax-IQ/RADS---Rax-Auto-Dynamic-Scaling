extends Node

@export var auto_enable : bool = false
@export var debug_mode  : bool = false

var _enabled    : bool = false
var _canvas     : CanvasLayer
var _debug_rect : ColorRect
var _frame_count : int = 0


# -- Lifecycle ---------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if auto_enable:
		enable()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _enabled:
		return
	
	_frame_count += 1
	
	if is_instance_valid(_debug_rect):
		_debug_rect.visible = debug_mode


# -- Public API --------------------------------------------------------

func enable() -> void:
	if _enabled:
		return
	
	_build_pipeline()
	_enabled = true


func disable() -> void:
	if not _enabled:
		return
	
	_teardown_pipeline()
	_enabled = false


func set_debug(enabled: bool) -> void:
	debug_mode = enabled


func is_enabled() -> bool:
	return _enabled


func get_frame_count() -> int:
	return _frame_count


# -- Pipeline ----------------------------------------------------------

func _build_pipeline() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 128
	add_child(_canvas)

	# Debug red overlay فقط
	_debug_rect = ColorRect.new()
	_debug_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_rect.color = Color(1.0, 0.0, 0.0, 0.15)
	_debug_rect.visible = debug_mode
	
	_canvas.add_child(_debug_rect)


func _teardown_pipeline() -> void:
	if is_instance_valid(_canvas):
		_canvas.queue_free()
	
	_canvas = null
	_debug_rect = null
	_frame_count = 0
