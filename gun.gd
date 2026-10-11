extends Node3D
# 手枪射击原型：腰射 / 开镜 姿态 + 单发 / 连发 射击模式
# 默认腰射 + 连发；右键切换腰射/开镜，B 键切换单发/连发
# 后坐力分两层：① 相机（准心被顶走，打在弹道上）② 武器自身（枪模型自己上抬/摆动，纯视觉）
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

@export_group("后坐力 Recoil")
@export var recoil_enabled: bool = true
@export var vertical_recoil_deg: float = 1.8      # 每发上抬（度）
@export var horizontal_recoil_deg: float = 0.675  # 每发左右随机 ± 范围（度）
@export var recoil_recovery_speed: float = 18.0   # 画面被"顶"上去的快慢（越大越猛）
@export var recoil_return_speed: float = 5.0      # 停火后回正的快慢（完全回正的关键）
@export var recoil_max_deg: float = 12.0          # 累积上限，兜底

@export_group("武器后坐 Weapon Kick")
@export var weapon_kick_up_deg: float = 4.5           # 开火瞬间枪口上抬（度）——枪自己动，比准心更"猛"
@export var weapon_kick_side_deg: float = 1.8         # 水平摆动幅度（度），方向跟着这一发的弹道偏移
@export var weapon_kick_recovery_speed: float = 22.0  # 枪"顿"到位的快慢（越大越瞬间）
@export var weapon_kick_return_speed: float = 9.0     # 枪回正的快慢（比相机快 → 枪比准心先回来）
@export var weapon_kick_max_deg: float = 10.0         # 累积上限，兜底

@export_group("镜头抖动 Camera Shake")
@export var shake_enabled: bool = true                 # 总开关（COD 里也是可关闭的设置项）
@export var shake_trauma_per_shot: float = 0.55        # 每发累加的 trauma（0~1），连发会叠加
@export var shake_decay: float = 1.8                   # trauma 每秒衰减速度（保证一定会回正）
@export var shake_max_deg: float = 1.2                 # trauma 拉满时的最大旋转抖动幅度（度）
@export var shake_frequency: float = 24.0              # 噪声频率（Hz）：越大抖得越"碎"
@export var shake_ads_mult: float = 0.4                # 开镜时的抖动倍率（举镜 = 端稳）

@export_group("枪口特效 Muzzle FX")
@export var muzzle_flash_enabled: bool = true                    # 枪口火焰开关
@export var muzzle_flash_color: Color = Color(1, 0.88, 0.6)      # 火焰（和闪光灯）的颜色
@export var muzzle_flash_scale: float = 1.0                      # 火焰大小倍率
@export var muzzle_flash_time: float = 0.045                     # 火焰亮多久（秒）：只亮 2~3 帧
@export var muzzle_light_energy: float = 0.9                     # 闪光灯亮度（会照亮周围环境）
@export var smoke_enabled: bool = true                           # 枪口烟开关
@export var smoke_lifetime: float = 0.55                         # 每团烟存活多久（秒）
@export var smoke_size: float = 0.16                             # 烟的最终大小（米）
@export var smoke_drift: Vector3 = Vector3(0, 0.25, -0.5)        # 烟飘走的方向（枪口局部空间，单位米）

@export_group("弹痕 Bullet Holes")
@export var bullet_hole_size: float = 0.03        # 方片边长（米）
@export var bullet_hole_lifetime: float = 5.0     # 每个弹痕存在多少秒（到点自动清除）

@export_group("过渡")
@export var aim_switch_time: float = 0.15   # 两种姿态之间的切换时长（秒）

var is_aiming: bool = false                 # false = 腰射，true = 开镜
var _auto_firing: bool = false              # 连发时：开火键是否仍按着
var _auto_timer: float = 0.0                # 连发计时器

@onready var camera: Camera3D = $"玩家_Player/俯仰_PitchPivot/Camera3D"
@onready var pistol: Node3D = $"玩家_Player/俯仰_PitchPivot/Camera3D/手枪_Pistol"
@onready var weapon_recoil: Node3D = $"玩家_Player/俯仰_PitchPivot/Camera3D/手枪_Pistol/武器后坐_RecoilPivot"
@onready var animation_player: AnimationPlayer = $"玩家_Player/俯仰_PitchPivot/Camera3D/手枪_Pistol/武器后坐_RecoilPivot/动画播放器_AnimationPlayer"
@onready var fire_sound: AudioStreamPlayer = $"玩家_Player/俯仰_PitchPivot/Camera3D/手枪_Pistol/武器后坐_RecoilPivot/开火音效_FireSound"
@onready var raycast: RayCast3D = $"玩家_Player/俯仰_PitchPivot/Camera3D/射线_RayCast"
@onready var muzzle_flash: Node3D = $"玩家_Player/俯仰_PitchPivot/Camera3D/手枪_Pistol/武器后坐_RecoilPivot/枪口火焰_MuzzleFlash"
@onready var flash_mesh: MeshInstance3D = $"玩家_Player/俯仰_PitchPivot/Camera3D/手枪_Pistol/武器后坐_RecoilPivot/枪口火焰_MuzzleFlash/闪光_FlashMesh"
@onready var flash_light: OmniLight3D = $"玩家_Player/俯仰_PitchPivot/Camera3D/手枪_Pistol/武器后坐_RecoilPivot/枪口火焰_MuzzleFlash/闪光灯_FlashLight"

