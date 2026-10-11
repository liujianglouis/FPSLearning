extends Node3D
# 手枪射击原型：腰射 / 开镜 姿态 + 单发 / 连发 射击模式
# 默认腰射 + 连发；右键切换腰射/开镜，B 键切换单发/连发
# 挂载位置：Main 节点

# 射击模式：单发 / 连发（格洛克 18 就是可切换的单连发）
enum FireMode { SEMI, AUTO }

@export_group("腰射姿态 Hip")
@export var hip_position: Vector3 = Vector3(0.13, -0.196, -0.46)  # 枪在相机空间的位置（z 越远枪越小；y 让枪底贴着屏幕底边）
@export var hip_rotation_degrees: Vector3 = Vector3(0, 8, 0)      # 略微向内偏，枪口朝屏幕中心

@export_group("开镜姿态 ADS")
@export var ads_position: Vector3 = Vector3(0, -0.030, -0.22)     # y = -照门中心y，让瞄准轴对齐相机中心线；z 越远枪越小
@export var ads_rotation_degrees: Vector3 = Vector3(0, 0, 0)      # 摆正，照门对上屏幕中心

@export_group("镜头缩放 FOV")
@export var hip_fov: float = 80.0   # 腰射：视野更广（数值越大看得越宽）
@export var ads_fov: float = 50.0   # 开镜：放大（数值越小放得越大）

@export_group("射击模式 Fire Mode")
@export var fire_mode: FireMode = FireMode.AUTO   # 默认连发（全自动格洛克）；游戏里按 B 切换
@export var auto_fire_interval: float = 0.08      # 连发间隔（秒），约 750 发/分

@export_group("过渡")
@export var aim_switch_time: float = 0.15   # 两种姿态之间的切换时长（秒）

var is_aiming: bool = false                 # false = 腰射，true = 开镜
var _auto_firing: bool = false              # 连发时：开火键是否仍按着
var _auto_timer: float = 0.0                # 连发计时器

@onready var camera: Camera3D = $Camera3D
@onready var pistol: Node3D = $"Camera3D/手枪_Pistol"
@onready var animation_player: AnimationPlayer = $"Camera3D/手枪_Pistol/动画播放器_AnimationPlayer"
@onready var fire_sound: AudioStreamPlayer = $"Camera3D/手枪_Pistol/开火音效_FireSound"

var _aim_tween: Tween                       # 记录正在跑的过渡，切换时冲掉旧的

func _ready() -> void:
	# 初始化为腰射姿态（默认模式）
	_apply_pose(hip_position, hip_rotation_degrees)
	# 腰射视野
	camera.fov = hip_fov

func _unhandled_input(event: InputEvent) -> void:
	# ---- 开火 ----
	if event.is_action_pressed("fire"):
		if fire_mode == FireMode.AUTO:
			# 连发：按下先立刻打一发，之后交给 _physics_process 持续打
			_auto_firing = true
			_auto_timer = auto_fire_interval
			_shoot()
		else:
			# 单发：按一次只打一发
			_shoot()
	if event.is_action_released("fire"):
		# 松开开火键 → 停止连发
		_auto_firing = false

	# ---- 右键：腰射 / 开镜 ----
	if event.is_action_pressed("aim"):
		_toggle_aim()

	# ---- B 键：单发 / 连发 ----
	if event.is_action_pressed("switch_fire_mode"):
		fire_mode = FireMode.SEMI if fire_mode == FireMode.AUTO else FireMode.AUTO
		_auto_firing = false
		print("射击模式：", "连发" if fire_mode == FireMode.AUTO else "单发")


func _physics_process(delta: float) -> void:
	# 连发：按着开火键时，按固定间隔持续开火
	if fire_mode == FireMode.AUTO and _auto_firing:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = auto_fire_interval
			_shoot()


# 打一发（播放套筒后坐动画 + 开火音效）
func _shoot() -> void:
	animation_player.play("fire")
	fire_sound.play()

# 切换射击模式
func _toggle_aim() -> void:
	is_aiming = not is_aiming
	# 根据当前模式选出目标姿态和视野
	var target_pos: Vector3 = ads_position if is_aiming else hip_position
	var target_rot: Vector3 = ads_rotation_degrees if is_aiming else hip_rotation_degrees
	var target_fov: float = ads_fov if is_aiming else hip_fov
	_move_pistol(target_pos, target_rot, target_fov)

# 用 Tween 把 手枪_Pistol 平滑移动到目标姿态，同时缩放镜头
func _move_pistol(target_pos: Vector3, target_rot_deg: Vector3, target_fov: float) -> void:
	# 先杀掉上一个还没跑完的过渡，否则两个 tween 会互相打架
	if _aim_tween and _aim_tween.is_valid():
		_aim_tween.kill()
	_aim_tween = create_tween()
	_aim_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_aim_tween.set_parallel(true)   # 位置、旋转、视野三者同时进行
	_aim_tween.tween_property(pistol, "position", target_pos, aim_switch_time)
	_aim_tween.tween_property(pistol, "rotation_degrees", target_rot_deg, aim_switch_time)
	_aim_tween.tween_property(camera, "fov", target_fov, aim_switch_time)

# 立即摆到某个姿态（不做过渡）
func _apply_pose(pos: Vector3, rot_deg: Vector3) -> void:
	pistol.position = pos
	pistol.rotation_degrees = rot_deg
