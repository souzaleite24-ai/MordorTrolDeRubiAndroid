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
var player_health := 100.0
var player_hit_cooldown := 0.0
var wave := 1
var anim_clock := 0.0

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
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = 0.12
	var dark_metal := StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.075, 0.065, 0.06)
	dark_metal.metallic = 0.72
	dark_metal.roughness = 0.38
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.48, 0.19, 0.055)
	trim.metallic = 0.62
	trim.roughness = 0.42

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = height
	body.mesh = capsule
	body.position.y = height * 0.5
	body.material_override = material
	actor.add_child(body)

	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.72, 0.62, 0.22)
	chest.mesh = chest_mesh
	chest.position = Vector3(0, height * 0.57, -0.31)
	chest.material_override = dark_metal
	actor.add_child(chest)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.27
	sphere.height = 0.54
	head.mesh = sphere
	head.position.y = height * 0.88
	head.material_override = material
	actor.add_child(head)

	# Ombreiras, braçadeiras e elmo dão uma silhueta distinta sem assets externos.
	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.23
		shoulder_mesh.height = 0.34
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(side * 0.43, height * 0.68, 0)
		shoulder.material_override = dark_metal
		actor.add_child(shoulder)

		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.105
		arm_mesh.height = height * 0.38
		arm.name = "Arm_L" if side < 0.0 else "Arm_R"
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.48, height * 0.43, -0.015)
		arm.rotation.z = side * -0.12
		arm.material_override = material
		actor.add_child(arm)

		var bracer := MeshInstance3D.new()
		var bracer_mesh := BoxMesh.new()
		bracer_mesh.size = Vector3(0.19, 0.25, 0.2)
		bracer.name = "Bracer_L" if side < 0.0 else "Bracer_R"
		bracer.mesh = bracer_mesh
		bracer.position = Vector3(side * 0.49, height * 0.31, -0.02)
		bracer.material_override = trim
		actor.add_child(bracer)

	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.31
	helmet_mesh.height = 0.24
	helmet.mesh = helmet_mesh
	helmet.position.y = height * 1.02
	helmet.material_override = dark_metal
	actor.add_child(helmet)

	var crest := MeshInstance3D.new()
	var crest_mesh := BoxMesh.new()
	crest_mesh.size = Vector3(0.075, 0.34, 0.09)
	crest.mesh = crest_mesh
	crest.position = Vector3(0, height * 1.13, 0.02)
	crest.material_override = trim
	actor.add_child(crest)

	var belt := MeshInstance3D.new()
	var belt_mesh := BoxMesh.new()
	belt_mesh.size = Vector3(0.68, 0.13, 0.27)
	belt.mesh = belt_mesh
	belt.position = Vector3(0, height * 0.34, 0)
	belt.material_override = dark_metal
	actor.add_child(belt)
	return actor

func _weapon_piece(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, size: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = size
	parent.add_child(part)
	return part

func _add_weapon(actor: Node3D, kind: String) -> void:
	var pivot := Node3D.new()
	pivot.name = "WeaponPivot"
	pivot.position = Vector3(0.56, 0.48, -0.18)
	actor.add_child(pivot)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.10, 0.09)
	metal.metallic = 0.86
	metal.roughness = 0.24
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.68, 0.72, 0.78)
	edge.metallic = 0.92
	edge.roughness = 0.18
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = MINION_COLORS.get(kind, Color(0.32, 0.12, 0.55))
	glow.emission_enabled = true
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 2.4
	if kind == "ASSASSINO":
		for side in [-1.0, 1.0]:
			var blade := BoxMesh.new()
			blade.size = Vector3(0.10, 0.12, 0.78)
			_weapon_piece(pivot, blade, edge, Vector3(side * 0.13, 0.02, -0.25), Vector3.ONE)
			var grip := CylinderMesh.new()
			grip.top_radius = 0.045
			grip.bottom_radius = 0.045
			grip.height = 0.28
			_weapon_piece(pivot, grip, metal, Vector3(side * 0.13, -0.02, 0.23), Vector3.ONE)
	elif kind == "BRUTAMONTES":
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.075
		shaft.bottom_radius = 0.09
		shaft.height = 1.05
		_weapon_piece(pivot, shaft, metal, Vector3(0, 0, -0.12), Vector3.ONE)
		var head := BoxMesh.new()
		head.size = Vector3(0.62, 0.48, 0.38)
		_weapon_piece(pivot, head, edge, Vector3(0, 0.52, -0.12), Vector3.ONE)
		var spike := SphereMesh.new()
		spike.radius = 0.16
		spike.height = 0.32
		_weapon_piece(pivot, spike, glow, Vector3(0, 0.52, -0.37), Vector3.ONE)
	else:
		var staff := CylinderMesh.new()
		staff.top_radius = 0.045
		staff.bottom_radius = 0.065
		staff.height = 1.35
		_weapon_piece(pivot, staff, metal, Vector3(0, 0.12, -0.08), Vector3.ONE)
		var orb := SphereMesh.new()
		orb.radius = 0.22
		orb.height = 0.44
		_weapon_piece(pivot, orb, glow, Vector3(0, 0.82, -0.08), Vector3.ONE)
		for side in [-1.0, 1.0]:
			var rune := SphereMesh.new()
			rune.radius = 0.075
			rune.height = 0.15
			_weapon_piece(pivot, rune, edge if kind == "XAMA" else glow, Vector3(side * 0.19, 0.82, -0.08), Vector3.ONE)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "SenhorSombrio"
	var visual := _make_actor(Color(0.12, 0.10, 0.09), 2.0)
	_add_weapon(visual, "SOMBRA")
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
		_add_weapon(minion, classes[i])
		minion.name = classes[i]
		minion.set_meta("class", classes[i])
		minion.position = Vector3((i - 1.5) * 1.7, 0, 6.5)
		add_child(minion)
		minions.append(minion)

