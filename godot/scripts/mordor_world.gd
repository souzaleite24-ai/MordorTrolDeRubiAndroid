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
var special_cooldown := 0.0
var dodge_cooldown := 0.0
var dodge_time := 0.0
var dodge_direction := Vector3.ZERO
var guarding := false
var combo_step := 0
var combo_window := 0.0
var player_health := 100.0
var player_hit_cooldown := 0.0
var wave := 1
var anim_clock := 0.0
var boss_health_bar: ProgressBar
var boss_name_label: Label
var boss_intro_label: Label
var boss_intro_timer := 0.0
var boss_intro_target: Node3D
var relic_count := 0
var relic_damage_bonus := 0.0
var inventory_panel: PanelContainer
var inventory_label: Label
var inventory_buttons: Dictionary = {}
var equipment_tiers: Dictionary = {"BRUTAMONTES": 0, "ASSASSINO": 0, "PIROMANTE": 0, "XAMA": 0}
var player_level := 1
var player_xp := 0
var unspent_attribute_points := 0
var strength_attribute := 0
var vitality_attribute := 0
var arcane_attribute := 0
var max_player_health := 100.0
var quest_label: Label
var quest_index := 0
var quest_progress := 0
var quests_completed := 0
var npc_dialog_panel: PanelContainer
var npc_dialog_label: Label
var npc_nearby := false
var npc_node: Node3D
var shop_panel: PanelContainer
var shop_label: Label
var shop_buttons: Dictionary = {}
var pause_panel: PanelContainer
var pause_button: Button
var ash_shards := 0
var shop_damage_bonus := 0.0
var shop_health_bonus := 0.0

func _ready() -> void:
	_load_progress()
	_setup_input()
	_setup_environment()
	_create_ground()
	_create_ruins()
	_create_npc()
	_create_player()
	_create_minions()
	_create_enemy(Vector3(0, 0, -11))
	_create_hud()
	_update_status()
	_update_quest_hud()

func _xp_to_next_level() -> int:
	return 100 + (player_level - 1) * 60

func _load_progress() -> void:
	var save := ConfigFile.new()
	if save.load("user://mordor_progress.cfg") != OK:
		return
	player_level = maxi(1, int(save.get_value("hero", "level", 1)))
	player_xp = maxi(0, int(save.get_value("hero", "xp", 0)))
	unspent_attribute_points = maxi(0, int(save.get_value("hero", "points", 0)))
	strength_attribute = maxi(0, int(save.get_value("hero", "strength", 0)))
	vitality_attribute = maxi(0, int(save.get_value("hero", "vitality", 0)))
	arcane_attribute = maxi(0, int(save.get_value("hero", "arcane", 0)))
	ash_shards = maxi(0, int(save.get_value("shop", "ash_shards", 0)))
	shop_damage_bonus = maxf(0.0, float(save.get_value("shop", "damage_bonus", 0.0)))
	shop_health_bonus = maxf(0.0, float(save.get_value("shop", "health_bonus", 0.0)))
	quest_index = clampi(int(save.get_value("quests", "index", 0)), 0, 1)
	quest_progress = maxi(0, int(save.get_value("quests", "progress", 0)))
	quests_completed = maxi(0, int(save.get_value("quests", "completed", 0)))
	max_player_health = 100.0 + float(vitality_attribute) * 10.0 + shop_health_bonus
	player_health = max_player_health

func _save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("hero", "level", player_level)
	save.set_value("hero", "xp", player_xp)
	save.set_value("hero", "points", unspent_attribute_points)
	save.set_value("hero", "strength", strength_attribute)
	save.set_value("hero", "vitality", vitality_attribute)
	save.set_value("hero", "arcane", arcane_attribute)
	save.set_value("shop", "ash_shards", ash_shards)
	save.set_value("shop", "damage_bonus", shop_damage_bonus)
	save.set_value("shop", "health_bonus", shop_health_bonus)
	save.set_value("quests", "index", quest_index)
	save.set_value("quests", "progress", quest_progress)
	save.set_value("quests", "completed", quests_completed)
	save.save("user://mordor_progress.cfg")

func _gain_experience(amount: int) -> void:
	player_xp += amount
	var gained_levels := 0
	while player_xp >= _xp_to_next_level():
		player_xp -= _xp_to_next_level()
		player_level += 1
		unspent_attribute_points += 1
		gained_levels += 1
	if gained_levels > 0:
		boss_intro_label.text = "NÍVEL %d ALCANÇADO!\n+%d PONTO(S) DE ATRIBUTO" % [player_level, gained_levels]
		boss_intro_label.visible = true
		boss_intro_label.modulate.a = 1.0
		var level_tween := create_tween()
		level_tween.tween_interval(2.0)
		level_tween.tween_property(boss_intro_label, "modulate:a", 0.0, 0.5)
		level_tween.tween_callback(func(): boss_intro_label.visible = false)
	_save_progress()
	_update_status()
	_update_inventory()

func _quest_description() -> String:
	if quest_index == 0:
		return "CONTRATO: Elimine 5 guardiões corrompidos (%d/5)" % quest_progress
	return "CONTRATO: Derrote Nekravor (%d/1)" % quest_progress

func _advance_quest(defeated_boss: bool) -> void:
	if quest_index == 0:
		if defeated_boss:
			return
		quest_progress += 1
		if quest_progress >= 5:
			_complete_quest(100)
	else:
		if defeated_boss:
			quest_progress = 1
			_complete_quest(250)
	_update_quest_hud()
	_save_progress()

func _complete_quest(reward_xp: int) -> void:
	quests_completed += 1
	quest_index = 1 - quest_index
	quest_progress = 0
	boss_intro_label.text = "CONTRATO CONCLUÍDO!\n+%d XP" % reward_xp
	boss_intro_label.visible = true
	boss_intro_label.modulate.a = 1.0
	var quest_tween := create_tween()
	quest_tween.tween_interval(2.0)
	quest_tween.tween_property(boss_intro_label, "modulate:a", 0.0, 0.5)
	quest_tween.tween_callback(func(): boss_intro_label.visible = false)
	_gain_experience(reward_xp)

func _update_quest_hud() -> void:
	if quest_label:
		quest_label.text = _quest_description() + "  |  Concluídos: %d" % quests_completed

