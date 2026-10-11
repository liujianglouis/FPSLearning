extends Node3D
# 手枪射击原型：腰射 / 开镜 两种射击模式
# 默认腰射（枪在右下角）；按鼠标右键切换开镜（枪移到屏幕中央照准）
# 挂载位置：Main 节点

@export_group("腰射姿态 Hip")
@export var hip_position: Vector3 = Vector3(0.13, 0.038, -0.19)   # 枪在相机空间的位置（y 让枪底贴着屏幕底边）
@export var hip_rotation_degrees: Vector3 = Vector3(0, 0, 0)      # 摆正（想让腰射略微向内偏就改这个 Y）

@export_group("开镜姿态 ADS")
@export var ads_position: Vector3 = Vector3(0, -0.030, -0.13)     # y = -照门中心y，让瞄准轴对齐相机中心线
@export var ads_rotation_degrees: Vector3 = Vector3(0, 0, 0)      # 摆正，照门对上屏幕中心

@export_group("过渡")
@export var aim_switch_time: float = 0.15   # 两种姿态之间的切换时长（秒）

var is_aiming: bool = false                 # false = 腰射，true = 开镜

@onready var pistol: Node3D = $"Camera3D/手枪_Pistol"
@onready var animation_player: AnimationPlayer = $"Camera3D/手枪_Pistol/动画播放器_AnimationPlayer"

var _aim_tween: Tween                       # 记录正在跑的过渡，切换时冲掉旧的

func _ready() -> void:
	# 初始化为腰射姿态（默认模式）
	_apply_pose(hip_position, hip_rotation_degrees)

func _unhandled_input(event: InputEvent) -> void:
	# 左键按下 → 播放开火动画（is_action_pressed 只在“刚按下”那一帧为 true，按住不连发）
	if event.is_action_pressed("fire"):
		animation_player.play("fire")
	# 右键按下 → 在腰射 / 开镜之间切换
	if event.is_action_pressed("aim"):
		_toggle_aim()

# 切换射击模式
func _toggle_aim() -> void:
	is_aiming = not is_aiming
	# 根据当前模式选出目标姿态
	var target_pos: Vector3 = ads_position if is_aiming else hip_position
	var target_rot: Vector3 = ads_rotation_degrees if is_aiming else hip_rotation_degrees
	_move_pistol(target_pos, target_rot)

# 用 Tween 把 手枪_Pistol 平滑移动到目标姿态
func _move_pistol(target_pos: Vector3, target_rot_deg: Vector3) -> void:
	# 先杀掉上一个还没跑完的过渡，否则两个 tween 会互相打架
	if _aim_tween and _aim_tween.is_valid():
		_aim_tween.kill()
	_aim_tween = create_tween()
	_aim_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_aim_tween.set_parallel(true)   # 位置和旋转同时进行
	_aim_tween.tween_property(pistol, "position", target_pos, aim_switch_time)
	_aim_tween.tween_property(pistol, "rotation_degrees", target_rot_deg, aim_switch_time)

# 立即摆到某个姿态（不做过渡）
func _apply_pose(pos: Vector3, rot_deg: Vector3) -> void:
	pistol.position = pos
	pistol.rotation_degrees = rot_deg