var _aim_tween: Tween                       # 记录正在跑的过渡，切换时冲掉旧的

var _camera_base_rot: Vector3 = Vector3.ZERO    # 相机基础朝向（相机现在只承载"后坐力"偏移，所以恒为 0；留着以防以后改层级）
var _recoil_target: Vector2 = Vector2.ZERO      # 后坐目标：x = 上抬，y = 左右
var _recoil_current: Vector2 = Vector2.ZERO     # 当前实际后坐
var _weapon_kick: Vector3 = Vector3.ZERO        # 武器自身后坐（度）：x = 枪口上抬，y = 左右摆
var _weapon_kick_target: Vector3 = Vector3.ZERO # 武器后坐的目标值（同上）
var _trauma: float = 0.0                        # 镜头抖动的"创伤值"（0~1）：开火累加，随时间自动衰减
var _shake_time: float = 0.0                    # 噪声采样的时间轴
var _shake_offset: Vector3 = Vector3.ZERO       # 当前抖动偏移（度）：x=俯仰 y=偏航 z=翻滚
var _shake_noise: FastNoiseLite                 # 用噪声而不是每帧纯随机，避免"频闪"感
var _flash_timer: float = 0.0                   # 枪口火焰还要亮多久
var _smoke_mesh: QuadMesh                       # 烟团的共享网格（大小靠节点 scale 控制）
var _smoke_tex: GradientTexture2D               # 烟团的径向渐变贴图（程序生成）
var _bullet_hole_mesh: QuadMesh                 # 共享网格（省内存）
var _bullet_hole_mat: StandardMaterial3D        # 共享材质