func _spend_attribute(attribute: String) -> void:
	if unspent_attribute_points <= 0:
		return
	match attribute:
		"FORÇA":
			strength_attribute += 1
		"VITALIDADE":
			vitality_attribute += 1
			max_player_health += 10.0
			player_health = minf(max_player_health, player_health + 10.0)
		"ARCANO":
			arcane_attribute += 1
	unspent_attribute_points -= 1
	_save_progress()
	_update_status()
	_update_inventory()

func _setup_input() -> void:
	var bindings := {
		"ui_left": [KEY_A],
		"ui_right": [KEY_D],
		"ui_up": [KEY_W],
		"ui_down": [KEY_S],
		"interact": [KEY_E]
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

	# Rosto legível à distância: órbitas, olhos emissivos, nariz e máscara mandibular.
	var face_dark := StandardMaterial3D.new()
	face_dark.albedo_color = Color(0.018, 0.012, 0.016)
	face_dark.roughness = 0.48
	var eye_glow := _glow_material(Color(0.95, 0.035, 0.018))
	var face_gold := StandardMaterial3D.new()
	face_gold.albedo_color = Color(0.42, 0.22, 0.075)
	face_gold.metallic = 0.78
	face_gold.roughness = 0.3
	for side in [-1.0, 1.0]:
		var socket := MeshInstance3D.new()
		var socket_mesh := SphereMesh.new()
		socket_mesh.radius = 0.083
		socket_mesh.height = 0.12
		socket.mesh = socket_mesh
		socket.position = Vector3(side * 0.115, height * 0.895, -0.226)
		socket.material_override = face_dark
		actor.add_child(socket)
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.044
		eye_mesh.height = 0.07
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.115, height * 0.895, -0.286)
		eye.material_override = eye_glow
		actor.add_child(eye)
		var cheek := MeshInstance3D.new()
		var cheek_mesh := BoxMesh.new()
		cheek_mesh.size = Vector3(0.16, 0.13, 0.075)
		cheek.mesh = cheek_mesh
		cheek.position = Vector3(side * 0.17, height * 0.79, -0.205)
		cheek.material_override = dark_metal
		actor.add_child(cheek)

	var nose := MeshInstance3D.new()
	var nose_mesh := PrismMesh.new()
	nose_mesh.size = Vector3(0.12, 0.19, 0.12)
	nose.mesh = nose_mesh
	nose.position = Vector3(0, height * 0.835, -0.265)
	nose.material_override = face_gold
	actor.add_child(nose)
	var jaw := MeshInstance3D.new()
	var jaw_mesh := BoxMesh.new()
	jaw_mesh.size = Vector3(0.29, 0.095, 0.12)
	jaw.mesh = jaw_mesh
	jaw.position = Vector3(0, height * 0.775, -0.22)
	jaw.material_override = dark_metal
	actor.add_child(jaw)

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

	# Pernas articuladas em pivôs próprios para uma passada visível.
	for side in [-1.0, 1.0]:
		var leg_pivot := Node3D.new()
		leg_pivot.name = "Leg_L" if side < 0.0 else "Leg_R"
		leg_pivot.position = Vector3(side * 0.19, height * 0.27, 0)
		actor.add_child(leg_pivot)
		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.14
		leg_mesh.height = height * 0.34
		leg.mesh = leg_mesh
		leg.position.y = -height * 0.12
		leg.material_override = dark_metal
		leg_pivot.add_child(leg)
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

func _create_npc() -> void:
	npc_node = _make_actor(Color(0.12, 0.32, 0.30), 1.9)
	npc_node.name = "OraculoDasCinzas"
	npc_node.position = Vector3(-4.0, 0.0, -3.0)
	# Silhueta exclusiva do Oráculo: manto longo, capuz e olhos verde-cinza.
	var robe_material := StandardMaterial3D.new()
	robe_material.albedo_color = Color(0.035, 0.12, 0.115)
	robe_material.roughness = 0.92
	var robe := MeshInstance3D.new()
	var robe_mesh := CylinderMesh.new()
	robe_mesh.top_radius = 0.22
	robe_mesh.bottom_radius = 0.53
	robe_mesh.height = 1.15
	robe.mesh = robe_mesh
	robe.position.y = 0.62
	robe.material_override = robe_material
	npc_node.add_child(robe)
	var hood := MeshInstance3D.new()
	var hood_mesh := SphereMesh.new()
	hood_mesh.radius = 0.39
	hood_mesh.height = 0.72
	hood.mesh = hood_mesh
	hood.scale = Vector3(1.12, 1.0, 0.9)
	hood.position = Vector3(0, 1.76, 0.055)
	hood.material_override = robe_material
	npc_node.add_child(hood)
	var oracle_eyes := _glow_material(Color(0.12, 0.95, 0.68))
	for eye_name in ["MeshInstance3D"]:
		pass
	for child in npc_node.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			if child.position.y > 1.6 and child.position.z < -0.2:
				child.material_override = oracle_eyes
	var aura := OmniLight3D.new()
	aura.position = Vector3(0, 2.0, 0)
	aura.light_color = Color(0.20, 0.85, 0.72)
	aura.light_energy = 1.4
	aura.omni_range = 4.5
	npc_node.add_child(aura)
	var rune_material := StandardMaterial3D.new()
	rune_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rune_material.albedo_color = Color(0.25, 1.0, 0.78)
	rune_material.emission_enabled = true
	rune_material.emission = Color(0.12, 0.9, 0.65)
	var rune := MeshInstance3D.new()
	var rune_mesh := SphereMesh.new()
	rune_mesh.radius = 0.16
	rune_mesh.height = 0.32
	rune.mesh = rune_mesh
	rune.material_override = rune_material
	rune.position = Vector3(0, 2.15, -0.35)
	npc_node.add_child(rune)
	add_child(npc_node)

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
		minion.set_meta("equipment_tier", 0)
		minion.set_meta("attack_timer", 0.0)
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



func _create_boss_arena(center: Vector3) -> void:
	var arena := Node3D.new()
	arena.name = "ArenaDeNekravor"
	arena.position = center
	var dark_stone := StandardMaterial3D.new()
	dark_stone.albedo_color = Color(0.055, 0.045, 0.07)
	dark_stone.roughness = 0.95
	dark_stone.metallic = 0.18
	var rune_glow := _glow_material(Color(0.34, 0.035, 0.62))
	var seal := MeshInstance3D.new()
	var seal_mesh := TorusMesh.new()
	seal_mesh.inner_radius = 5.8
	seal_mesh.outer_radius = 6.05
	seal.mesh = seal_mesh
	seal.position.y = 0.08
	seal.rotation.x = deg_to_rad(90)
	seal.material_override = rune_glow
	arena.add_child(seal)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var obelisk := MeshInstance3D.new()
		var obelisk_mesh := BoxMesh.new()
		obelisk_mesh.size = Vector3(0.85, 5.2 if i % 2 == 0 else 3.8, 0.85)
		obelisk.mesh = obelisk_mesh
		obelisk.position = Vector3(cos(angle) * 9.0, obelisk_mesh.size.y * 0.5, sin(angle) * 9.0)
		obelisk.rotation.y = -angle
		obelisk.material_override = dark_stone
		arena.add_child(obelisk)
		var rune := MeshInstance3D.new()
		var rune_mesh := BoxMesh.new()
		rune_mesh.size = Vector3(0.12, 2.2, 0.12)
		rune.mesh = rune_mesh
		rune.position = obelisk.position + Vector3(0, 0, -0.46)
		rune.material_override = rune_glow
		arena.add_child(rune)
		var flame := OmniLight3D.new()
		flame.position = obelisk.position + Vector3(0, 2.2, -0.8)
		flame.light_color = Color(0.48, 0.08, 0.82)
		flame.light_energy = 1.7
		flame.omni_range = 8.0
		arena.add_child(flame)
	var entrance := MeshInstance3D.new()
	var gate_mesh := BoxMesh.new()
	gate_mesh.size = Vector3(5.5, 6.5, 0.7)
	entrance.mesh = gate_mesh
	entrance.position = Vector3(0, 3.25, -13.0)
	entrance.material_override = dark_stone
	arena.add_child(entrance)
	var gate_rune := MeshInstance3D.new()
	var gate_ring := TorusMesh.new()
	gate_ring.inner_radius = 1.45
	gate_ring.outer_radius = 1.7
	gate_rune.mesh = gate_ring
	gate_rune.position = Vector3(0, 3.3, -12.55)
	gate_rune.material_override = rune_glow
	arena.add_child(gate_rune)
	add_child(arena)

func _boss_entrance(boss: Node3D) -> void:
	boss_intro_timer = 3.8
	boss_intro_target = boss
	if boss_intro_label:
		boss_intro_label.text = "NEKRAVOR\nO TIRANO ABISSAL"
		boss_intro_label.visible = true
		boss_intro_label.modulate.a = 0.0
		var title_tween := create_tween()
		title_tween.tween_property(boss_intro_label, "modulate:a", 1.0, 0.55)
		title_tween.tween_interval(2.3)
		title_tween.tween_property(boss_intro_label, "modulate:a", 0.0, 0.65)
		title_tween.tween_callback(func(): boss_intro_label.visible = false)
	boss.scale = Vector3.ONE * 0.08
	var reveal := create_tween()
	reveal.tween_interval(0.45)
	reveal.tween_property(boss, "scale", Vector3.ONE * 1.55, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_special_ring(boss.global_position + Vector3(0, 0.14, 0), Color(0.62, 0.04, 0.9), 8.0)
	_spawn_combat_flash(boss.global_position + Vector3(0, 2.0, 0), Color(0.48, 0.06, 0.82), 4.5)

func _create_boss(at: Vector3) -> void:
	var boss := Node3D.new()
	boss.name = "Nekravor_TiranoAbissal"
	boss.position = at
	boss.scale = Vector3.ONE * 1.55
	boss.set_meta("is_boss", true)
	boss.set_meta("health", 720.0)
	boss.set_meta("attack_timer", 1.8)
	boss.set_meta("telegraph_timer", 0.0)
	boss.set_meta("phase_two", false)
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.72, 0.70, 0.58)
	var abyss := StandardMaterial3D.new()
	abyss.albedo_color = Color(0.035, 0.045, 0.075)
	abyss.metallic = 0.72
	abyss.roughness = 0.3
	var violet := _glow_material(Color(0.48, 0.06, 0.82))
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.72
	torso_mesh.height = 2.7
	torso.mesh = torso_mesh
	torso.position.y = 1.55
	torso.material_override = abyss
	boss.add_child(torso)
	var skull := MeshInstance3D.new()
	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = 0.72
	skull_mesh.height = 1.12
	skull.mesh = skull_mesh
	skull.position = Vector3(0, 3.05, -0.16)
	skull.scale = Vector3(1.0, 1.08, 0.82)
	skull.material_override = bone
	boss.add_child(skull)
	var jaw := MeshInstance3D.new()
	var jaw_mesh := BoxMesh.new()
	jaw_mesh.size = Vector3(0.88, 0.28, 0.68)
	jaw.mesh = jaw_mesh
	jaw.position = Vector3(0, 2.55, -0.32)
	jaw.material_override = bone
	boss.add_child(jaw)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.13
		eye_mesh.height = 0.22
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.29, 3.13, -0.77)
		eye.material_override = violet
		eye.set_meta("boss_eye", true)
		boss.add_child(eye)
		var horn := MeshInstance3D.new()
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.015
		horn_mesh.bottom_radius = 0.18
		horn_mesh.height = 0.92
		horn.mesh = horn_mesh
		horn.position = Vector3(side * 0.56, 3.68, -0.05)
		horn.rotation.z = side * -0.48
		horn.material_override = bone
		boss.add_child(horn)
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.52
		shoulder_mesh.height = 0.72
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(side * 0.9, 2.35, 0)
		shoulder.material_override = abyss
		boss.add_child(shoulder)
		for segment in range(3):
			var tentacle := MeshInstance3D.new()
			var tentacle_mesh := CylinderMesh.new()
			tentacle_mesh.top_radius = 0.055
			tentacle_mesh.bottom_radius = 0.16 - segment * 0.025
			tentacle_mesh.height = 0.72
			tentacle.mesh = tentacle_mesh
			tentacle.position = Vector3(side * (0.42 + segment * 0.17), 2.2 - segment * 0.48, -0.38)
			tentacle.rotation.z = side * (0.55 + segment * 0.22)
			tentacle.material_override = abyss
			tentacle.set_meta("boss_tentacle", true)
			boss.add_child(tentacle)
	var crown := MeshInstance3D.new()
	var crown_mesh := TorusMesh.new()
	crown_mesh.inner_radius = 0.55
	crown_mesh.outer_radius = 0.68
	crown.mesh = crown_mesh
	crown.position.y = 3.63
	crown.rotation.x = deg_to_rad(90)
	crown.material_override = violet
	crown.set_meta("boss_crown", true)
	boss.add_child(crown)
	_create_boss_arena(at)
	add_child(boss)
	enemies.append(boss)
	_boss_entrance(boss)
	_update_boss_hud()

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
	quest_label = Label.new()
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(quest_label)
	boss_name_label = Label.new()
	boss_name_label.text = "NEKRAVOR — O TIRANO ABISSAL"
	boss_name_label.visible = false
	vbox.add_child(boss_name_label)
	boss_health_bar = ProgressBar.new()
	boss_health_bar.custom_minimum_size = Vector2(280, 14)
	boss_health_bar.max_value = 720.0
	boss_health_bar.value = 720.0
	boss_health_bar.visible = false
	vbox.add_child(boss_health_bar)
	boss_intro_label = Label.new()
	boss_intro_label.text = "NEKRAVOR"
	boss_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_intro_label.anchor_left = 0.2
	boss_intro_label.anchor_right = 0.8
	boss_intro_label.anchor_top = 0.28
	boss_intro_label.anchor_bottom = 0.48
	boss_intro_label.add_theme_font_size_override("font_size", 34)
	boss_intro_label.add_theme_color_override("font_color", Color(0.88, 0.68, 1.0))
	boss_intro_label.visible = false
	layer.add_child(boss_intro_label)
	inventory_panel = PanelContainer.new()
	inventory_panel.position = Vector2(18, 158)
	inventory_panel.custom_minimum_size = Vector2(360, 290)
	inventory_panel.visible = false
	layer.add_child(inventory_panel)
	var inventory_box := VBoxContainer.new()
	inventory_panel.add_child(inventory_box)
	inventory_label = Label.new()
	inventory_label.text = _inventory_text()
	inventory_label.add_theme_font_size_override("font_size", 14)
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_box.add_child(inventory_label)
	for attribute in ["FORÇA", "VITALIDADE", "ARCANO"]:
		var attribute_button := Button.new()
		attribute_button.custom_minimum_size.y = 34
		attribute_button.pressed.connect(_spend_attribute.bind(attribute))
		inventory_box.add_child(attribute_button)
		inventory_buttons["ATRIBUTO_" + attribute] = attribute_button
	for kind in ["BRUTAMONTES", "ASSASSINO", "PIROMANTE", "XAMA"]:
		var equip_button := Button.new()
		equip_button.custom_minimum_size.y = 38
		equip_button.pressed.connect(_cycle_equipment.bind(kind))
		inventory_box.add_child(equip_button)
		inventory_buttons[kind] = equip_button
	_update_inventory()
	npc_dialog_panel = PanelContainer.new()
	npc_dialog_panel.position = Vector2(0, 0)
	npc_dialog_panel.anchor_left = 0.28
	npc_dialog_panel.anchor_right = 0.72
	npc_dialog_panel.anchor_top = 0.28
	npc_dialog_panel.anchor_bottom = 0.65
	npc_dialog_panel.visible = false
	layer.add_child(npc_dialog_panel)
	var dialog_box := VBoxContainer.new()
	npc_dialog_panel.add_child(dialog_box)
	shop_panel = PanelContainer.new()
	shop_panel.position = Vector2(0, 0)
	shop_panel.anchor_left = 0.18
	shop_panel.anchor_right = 0.82
	shop_panel.anchor_top = 0.20
	shop_panel.anchor_bottom = 0.78
	shop_panel.visible = false
	layer.add_child(shop_panel)
	var shop_box := VBoxContainer.new()
	shop_panel.add_child(shop_box)
	shop_label = Label.new()
	shop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_box.add_child(shop_label)
	for item in ["DANO", "VIDA", "CURA"]:
		var buy_button := Button.new()
		buy_button.custom_minimum_size.y = 42
		buy_button.pressed.connect(_buy_shop_item.bind(item))
		shop_box.add_child(buy_button)
		shop_buttons[item] = buy_button
	var close_shop := Button.new()
	close_shop.text = "FECHAR LOJA"
	close_shop.pressed.connect(func(): shop_panel.visible = false)
	shop_box.add_child(close_shop)
	npc_dialog_label = Label.new()
	npc_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_box.add_child(npc_dialog_label)
	var shop_button := Button.new()
	shop_button.text = "ABRIR LOJA DO ORÁCULO"
	shop_button.custom_minimum_size.y = 42
	shop_button.pressed.connect(_open_shop)
	dialog_box.add_child(shop_button)
	var close_dialog := Button.new()
	close_dialog.text = "FECHAR"
	close_dialog.pressed.connect(func(): npc_dialog_panel.visible = false)
	dialog_box.add_child(close_dialog)
	# Controles em duas fileiras: botões maiores, com espaço entre eles.
	# A área de ações começa após o direcional para não sobrepor os comandos.
	var controls := GridContainer.new()
	controls.columns = 4
	controls.anchor_left = 0.22
	controls.anchor_top = 1.0
	controls.anchor_right = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = 8
	controls.offset_top = -166
	controls.offset_right = -18
	controls.offset_bottom = -14
	controls.add_theme_constant_override("h_separation", 12)
	controls.add_theme_constant_override("v_separation", 12)
	layer.add_child(controls)
	for action in ["ATACAR", "ESPECIAL", "ESQUIVA", "DEFESA", "ORDEN", "CLASSE", "INVENTARIO", "FALAR"]:
		var button := Button.new()
		button.text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 68)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_control.bind("TALK" if action == "FALAR" else action))
		controls.add_child(button)
	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.position = Vector2(22, -232)
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.custom_minimum_size = Vector2(210, 210)
	dpad.add_theme_constant_override("h_separation", 8)
	dpad.add_theme_constant_override("v_separation", 8)
	layer.add_child(dpad)
	for direction in ["", "ui_up", "", "ui_left", "", "ui_right", "", "ui_down", ""]:
		var move_button := Button.new()
		move_button.text = "▲" if direction == "ui_up" else ("▼" if direction == "ui_down" else ("◀" if direction == "ui_left" else ("▶" if direction == "ui_right" else "")))
		move_button.custom_minimum_size = Vector2(64, 64)
		move_button.add_theme_font_size_override("font_size", 24)
		move_button.disabled = direction == ""
		if direction != "":
			move_button.button_down.connect(Input.action_press.bind(direction))
			move_button.button_up.connect(Input.action_release.bind(direction))
			move_button.mouse_exited.connect(_release_direction.bind(direction))
		dpad.add_child(move_button)
	pause_button = Button.new()
	pause_button.text = "Ⅱ PAUSAR"
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -174
	pause_button.offset_right = -18
	pause_button.offset_top = 18
	pause_button.offset_bottom = 74
	pause_button.add_theme_font_size_override("font_size", 17)
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)
	pause_panel = PanelContainer.new()
	pause_panel.anchor_left = 0.32
	pause_panel.anchor_right = 0.68
	pause_panel.anchor_top = 0.28
	pause_panel.anchor_bottom = 0.72
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_panel.add_child(pause_box)
	var pause_title := Label.new()
	pause_title.text = "JOGO PAUSADO"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 24)
	pause_box.add_child(pause_title)
	var resume_button := Button.new()
	resume_button.text = "CONTINUAR"
	resume_button.custom_minimum_size.y = 52
	resume_button.pressed.connect(_toggle_pause)
	pause_box.add_child(resume_button)
	var save_button := Button.new()
	save_button.text = "SALVAR PROGRESSO"
	save_button.custom_minimum_size.y = 46
	save_button.pressed.connect(_save_progress)
	pause_box.add_child(save_button)
	var hint := Label.new()
	hint.text = "WASD / setas: mover   •   toque: botões   •   toque em ORDEM para comandar a horda"
	hint.position = Vector2(18, 116)
	layer.add_child(hint)

func _toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	pause_panel.visible = should_pause
	if pause_button:
		pause_button.text = "▶ RETOMAR" if should_pause else "Ⅱ PAUSAR"

func _release_direction(action: String) -> void:
	Input.action_release(action)

func _toggle_npc_dialog() -> void:
	if npc_dialog_panel == null or not npc_nearby:
		return
	npc_dialog_panel.visible = not npc_dialog_panel.visible
	if npc_dialog_panel.visible:
		npc_dialog_label.text = "ORÁCULO DAS CINZAS\n\nAs ruínas estão despertando. " + _quest_description() + ".\n\n" + ("Prove sua força contra os guardiões. Cada vitória concede experiência." if quest_index == 0 else "O tirano abissal aguarda no portal. Derrote Nekravor para receber a recompensa lendária.") + "\n\nContratos concluídos: %d" % quests_completed

func _open_shop() -> void:
	if not npc_nearby or shop_panel == null:
		return
	npc_dialog_panel.visible = false
	shop_panel.visible = true
	_update_shop()

func _buy_shop_item(item: String) -> void:
	var cost := 80 if item == "DANO" else (65 if item == "VIDA" else 25)
	if ash_shards < cost:
		return
	ash_shards -= cost
	match item:
		"DANO":
			shop_damage_bonus += 0.05
		"VIDA":
			shop_health_bonus += 20.0
			max_player_health += 20.0
			player_health = minf(max_player_health, player_health + 20.0)
		"CURA":
			player_health = minf(max_player_health, player_health + 45.0)
	_save_progress()
	_update_shop()
	_update_inventory()
	_update_status()

func _update_shop() -> void:
	if shop_label == null:
		return
	shop_label.text = "LOJA DO ORÁCULO DAS CINZAS\\nFragmentos disponíveis: %d\\n\\nDANO SOMBRIO — 80 fragmentos\\n+5%% de dano permanente\\n\\nVITALIDADE — 65 fragmentos\\n+20 de vida máxima\\n\\nELIXIR DAS CINZAS — 25 fragmentos\\nRecupera até 45 de vida" % ash_shards
	for item in ["DANO", "VIDA", "CURA"]:
		var button := shop_buttons.get(item) as Button
		if button:
			var cost := 80 if item == "DANO" else (65 if item == "VIDA" else 25)
			button.disabled = ash_shards < cost
			button.text = ("COMPRAR DANO — 80" if item == "DANO" else ("COMPRAR VIDA — 65" if item == "VIDA" else "COMPRAR CURA — 25"))

func _on_control(action: String) -> void:
	if boss_intro_timer > 0.0:
		return
	match action:
		"ATACAR":
			_attack()
		"ESPECIAL":
			_cast_spell()
		"ESQUIVA":
			_dodge()
		"DEFESA":
			guarding = not guarding
			_update_status()
		"ORDEN":
			selected_order = "ATACAR" if selected_order == "SEGUIR" else "SEGUIR"
			_update_status()
		"CLASSE":
			var keys := MINION_COLORS.keys()
			selected_class = keys[(keys.find(selected_class) + 1) % keys.size()]
			_update_status()
		"INVENTARIO":
			inventory_panel.visible = not inventory_panel.visible
			_update_inventory()
		"TALK":
			_toggle_npc_dialog()

func _damage_enemy(enemy: Node3D, amount: float) -> void:
	if not is_instance_valid(enemy):
		return
	var final_damage := amount * (1.0 + relic_damage_bonus + shop_damage_bonus)
	var hp := float(enemy.get_meta("health", 90.0)) - final_damage
	enemy.set_meta("health", hp)
	# Reação curta ao impacto: flash, pulsação de escala e recuo visual.
	_spawn_combat_flash(enemy.global_position + Vector3(0, 1.05, 0), Color(1.0, 0.32, 0.12), 1.15)
	if not bool(enemy.get_meta("is_hit_reacting", false)):
		enemy.set_meta("is_hit_reacting", true)
		var base_scale := enemy.scale
		var hit_tween := create_tween()
		hit_tween.tween_property(enemy, "scale", base_scale * Vector3(1.10, 0.92, 1.10), 0.055)
		hit_tween.tween_property(enemy, "scale", base_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hit_tween.tween_callback(func():
			if is_instance_valid(enemy):
				enemy.set_meta("is_hit_reacting", false)
		)
	if hp <= 0.0:
		var at := enemy.global_position
		var defeated_boss := bool(enemy.get_meta("is_boss", false))
		_advance_quest(defeated_boss)
		_gain_experience(180 if defeated_boss else 35)
		ash_shards += 100 if defeated_boss else 12
		_save_progress()
		_update_shop()
		enemies.erase(enemy)
		enemy.queue_free()
		if defeated_boss:
			relic_count += 1
			relic_damage_bonus += 0.10
			_upgrade_minion_relics()
			player_health = minf(max_player_health, player_health + 30.0)
			_spawn_special_ring(at + Vector3(0, 0.15, 0), Color(0.72, 0.32, 1.0), 7.0)
			_show_relic_reward()
			_update_inventory()
			if boss_name_label:
				boss_name_label.visible = false
			if boss_health_bar:
				boss_health_bar.visible = false
		if enemies.is_empty():
			wave += 1
			if wave % 3 == 0:
				_create_boss(at + Vector3(0, 0, -7))
			else:
				for i in range(mini(wave, 4)):
					_create_enemy(at + Vector3(randf_range(-5, 5), 0, randf_range(-7, -3)))
		_update_status()
	else:
		_update_boss_hud()

func _upgrade_minion_relics() -> void:
	var relic_colors := {
		"BRUTAMONTES": Color(1.0, 0.36, 0.06),
		"ASSASSINO": Color(0.18, 1.0, 0.48),
		"PIROMANTE": Color(1.0, 0.12, 0.025),
		"XAMA": Color(0.12, 0.52, 1.0)
	}
	for minion in minions:
		var kind := String(minion.get_meta("class", "BRUTAMONTES"))
		var glow_color: Color = relic_colors.get(kind, Color(0.7, 0.2, 1.0))
		var emblem := minion.get_node_or_null("RelicEmblem") as MeshInstance3D
		if emblem == null:
			emblem = MeshInstance3D.new()
			emblem.name = "RelicEmblem"
			var gem := SphereMesh.new()
			gem.radius = 0.16
			gem.height = 0.32
			emblem.mesh = gem
			emblem.position = Vector3(0, 0.78, -0.45)
			minion.add_child(emblem)
			var halo := MeshInstance3D.new()
			halo.name = "RelicHalo"
			var halo_mesh := TorusMesh.new()
			halo_mesh.inner_radius = 0.28
			halo_mesh.outer_radius = 0.36
			halo.mesh = halo_mesh
			halo.position = Vector3(0, 1.38, 0)
			halo.rotation.x = deg_to_rad(90)
			minion.add_child(halo)
		var glow := _glow_material(glow_color)
		glow.emission_energy_multiplier = 2.2 + float(relic_count) * 0.45
		emblem.material_override = glow
		var halo_node := minion.get_node("RelicHalo") as MeshInstance3D
		halo_node.material_override = glow
		halo_node.scale = Vector3.ONE * (1.0 + float(relic_count - 1) * 0.12)


func _equipment_damage_multiplier(kind: String) -> float:
	var tier := int(equipment_tiers.get(kind, 0))
	return [1.0, 1.18, 1.38, 1.65][clampi(tier, 0, 3)]

func _cycle_equipment(kind: String) -> void:
	var max_unlocked := mini(relic_count, 3)
	var current := int(equipment_tiers.get(kind, 0))
	equipment_tiers[kind] = 0 if current >= max_unlocked else current + 1
	for minion in minions:
		if is_instance_valid(minion) and String(minion.get_meta("class", "")) == kind:
			minion.set_meta("equipment_tier", int(equipment_tiers[kind]))
	_update_inventory()

func _inventory_text() -> String:
	return "INVENTÁRIO ABISSAL\nNível %d  |  XP: %d/%d  |  Pontos: %d\nForça %d  •  Vitalidade %d  •  Arcano %d\nVida máxima: %d  |  Relíquias: %d  |  Dano global: +%d%%\nFragmentos de Cinza: %d  |  Bônus da loja: +%d%% dano / +%d vida\nEquipamentos aprimorados causam mais dano e atacam mais rápido.\nCada relíquia libera um nível (máx. 3)." % [player_level, player_xp, _xp_to_next_level(), unspent_attribute_points, strength_attribute, vitality_attribute, arcane_attribute, int(max_player_health), relic_count, int(relic_damage_bonus * 100.0), ash_shards, int(shop_damage_bonus * 100.0), int(shop_health_bonus)]

func _update_inventory() -> void:
	if inventory_label:
		inventory_label.text = _inventory_text()
	for attribute in ["FORÇA", "VITALIDADE", "ARCANO"]:
		var attribute_button := inventory_buttons.get("ATRIBUTO_" + attribute) as Button
		if attribute_button:
			var current := strength_attribute if attribute == "FORÇA" else (vitality_attribute if attribute == "VITALIDADE" else arcane_attribute)
			attribute_button.text = "%s — %d  |  gastar 1 ponto" % [attribute, current]
			attribute_button.disabled = unspent_attribute_points <= 0
	for kind in ["BRUTAMONTES", "ASSASSINO", "PIROMANTE", "XAMA"]:
		var tier := int(equipment_tiers.get(kind, 0))
		var max_unlocked := mini(relic_count, 3)
		var weapon_name: String = str({"BRUTAMONTES": "Martelo do Núcleo", "ASSASSINO": "Gêmeas do Eclipse", "PIROMANTE": "Orbe da Chama", "XAMA": "Totem da Aurora"}[kind])
		var button := inventory_buttons[kind] as Button
		button.text = "%s — %s  |  Nível %d/%d (+%d%% dano)" % [kind, weapon_name, tier, max_unlocked, int((_equipment_damage_multiplier(kind) - 1.0) * 100.0)]
		button.disabled = max_unlocked == 0

func _show_relic_reward() -> void:
	if not boss_intro_label:
		return
	boss_intro_label.text = "RELÍQUIA ABISSAL DESBLOQUEADA\n+10% DANO  •  +30 VIDA\nRelíquias: %d" % relic_count
	boss_intro_label.visible = true
	boss_intro_label.modulate.a = 1.0
	var reward_tween := create_tween()
	reward_tween.tween_interval(2.8)
	reward_tween.tween_property(boss_intro_label, "modulate:a", 0.0, 0.8)
	reward_tween.tween_callback(func(): boss_intro_label.visible = false)

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
	var gait_rate := 10.5 if moving else 2.0
	var stride := sin(anim_clock * gait_rate + phase)
	var idle_breath := sin(anim_clock * 2.2 + phase)
	actor.position.y = 0.055 * absf(stride) if moving else 0.025 * idle_breath

	var left_arm := actor.get_node_or_null("Arm_L") as Node3D
	var right_arm := actor.get_node_or_null("Arm_R") as Node3D
	var left_leg := actor.get_node_or_null("Leg_L") as Node3D
	var right_leg := actor.get_node_or_null("Leg_R") as Node3D
	var weapon := actor.get_node_or_null("WeaponPivot") as Node3D
	var chest := actor.get_node_or_null("TorsoPivot") as Node3D
	var head := actor.get_node_or_null("HeadPivot") as Node3D

	if left_leg:
		left_leg.rotation.x = stride * 0.48 if moving else 0.025 * idle_breath
	if right_leg:
		right_leg.rotation.x = -stride * 0.48 if moving else -0.025 * idle_breath
	if left_arm:
		left_arm.rotation.x = -stride * 0.34 if moving else 0.035 * idle_breath
	if right_arm and not actor.has_meta("weapon_striking"):
		right_arm.rotation.x = stride * 0.34 if moving else -0.035 * idle_breath
	if weapon and not actor.has_meta("weapon_striking"):
		weapon.rotation.z = sin(anim_clock * (3.0 if moving else 1.8) + phase) * 0.045
	if chest:
		chest.rotation.z = sin(anim_clock * gait_rate + phase) * (0.035 if moving else 0.012)
	if head:
		head.rotation.x = sin(anim_clock * 1.4 + phase) * 0.025

func _attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.32
	combo_step = (combo_step % 3) + 1
	combo_window = 0.85
	_weapon_strike(player.get_child(0) as Node3D)
	_spawn_combat_flash(player.global_position + player.global_basis * Vector3(0, 1.1, -1.35), Color(1.0, 0.58, 0.16), 2.8 + combo_step * 0.22)
	for enemy in enemies:
		if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 4.0:
			_spawn_combat_flash(enemy.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.25, 0.08), 1.7)
			_damage_enemy(enemy, (24.0 + combo_step * 9.0) * (1.0 + float(strength_attribute) * 0.04))
			if combo_step == 3:
				_spawn_special_ring(enemy.global_position + Vector3(0, 0.15, 0), Color(1.0, 0.52, 0.12), 1.9)
			break


func _dodge() -> void:
	if dodge_cooldown > 0.0 or boss_intro_timer > 0.0:
		return
	var input := Vector2.ZERO if boss_intro_timer > 0.0 else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dodge_direction = Vector3(input.x, 0, input.y)
	if dodge_direction.length() < 0.1:
		dodge_direction = -player.global_basis.z
	dodge_direction = dodge_direction.normalized()
	dodge_time = 0.22
	dodge_cooldown = 1.1
	_spawn_special_ring(player.global_position + Vector3(0, 0.12, 0), Color(0.55, 0.55, 0.62), 1.45)

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
	if special_cooldown > 0.0:
		return
	special_cooldown = 5.0
	match selected_class:
		"BRUTAMONTES":
			# Impacto pesado: dano em área curta e onda de choque.
			_spawn_special_ring(player.global_position + Vector3(0, 0.12, 0), Color(1.0, 0.30, 0.045), 4.2)
			_spawn_combat_flash(player.global_position + Vector3(0, 1.0, -0.8), Color(1.0, 0.38, 0.06), 3.4)
			for enemy in enemies.duplicate():
				if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 5.5:
					_damage_enemy(enemy, 55.0 * (1.0 + float(arcane_attribute) * 0.05))
		"ASSASSINO":
			# Três cortes rápidos no alvo mais próximo.
			var target: Node3D = _nearest_enemy()
			if target:
				for hit in range(3):
					if is_instance_valid(target):
						_spawn_combat_flash(target.global_position + Vector3(0, 1.0, 0), Color(0.35, 1.0, 0.48), 1.25 + hit * 0.18)
						_damage_enemy(target, 17.0 * (1.0 + float(arcane_attribute) * 0.05))
			else:
				_spawn_combat_flash(player.global_position + Vector3(0, 1.0, -1.0), Color(0.35, 1.0, 0.48), 2.0)
		"PIROMANTE":
			_cast_fireball()
		"XAMA":
			# Pulso espiritual: recupera o senhor sombrio e fere inimigos próximos.
			player_health = minf(max_player_health, player_health + 28.0 + float(vitality_attribute) * 0.5)
			_spawn_special_ring(player.global_position + Vector3(0, 0.15, 0), Color(0.12, 0.68, 1.0), 3.8)
			_spawn_combat_flash(player.global_position + Vector3(0, 1.4, 0), Color(0.12, 0.68, 1.0), 2.6)
			for enemy in enemies.duplicate():
				if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) < 7.0:
					_spawn_combat_flash(enemy.global_position + Vector3(0, 1.0, 0), Color(0.12, 0.68, 1.0), 1.8)
					_damage_enemy(enemy, 22.0 * (1.0 + float(arcane_attribute) * 0.05))
	_update_status()

func _nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var best_distance := 999.0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance := player.global_position.distance_to(enemy.global_position)
			if distance < best_distance:
				best_distance = distance
				nearest = enemy
	return nearest

func _cast_fireball() -> void:
	var target := _nearest_enemy()
	var destination := player.global_position + player.global_basis * Vector3(0, 1.2, -9.0)
	if target:
		destination = target.global_position + Vector3(0, 1.0, 0)
	var fireball := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.38
	orb.height = 0.76
	fireball.mesh = orb
	fireball.material_override = _glow_material(Color(1.0, 0.20, 0.025))
	fireball.global_position = player.global_position + Vector3(0, 1.35, 0)
	add_child(fireball)
	var tween := create_tween()
	tween.tween_property(fireball, "global_position", destination, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_explode_fireball.bind(fireball))

func _explode_fireball(fireball: Node3D) -> void:
	if not is_instance_valid(fireball):
		return
	var impact := fireball.global_position
	_spawn_combat_flash(impact, Color(1.0, 0.24, 0.025), 3.2)
	_spawn_special_ring(impact, Color(1.0, 0.36, 0.04), 2.0)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and impact.distance_to(enemy.global_position) < 3.8:
			_damage_enemy(enemy, 48.0)
	fireball.queue_free()

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
			damage *= _equipment_damage_multiplier(kind)
			_damage_enemy(target_enemy, damage)
			var tier := int(minion.get_meta("equipment_tier", 0))
			var base_cooldown := 0.9 if kind != "ASSASSINO" else 0.55
			timer = base_cooldown * (1.0 - float(tier) * 0.08)
		minion.set_meta("attack_timer", timer)


func _update_boss_hud() -> void:
	if not boss_health_bar or not boss_name_label:
		return
	for enemy in enemies:
		if is_instance_valid(enemy) and bool(enemy.get_meta("is_boss", false)):
			boss_name_label.visible = true
			boss_health_bar.visible = true
			boss_health_bar.value = float(enemy.get_meta("health", 720.0))
			return
	boss_name_label.visible = false
	boss_health_bar.visible = false