func _create_enemy(at: Vector3) -> void:
	var enemy := _make_actor(Color(0.34, 0.035, 0.025), 2.1)
	enemy.name = "GuardiaoCorrompido"
	enemy.position = at
	enemy.set_meta("health", 90.0)
	enemy.set_meta("attack_timer", 0.0)
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
	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.position = Vector2(20, -205)
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.custom_minimum_size = Vector2(174, 174)
	layer.add_child(dpad)
	for direction in ["", "ui_up", "", "ui_left", "", "ui_right", "", "ui_down", ""]:
		var move_button := Button.new()
		move_button.text = "▲" if direction == "ui_up" else ("▼" if direction == "ui_down" else ("◀" if direction == "ui_left" else ("▶" if direction == "ui_right" else "")))
		move_button.custom_minimum_size = Vector2(54, 54)
		move_button.disabled = direction == ""
		if direction != "":
			move_button.button_down.connect(Input.action_press.bind(direction))
			move_button.button_up.connect(Input.action_release.bind(direction))
			move_button.mouse_exited.connect(_release_direction.bind(direction))
		dpad.add_child(move_button)
	var hint := Label.new()
	hint.text = "WASD / setas: mover   •   toque: botões   •   toque em ORDEM para comandar a horda"
	hint.position = Vector2(18, 116)
	layer.add_child(hint)

func _release_direction(action: String) -> void:
	Input.action_release(action)

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

func _damage_enemy(enemy: Node3D, amount: float) -> void:
	if not is_instance_valid(enemy):
		return
	var hp := float(enemy.get_meta("health", 90.0)) - amount
	enemy.set_meta("health", hp)
	if hp <= 0.0:
		var at := enemy.global_position
		enemies.erase(enemy)
		enemy.queue_free()
		if enemies.is_empty():
			wave += 1
			for i in range(mini(wave, 4)):
				_create_enemy(at + Vector3(randf_range(-5, 5), 0, randf_range(-7, -3)))
		_update_status()

func _spawn_combat_flash(at: Vector3, tint: Color, radius: float) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	flash.mesh = mesh
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = tint
	glow.emission_enabled = true
	glow.emission = tint
	glow.emission_energy_multiplier = 2.8
	flash.material_override = glow
	flash.position = at
	add_child(flash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * radius, 0.24)
	tween.chain().tween_callback(flash.queue_free)

func _animate_actor(actor: Node3D, delta: float, speed: float, phase: float) -> void:
	if not is_instance_valid(actor):
		return
	var moving := speed > 0.15
	var stride := sin(anim_clock * (10.0 if moving else 2.0) + phase)
	actor.position.y = 0.045 * absf(stride) if moving else 0.025 * sin(anim_clock * 2.0 + phase)
	var left_arm := actor.get_node_or_null("Arm_L") as Node3D
	var right_arm := actor.get_node_or_null("Arm_R") as Node3D
	var weapon := actor.get_node_or_null("WeaponPivot") as Node3D
	if weapon and not actor.has_meta("weapon_striking"):
		weapon.rotation.z = sin(anim_clock * 2.0 + phase) * 0.035
	if left_arm:
		left_arm.rotation.x = stride * 0.42
	if right_arm:
		right_arm.rotation.x = -stride * 0.42

func _attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.55
	_weapon_strike(player.get_child(0) as Node3D)
	_spawn_combat_flash(player.global_position + player.global_basis * Vector3(0, 1.1, -1.35), Color(1.0, 0.58, 0.16), 2.8)
	for enemy in enemies:
		if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 4.0:
			_spawn_combat_flash(enemy.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.25, 0.08), 1.7)
			_damage_enemy(enemy, 42.0)
			break

func _weapon_strike(actor: Node3D) -> void:
	var pivot := actor.get_node_or_null("WeaponPivot") as Node3D
	if not pivot:
		return
	var tween := create_tween()
	tween.tween_property(pivot, "rotation:x", -1.05, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "rotation:x", 0.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_special_ring(at: Vector3, tint: Color, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.9
	ring.mesh = torus
	ring.material_override = _glow_material(tint)
	ring.position = at
	ring.rotation.x = deg_to_rad(90)
	ring.scale = Vector3.ONE * 0.2
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * radius, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "rotation:z", TAU, 0.38)
	tween.chain().tween_callback(ring.queue_free)

func _glow_material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 3.5
	return mat

func _cast_spell() -> void:
	_spawn_combat_flash(player.global_position + Vector3(0, 1.0, -1.0), Color(0.55, 0.08, 0.95), 4.2)
	_spawn_special_ring(player.global_position + Vector3(0, 0.12, -1.0), Color(0.48, 0.08, 1.0), 2.5)
	_spawn_special_ring(player.global_position + Vector3(0, 1.4, -1.0), Color(0.12, 0.72, 1.0), 1.4)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 12.0:
			_spawn_combat_flash(enemy.global_position + Vector3(0, 1.0, 0), Color(0.62, 0.12, 1.0), 2.2)
			_damage_enemy(enemy, 65.0)
	var flash := OmniLight3D.new()
	flash.position = player.position + Vector3(0, 1.2, -2)
	flash.light_color = Color(0.55, 0.08, 0.95)
	flash.light_energy = 4.0
	flash.omni_range = 8.0
	add_child(flash)
	var timer := get_tree().create_timer(0.22)
	timer.timeout.connect(flash.queue_free)

func _update_minion_combat(delta: float) -> void:
	for minion in minions:
		var target_enemy: Node3D = null
		var best_distance := 999.0
		for enemy in enemies:
			if is_instance_valid(enemy):
				var d := minion.global_position.distance_to(enemy.global_position)
				if d < best_distance:
					best_distance = d
					target_enemy = enemy
		var timer := maxf(0.0, float(minion.get_meta("attack_timer", 0.0)) - delta)
		if selected_order == "ATACAR" and target_enemy and best_distance < 2.4 and timer <= 0.0:
			var kind := String(minion.get_meta("class", "BRUTAMONTES"))
			var damage := 18.0
			match kind:
				"BRUTAMONTES": damage = 28.0
				"ASSASSINO": damage = 20.0
				"PIROMANTE": damage = 24.0
				"XAMA": damage = 10.0
			_weapon_strike(minion)
			_spawn_combat_flash(target_enemy.global_position + Vector3(0, 1.0, 0), MINION_COLORS[kind], 1.35)
			_damage_enemy(target_enemy, damage)
			timer = 0.9 if kind != "ASSASSINO" else 0.55
		minion.set_meta("attack_timer", timer)

func _update_enemy_ai(delta: float) -> void:
	player_hit_cooldown = maxf(0.0, player_hit_cooldown - delta)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var to_player := player.global_position - enemy.global_position
		to_player.y = 0.0
		var distance := to_player.length()
		if distance > 1.7:
			enemy.global_position += to_player.normalized() * 1.6 * delta
			enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
		elif player_hit_cooldown <= 0.0:
			player_health = maxf(0.0, player_health - 8.0)
			_spawn_combat_flash(player.global_position + Vector3(0, 1.0, 0), Color(0.9, 0.03, 0.02), 1.4)
			player_hit_cooldown = 1.0
			_update_status()

func _update_status() -> void:
	if status_label:
		status_label.text = "Vida: %d  |  Horda: %d  |  Ordem: %s  |  Classe: %s  |  Onda: %d" % [int(player_health), minions.size(), selected_order, selected_class, wave]

func _physics_process(delta: float) -> void:
	anim_clock += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input.x, 0, input.y)
	if direction.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), 10.0 * delta)
	player.velocity.x = direction.x * 6.0
	player.velocity.z = direction.z * 6.0
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = 0.0
	player.move_and_slide()
	_animate_actor(player.get_child(0) as Node3D, delta, direction.length(), 0.0)
	camera.global_position = camera.global_position.lerp(player.global_position + Vector3(0, 5.2, 9), 5.0 * delta)
	camera.look_at(player.global_position + Vector3(0, 1, -3), Vector3.UP)
	_update_enemy_ai(delta)
	_update_minion_combat(delta)
	for i in range(minions.size()):
		var minion := minions[i]
		var target := player.global_position + Vector3((i - 1.5) * 1.5, 0, 2.2)
		if selected_order == "ATACAR" and not enemies.is_empty():
			target = enemies[0].global_position + Vector3((i - 1.5) * 0.8, 0, 1.5)
		var old_position := minion.global_position
		minion.global_position = minion.global_position.lerp(target, 2.8 * delta)
		var minion_speed := old_position.distance_to(minion.global_position) / maxf(delta, 0.001)
		_animate_actor(minion, delta, minion_speed, float(i) * 1.3)
	for enemy in enemies:
		if is_instance_valid(enemy):
			_animate_actor(enemy, delta, 1.0, 2.0)