func _ready() -> void:
	# 初始化为腰射姿态（默认模式）
	_apply_pose(hip_position, hip_rotation_degrees)
	# 腰射视野
	camera.fov = hip_fov
	# 记住相机基础朝向：后坐力是"叠加"在它之上的偏移
	_camera_base_rot = camera.rotation_degrees
	# 弹痕用的共享网格与材质（黑色无光照，任何角度都看得清）
	_bullet_hole_mesh = QuadMesh.new()
	_bullet_hole_mesh.size = Vector2(bullet_hole_size, bullet_hole_size)
	_bullet_hole_mat = StandardMaterial3D.new()
	_bullet_hole_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bullet_hole_mat.albedo_color = Color(0.02, 0.02, 0.02)
	# 镜头抖动的噪声源：Simplex 噪声比"每帧纯随机"平滑，不会出现频闪感
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_shake_noise.frequency = 1.0

	# ---- 枪口特效 ----
	# 火焰材质：无光照 + 加色混合 + 永远正对相机 + 程序生成的径向渐变（完全不用外部贴图）
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # 不受光照影响
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD           # 加色混合 → 会"发光"
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED    # 永远正对相机
	flash_mat.billboard_keep_scale = true                          # 保留节点缩放（我们要随机大小）
	flash_mat.disable_receive_shadows = true
	flash_mat.albedo_color = muzzle_flash_color
	flash_mat.albedo_texture = _make_radial_texture(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	flash_mesh.material_override = flash_mat
	flash_mesh.visible = false
	flash_light.visible = false

	# 烟团：同样用径向渐变贴图，但走普通透明混合（烟不发光）
	_smoke_tex = _make_radial_texture(Color(0.8, 0.8, 0.82, 1.0), Color(0.6, 0.6, 0.63, 0.0))
	_smoke_mesh = QuadMesh.new()
	_smoke_mesh.size = Vector2(1, 1)


# 程序生成一张"中心实、边缘透明"的径向渐变贴图
# 火焰和烟都用它 —— 这样整个 demo 不需要任何外部图片资源
func _make_radial_texture(center_color: Color, edge_color: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, center_color)
	grad.set_color(1, edge_color)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL      # 径向（从中心往外）
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


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
	# 先更新后坐力与镜头抖动，再决定要不要开火（保证"这一枪用的是当前准心"）
	_update_recoil(delta)
	_update_shake(delta)
	_apply_camera_rotation()   # 相机的最终朝向在这里一次性写入
	# 枪口火焰到点就关掉（真实枪口焰只有几毫秒，屏幕上亮 2~3 帧就够）
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			flash_mesh.visible = false
			flash_light.visible = false
	# 连发：按着开火键时，按固定间隔持续开火
	if fire_mode == FireMode.AUTO and _auto_firing:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = auto_fire_interval
			_shoot()


# 打一发：先打准心方向那一发（弹痕），再加后坐力，最后播套筒动画 + 音效
func _shoot() -> void:
	_spawn_bullet_hole()
	_add_recoil_kick()
	_add_shake_trauma()
	_show_muzzle_flash()
	_spawn_smoke()
	animation_player.play("fire")
	fire_sound.play()


# 后坐力回复：业内标准的"两段 lerp"
#   当前后坐 追 目标后坐  → 画面被"顶"上去
#   目标后坐 往 0 收      → 停火后**完全回正**到初始位置
func _update_recoil(delta: float) -> void:
	_recoil_current = _recoil_current.lerp(_recoil_target, clampf(recoil_recovery_speed * delta, 0.0, 1.0))
	_recoil_target = _recoil_target.lerp(Vector2.ZERO, clampf(recoil_return_speed * delta, 0.0, 1.0))
	# 上抬 = 相机绕 X 轴**正向**转（Godot 里 +X 是抬头，-X 是低头）；左右 = 绕 Y 轴
	# 这里只算出偏移值，真正写进相机的是 _apply_camera_rotation()（后坐 + 抖动一起叠）

	# ---- 第二层：武器自身后坐（枪模型自己转，和相机互不干扰）----
	# 和相机同一套"两段 lerp"，只是用武器自己的一套速度参数（更猛、回得更快）
	_weapon_kick = _weapon_kick.lerp(_weapon_kick_target, clampf(weapon_kick_recovery_speed * delta, 0.0, 1.0))
	_weapon_kick_target = _weapon_kick_target.lerp(Vector3.ZERO, clampf(weapon_kick_return_speed * delta, 0.0, 1.0))
	# 枪的朝向也是 -Z，和相机符号规则相同：+X 就是枪口上抬；+Y 是枪口往右摆
	weapon_recoil.rotation_degrees = _weapon_kick


# 把"基础朝向 + 后坐力 + 镜头抖动"一次性写进相机
# 注意：射线_RayCast 是相机的子节点，所以这里转多少，弹道就跟着偏多少
func _apply_camera_rotation() -> void:
	camera.rotation_degrees = (
		_camera_base_rot
		+ Vector3(_recoil_current.x, _recoil_current.y, 0.0)
		+ _shake_offset
	)


# 每发往 trauma 里加一点"创伤"
func _add_shake_trauma() -> void:
	if not shake_enabled:
		return
	_trauma = minf(_trauma + shake_trauma_per_shot, 1.0)


# 镜头抖动：业界标准的 trauma 模型（GDC《Juicing Your Cameras With Math》那一套）
#   每发累加 trauma → 随时间线性衰减 → 实际幅度取 trauma 的**平方**
#   取平方的作用：小抖动几乎看不见、大抖动被放大 → 衰减曲线自然，而且最终一定会回到 0
func _update_shake(delta: float) -> void:
	if not shake_enabled:
		# 关掉时确保归零，不影响别的层
		_trauma = 0.0
		_shake_offset = Vector3.ZERO
		return

	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var amount: float = _trauma * _trauma        # 平方衰减
	var amp: float = shake_max_deg * amount
	if is_aiming:
		amp *= shake_ads_mult                    # 开镜 = 端得更稳，抖动减弱
	_shake_time += delta * shake_frequency       # 噪声的时间轴

	# 三条轴用"同一张噪声图的不同坐标"采样：互相不相关，又不会像纯随机那样频闪
	# 翻滚（z 轴）只取一半幅度 —— 旋转抖动最"提味"，但给多了容易晕
	_shake_offset = Vector3(
		_shake_noise.get_noise_2d(0.0, _shake_time) * amp,
		_shake_noise.get_noise_2d(100.0, _shake_time) * amp,
		_shake_noise.get_noise_2d(200.0, _shake_time) * amp * 0.5
	)


# 枪口火焰：亮极短时间。连发时每发都随机一下大小/长宽，避免看着像"同一张贴图在闪"
func _show_muzzle_flash() -> void:
	if not muzzle_flash_enabled:
		return
	flash_mesh.scale = Vector3(
		muzzle_flash_scale * randf_range(0.24, 0.78),   # 半径范围：原 0.8~1.3 的 30% ~ 60%
		muzzle_flash_scale * randf_range(0.24, 0.78),
		1.0
	)
	flash_mesh.visible = true
	# 闪光灯：这才是"有火花"最大的观感来源 —— 开火瞬间把周围照亮一下
	flash_light.light_energy = muzzle_light_energy * randf_range(0.7, 1.3)
	flash_light.visible = true
	_flash_timer = muzzle_flash_time


# 枪口烟：手搓一个"会变大、会飘走、会淡出"的小烟团
# （正经做法是 GPUParticles3D；这里为了 demo 简单直接手搓，思路和弹痕那套一样）
func _spawn_smoke() -> void:
	if not smoke_enabled:
		return

	# 每团烟单独一份材质 —— 材质若是共享的，所有烟会一起变透明
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED   # 永远正对相机
	mat.billboard_keep_scale = true
	mat.disable_receive_shadows = true
	mat.albedo_texture = _smoke_tex
	mat.albedo_color = Color(0.78, 0.78, 0.8, 0.45)

	var puff := MeshInstance3D.new()
	puff.mesh = _smoke_mesh
	puff.material_override = mat
	puff.scale = Vector3.ONE * 0.04
	puff.position = Vector3(0, 0, -0.03)   # 从枪口稍前一点冒出来
	muzzle_flash.add_child(puff)           # 挂在枪口下 → 跟着枪一起动

	# 同时做三件事：变大、飘走、淡出，做完把自己删掉
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector3.ONE * smoke_size, smoke_lifetime)
	tween.tween_property(puff, "position", puff.position + smoke_drift, smoke_lifetime)
	tween.tween_property(mat, "albedo_color:a", 0.0, smoke_lifetime)
	tween.chain().tween_callback(puff.queue_free)


# 每发加一次后坐冲量
func _add_recoil_kick() -> void:
	if not recoil_enabled:
		return
	# 垂直：固定上抬（连发时会累加 → 弹着点逐发往上爬）
	_recoil_target.x += vertical_recoil_deg
	# 水平：每次开火在 ±范围 内随机左右摆（这个值要留着，武器后坐得跟着同一个方向）
	var side_impulse: float = randf_range(-horizontal_recoil_deg, horizontal_recoil_deg)
	_recoil_target.y += side_impulse
	# 兜底上限，防止参数调歪后画面乱飞
	_recoil_target.x = minf(_recoil_target.x, recoil_max_deg)

	# ---- 武器自身后坐：枪口上抬 + 朝"这一发弹道偏移的方向"摆动 ----
	_weapon_kick_target.x += weapon_kick_up_deg
	# 把 side_impulse 归一化到 [-1, 1]，再乘摆动幅度 → 枪口摆的方向和这一发弹道偏的方向一致
	_weapon_kick_target.y += side_impulse / maxf(horizontal_recoil_deg, 0.001) * weapon_kick_side_deg
	_weapon_kick_target.x = clampf(_weapon_kick_target.x, -weapon_kick_max_deg, weapon_kick_max_deg)
	_weapon_kick_target.y = clampf(_weapon_kick_target.y, -weapon_kick_max_deg, weapon_kick_max_deg)


# 在射线命中点贴一个弹痕小方片
func _spawn_bullet_hole() -> void:
	raycast.force_raycast_update()   # 立刻用当前准心刷新射线
	if not raycast.is_colliding():
		return
	var point: Vector3 = raycast.get_collision_point()
	var normal: Vector3 = raycast.get_collision_normal()
	var hit_body := raycast.get_collider() as Node3D
	if hit_body == null:
		return
	# QuadMesh 正面朝 +Z；要让正面法线贴到墙面，就用 looking_at(-法线)
	var up: Vector3 = Vector3.FORWARD if absf(normal.y) > 0.9 else Vector3.UP
	var hole := MeshInstance3D.new()
	hole.mesh = _bullet_hole_mesh
	hole.material_override = _bullet_hole_mat
	hit_body.add_child(hole)   # 挂在被打中的物体上（物体动，弹痕跟着动）
	hole.global_transform = Transform3D(Basis.looking_at(-normal, up), point + normal * 0.003)
	# 到点自动清除：等 bullet_hole_lifetime 秒后 queue_free
	var tween := hole.create_tween()
	tween.tween_interval(bullet_hole_lifetime)
	tween.tween_callback(hole.queue_free)

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