func _update_boss_ai(delta: float) -> void:
	for boss in enemies:
		if not is_instance_valid(boss) or not bool(boss.get_meta("is_boss", false)):
			continue
		if boss_intro_timer > 0.0:
			continue
		var hp := float(boss.get_meta("health", 720.0))
		var phase_two := hp <= 360.0
		if phase_two and not bool(boss.get_meta("phase_two", false)):
			boss.set_meta("phase_two", true)
			boss.set_meta("attack_timer", 0.7)
			boss.scale = Vector3.ONE * 1.82
			for part in boss.get_children():
				if part is MeshInstance3D and (bool(part.get_meta("boss_eye", false)) or bool(part.get_meta("boss_crown", false)) or bool(part.get_meta("boss_tentacle", false))):
					part.material_override = _glow_material(Color(1.0, 0.025, 0.12))
				if part is MeshInstance3D and part.mesh is SphereMesh and part.position.y > 2.0:
					part.material_override = _glow_material(Color(0.55, 0.015, 0.10))
			_spawn_special_ring(boss.global_position + Vector3(0, 0.15, 0), Color(1.0, 0.025, 0.18), 6.2)
			_spawn_combat_flash(boss.global_position + Vector3(0, 2.1, 0), Color(0.85, 0.015, 0.16), 4.0)
		var to_player := player.global_position - boss.global_position
		to_player.y = 0.0
		var distance := to_player.length()
		if distance > 3.2:
			boss.global_position += to_player.normalized() * (1.15 if not phase_two else 1.75) * delta
			boss.look_at(Vector3(player.global_position.x, boss.global_position.y, player.global_position.z), Vector3.UP)
		var telegraph := float(boss.get_meta("telegraph_timer", 0.0))
		if telegraph > 0.0:
			telegraph = maxf(0.0, telegraph - delta)
			boss.set_meta("telegraph_timer", telegraph)
			if telegraph <= 0.0:
				var impact_distance := Vector2(player.global_position.x - boss.global_position.x, player.global_position.z - boss.global_position.z).length()
				var impact_radius := 5.8 if phase_two else 4.4
				_spawn_special_ring(boss.global_position + Vector3(0, 0.16, 0), Color(1.0, 0.025, 0.18) if phase_two else Color(0.68, 0.08, 0.95), impact_radius)
				if impact_distance < impact_radius and dodge_time <= 0.0:
					player_health = maxf(0.0, player_health - (22.0 if phase_two else 13.0) * (0.35 if guarding else 1.0) * (100.0 / max_player_health))
					_spawn_combat_flash(player.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.025, 0.18) if phase_two else Color(0.72, 0.08, 1.0), 2.3)
					_update_status()
		elif distance < 5.2:
			var timer := maxf(0.0, float(boss.get_meta("attack_timer", 1.8)) - delta)
			if timer <= 0.0:
				boss.set_meta("telegraph_timer", 0.95)
				_spawn_special_ring(boss.global_position + Vector3(0, 0.14, 0), Color(1.0, 0.025, 0.18) if phase_two else Color(0.68, 0.08, 0.95), 4.5 if not phase_two else 5.8)
				if phase_two:
					# Segunda onda da ruptura: o jogador precisa esquivar duas vezes.
					var followup := create_tween()
					followup.tween_interval(0.32)
					followup.tween_callback(_spawn_special_ring.bind(boss.global_position + Vector3(0, 0.18, 0), Color(1.0, 0.12, 0.28), 7.0))
				timer = 2.6 if not phase_two else 1.8
			boss.set_meta("attack_timer", timer)
		_animate_actor(boss, delta, 1.0, 2.8)
	_update_boss_hud()

func _update_enemy_ai(delta: float) -> void:
	player_hit_cooldown = maxf(0.0, player_hit_cooldown - delta)
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get_meta("is_boss", false)):
			continue
		var to_player := player.global_position - enemy.global_position
		to_player.y = 0.0
		var distance := to_player.length()
		if distance > 1.7:
			enemy.global_position += to_player.normalized() * 1.6 * delta
			enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
		elif player_hit_cooldown <= 0.0 and dodge_time <= 0.0:
			var incoming_damage := (2.0 if guarding else 8.0) * (100.0 / max_player_health)
			player_health = maxf(0.0, player_health - incoming_damage)
			_spawn_combat_flash(player.global_position + Vector3(0, 1.0, 0), Color(0.9, 0.03, 0.02), 1.4)
			player_hit_cooldown = 1.0
			_update_status()

func _update_status() -> void:
	if status_label:
		status_label.text = "Nv.%d  XP %d/%d  |  Vida: %d/%d  |  Horda: %d  |  Ordem: %s  |  Classe: %s  |  Combo: %d/3  |  Defesa: %s  |  Onda: %d" % [player_level, player_xp, _xp_to_next_level(), int(player_health), int(max_player_health), minions.size(), selected_order, selected_class, combo_step, "ON" if guarding else "OFF", wave]
	_update_quest_hud()
	_update_shop()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if is_instance_valid(player) and is_instance_valid(npc_node):
		npc_nearby = player.global_position.distance_to(npc_node.global_position) <= 3.2
		if Input.is_action_just_pressed("interact") and npc_nearby:
			_toggle_npc_dialog()
	anim_clock += delta
	boss_intro_timer = maxf(0.0, boss_intro_timer - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	combo_window = maxf(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo_step = 0
	special_cooldown = maxf(0.0, special_cooldown - delta)
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if not is_instance_valid(player):
		return
	if boss_intro_timer > 0.0:
		input = Vector2.ZERO
	var move_direction := Vector3(input.x, 0.0, input.y)
	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()
	var move_speed := 6.2
	if dodge_time > 0.0:
		move_direction = dodge_direction
		move_speed = 14.0
	player.velocity.x = move_direction.x * move_speed
	player.velocity.z = move_direction.z * move_speed
	if not player.is_on_floor():
		player.velocity.y -= 24.0 * delta
	else:
		player.velocity.y = 0.0
	player.move_and_slide()
	if move_direction.length_squared() > 0.01:
		player.rotation.y = atan2(-move_direction.x, -move_direction.z)
	_animate_actor(player.get_child(0) as Node3D, delta, move_direction.length() * (1.0 if dodge_time <= 0.0 else 1.5), 0.0)
	_update_boss_ai(delta)
	_update_enemy_ai(delta)
