extends CharacterBody3D
# 第一人称角色控制器：WASD 移动 + 鼠标视角 + 重力 + 跳跃
# 角色本身不需要渲染（没有模型），只有胶囊碰撞体 + 相机
# 挂载位置：玩家_Player

@export var move_speed: float = 5.0            # 移动速度（米/秒）
@export var mouse_sensitivity: float = 0.002   # 鼠标灵敏度
@export var jump_velocity: float = 4.5         # 跳跃初速度（米/秒）
@export var gravity: float = 9.8               # 重力加速度
@export var initial_pitch_deg: float = -8.0    # 初始俯仰角（负值 = 低头）：让准心落在 2m 外靶子的胸口正面

@onready var pitch_pivot: Node3D = $俯仰_PitchPivot


func _ready() -> void:
	# 初始俯仰：不低头的话，1.6m 的视线会正好擦着靶子躯干顶面过去（弹痕贴到朝上的面，看不见）
	pitch_pivot.rotation_degrees.x = initial_pitch_deg
	# 捕获鼠标：让鼠标移动直接控制视角
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	# —— 鼠标视角 ——
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# 左右：转整个角色（绕世界 Y 轴），这样走路方向也跟着转
		rotate_y(-event.relative.x * mouse_sensitivity)
		# 上下：只转"俯仰枢轴"，不转身体本身
		# （否则身体会跟着前倾，走路方向就会被带偏）
		pitch_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		# 限制俯仰角，避免抬头/低头超过 90 度翻过去
		pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	# 按 Esc 释放鼠标（方便在窗口外操作 / 关闭游戏）
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	# —— 重力 ——
	if not is_on_floor():
		velocity.y -= gravity * delta

	# —— 跳跃（空格）——
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# —— WASD 移动 ——
	# get_vector 返回二维向量：x = 左右，y = 前后（前为负）
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# 只取角色朝向的 Y 轴（水平方向）来换算移动方向
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		# 没输入：水平速度平滑减到 0，避免瞬间停住
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()
