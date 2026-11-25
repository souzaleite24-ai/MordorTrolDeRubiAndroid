extends Node3D

const MINION_COLORS := {
	"BRUTAMONTES": Color(0.30, 0.20, 0.16),
	"ASSASSINO": Color(0.12, 0.30, 0.16),
	"PIROMANTE": Color(0.72, 0.18, 0.06),
	"XAMA": Color(0.12, 0.30, 0.52)
}

var player: CharacterBody3D
var camera: Camera3D
var minions: Array[Node3D] = []
var enemies: Array[Node3D] = []
var selected_order := "SEGUIR"
var selected_class := "BRUTAMONTES"
var status_label: Label
var attack_cooldown := 0.0

func _ready() -> void:
	_setup_input()
	_setup_environment()
	_create_ground()
	_create_ruins()
	_create_player()
	_create_minions()
	_create_enemy(Vector3(0, 0, -11))
	_create_hud()
	_update_status()

func _setup_input() -> void:
	var bindings := {
		"ui_left": [KEY_A],
		"ui_right": [KEY_D],
		"ui_up": [KEY_W],
		"ui_down": [KEY_S]
	}
	for action in bindings:
		for keycode in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.22, 0.20)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.20, 0.12, 0.09)
	env.fog_density = 0.012
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func _create_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Terreno"
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.14, 0.12)
	mat.roughness = 1.0
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.5, 100)
	shape.shape = box
	shape.position.y = -0.25
	body.add_child(shape)
	add_child(body)

func _create_ruins() -> void:
	for i in range(18):
		var pillar := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = randf_range(0.35, 0.65)
		cylinder.bottom_radius = cylinder.top_radius * 1.2
		cylinder.height = randf_range(2.0, 5.0)
		pillar.mesh = cylinder
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.20, 0.18, 0.16) * randf_range(0.8, 1.2)
		stone.roughness = 0.95
		pillar.material_override = stone
		pillar.position = Vector3(randf_range(-22, 22), cylinder.height / 2.0, randf_range(-28, 12))
		add_child(pillar)
	for i in range(12):
		var fire := OmniLight3D.new()
		fire.position = Vector3(randf_range(-18, 18), 1.3, randf_range(-20, 8))
		fire.light_color = Color(1.0, 0.22, 0.045)
		fire.light_energy = 1.8
		fire.omni_range = 7.0
		add_child(fire)

func _make_actor(color: Color, height: float = 1.8) -> Node3D:
	var actor := Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = height
	body.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = 0.12
	body.material_override = material
	actor.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.27
	sphere.height = 0.54
	head.mesh = sphere
	head.position.y = height * 0.48
	head.material_override = material
	actor.add_child(head)
	return actor

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "SenhorSombrio"
	var visual := _make_actor(Color(0.12, 0.10, 0.09), 2.0)
	player.add_child(visual)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 2.0
	collision.shape = capsule
	collision.position.y = 1.0
	player.add_child(collision)
	player.position = Vector3(0, 0, 4)
	add_child(player)
	camera = Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, 5.5, 9)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	player.add_child(camera)
	camera.position = Vector3(0, 5.2, 9)
	camera.look_at(player.global_position + Vector3(0, 1, -3), Vector3.UP)

func _create_minions() -> void:
	var classes := ["BRUTAMONTES", "ASSASSINO", "PIROMANTE", "XAMA"]
	for i in range(4):
		var minion := _make_actor(MINION_COLORS[classes[i]], 1.25)
		minion.name = classes[i]
		minion.set_meta("class", classes[i])
		minion.position = Vector3((i - 1.5) * 1.7, 0, 6.5)
		add_child(minion)
		minions.append(minion)

func _create_enemy(at: Vector3) -> void:
	var enemy := _make_actor(Color(0.34, 0.035, 0.025), 2.1)
	enemy.name = "GuardiaoCorrompido"
	enemy.position = at
	add_child(enemy)
	enemies.append(enemy)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(310, 92)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "MORDOR 3D  |  CRÔNICAS DE MORDOR"
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	status_label = Label.new()
	vbox.add_child(status_label)
	var controls := HBoxContainer.new()
	controls.anchor_left = 0.0
	controls.anchor_top = 1.0
	controls.anchor_right = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_top = -76
	controls.offset_bottom = -12
	layer.add_child(controls)
	for action in ["ATACAR", "MAGIA", "ORDEN", "CLASSE"]:
		var button := Button.new()
		button.text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 58
		button.pressed.connect(_on_control.bind(action))
		controls.add_child(button)
	var hint := Label.new()
	hint.text = "WASD / setas: mover   •   toque: botões   •   toque em ORDEM para comandar a horda"
	hint.position = Vector2(18, 116)
	layer.add_child(hint)

func _on_control(action: String) -> void:
	match action:
		"ATACAR":
			_attack()
		"MAGIA":
			_cast_spell()
		"ORDEN":
			selected_order = "ATACAR" if selected_order == "SEGUIR" else "SEGUIR"
			_update_status()
		"CLASSE":
			var keys := MINION_COLORS.keys()
			selected_class = keys[(keys.find(selected_class) + 1) % keys.size()]
			_update_status()

func _attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.55
	for enemy in enemies:
		if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 4.0:
			enemy.queue_free()
			enemies.erase(enemy)
			_create_enemy(Vector3(randf_range(-7, 7), 0, -14))
			break

func _cast_spell() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 12.0:
			enemy.queue_free()
			enemies.erase(enemy)
			break
	var flash := OmniLight3D.new()
	flash.position = player.position + Vector3(0, 1.2, -2)
	flash.light_color = Color(0.55, 0.08, 0.95)
	flash.light_energy = 4.0
	flash.omni_range = 8.0
	add_child(flash)
	var timer := get_tree().create_timer(0.22)
	timer.timeout.connect(flash.queue_free)

func _update_status() -> void:
	if status_label:
		status_label.text = "Horda: %d lacaios  |  Ordem: %s  |  Classe: %s" % [minions.size(), selected_order, selected_class]

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input.x, 0, input.y)
	player.velocity.x = direction.x * 6.0
	player.velocity.z = direction.z * 6.0
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = 0.0
	player.move_and_slide()
	camera.global_position = camera.global_position.lerp(player.global_position + Vector3(0, 5.2, 9), 5.0 * delta)
	camera.look_at(player.global_position + Vector3(0, 1, -3), Vector3.UP)
	for i in range(minions.size()):
		var minion := minions[i]
		var target := player.global_position + Vector3((i - 1.5) * 1.5, 0, 2.2)
		if selected_order == "ATACAR" and not enemies.is_empty():
			target = enemies[0].global_position + Vector3((i - 1.5) * 0.8, 0, 1.5)
		minion.global_position = minion.global_position.lerp(target, 2.8 * delta)
