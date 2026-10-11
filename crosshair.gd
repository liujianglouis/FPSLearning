extends CanvasLayer
# 屏幕中心准星（HUD）：四段细线 + 可选中心点，纯代码绘制，不依赖任何图片资源
# 支持"动态准心"：外部调用 set_spread_radius() 传入当前散布的屏幕半径，准心会平滑张合
# 挂载位置：Main 节点下的 准星_Crosshair

@export_group("准星 Crosshair")
@export var line_length: float = 8.0      # 每条线的长度（像素）
@export var line_gap: float = 5.0         # 基础中心空隙（像素），也是准星的最小张开半径
@export var line_thickness: float = 2.0   # 线的粗细（像素）
@export var line_color: Color = Color(0.15, 1.0, 0.45, 0.9)   # 准星颜色
@export var dot_size: float = 0.0         # 中心点大小（像素），0 = 不画
@export var gap_smooth_speed: float = 14.0  # 准心张合的平滑速度（越大越跟手）

var _bars: Array[ColorRect] = []   # 顺序：上 下 左 右
var _dot: ColorRect = null
var _gap: float = 0.0              # 当前显示的半宽（像素）
var _target_gap: float = 0.0       # 目标半宽（= 当前散布的屏幕半径）


func _ready() -> void:
	_gap = line_gap
	_target_gap = line_gap

	# 根 Control 铺满屏幕，只作为居中参照，不拦截鼠标
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 居中的 0 尺寸 Control：子节点用负偏移就能画出"以屏幕中心为原点"的准星
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	# 上、下、左、右四段（尺寸固定，位置随散布张合）
	_bars.append(_make_bar(center, Vector2(line_thickness, line_length)))
	_bars.append(_make_bar(center, Vector2(line_thickness, line_length)))
	_bars.append(_make_bar(center, Vector2(line_length, line_thickness)))
	_bars.append(_make_bar(center, Vector2(line_length, line_thickness)))
	# 中心点（可选）
	if dot_size > 0.0:
		_dot = _make_bar(center, Vector2(dot_size, dot_size))
	_apply_gap(_gap)


func _process(delta: float) -> void:
	if absf(_gap - _target_gap) > 0.01:
		_gap = lerpf(_gap, _target_gap, clampf(gap_smooth_speed * delta, 0.0, 1.0))
		_apply_gap(_gap)


# 由外部（gun.gd）传入当前散布在屏幕上的半径（像素）
func set_spread_radius(radius_px: float) -> void:
	_target_gap = maxf(line_gap, radius_px)


# 按当前半宽摆放四段线
func _apply_gap(gap: float) -> void:
	_bars[0].position = Vector2(-line_thickness * 0.5, -gap - line_length)   # 上
	_bars[1].position = Vector2(-line_thickness * 0.5, gap)                  # 下
	_bars[2].position = Vector2(-gap - line_length, -line_thickness * 0.5)   # 左
	_bars[3].position = Vector2(gap, -line_thickness * 0.5)                  # 右
	if _dot:
		_dot.position = Vector2(-dot_size * 0.5, -dot_size * 0.5)


# 建一段矩形准星线
func _make_bar(parent: Control, size: Vector2) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = line_color
	bar.size = size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar
