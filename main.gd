extends Node3D

# IRONFALL: offline 3D city driving prototype
# Original procedural assets; designed for Android + desktop.

const MAX_SPEED := 24.0
const REVERSE_SPEED := 9.0
const ACCELERATION := 16.0
const BRAKE_POWER := 24.0
const DRAG := 7.0
const STEER_RATE := 1.65
const GRAVITY := 18.0

var car: CharacterBody3D
var camera: Camera3D
var car_visual: Node3D
var wheels: Array[MeshInstance3D] = []
var speed := 0.0
var steering := 0.0
var health := 100
var distance_driven := 0.0
var touch_left := false
var touch_right := false
var touch_gas := false
var touch_brake := false
var horn_pressed := false
var hud: Label
var status_label: Label
var camera_target := Vector3.ZERO

func mat(color: Color, metallic := 0.0, roughness := 0.75) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func make_box(parent: Node, pos: Vector3, size: Vector3, color: Color, collision := true) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = size
    mesh_node.mesh = box_mesh
    mesh_node.position = pos
    mesh_node.material_override = mat(color)
    parent.add_child(mesh_node)

    if collision:
        var body := StaticBody3D.new()
        body.position = pos
        var shape := CollisionShape3D.new()
        var box_shape := BoxShape3D.new()
        box_shape.size = size
        shape.shape = box_shape
        body.add_child(shape)
        parent.add_child(body)
    return mesh_node

func _ready() -> void:
    _build_city()
    _spawn_player_car()
    _spawn_parked_cars()
    _build_hud()
    _update_camera(1.0)

func _build_city() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("#9ab6c8")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.72, 0.76, 0.80)
    e.ambient_light_energy = 1.15
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    add_child(sun)

    # Large city ground.
    make_box(self, Vector3(0, -0.35, 0), Vector3(180, 0.5, 180), Color("#55575a"))

    # Four broad roads crossing the city.
    var road_color := Color("#292b2e")
    for x in [-48.0, 0.0, 48.0]:
        make_box(self, Vector3(x, -0.08, 0), Vector3(15, 0.12, 180), road_color, false)
    for z in [-48.0, 0.0, 48.0]:
        make_box(self, Vector3(0, -0.07, z), Vector3(180, 0.12, 15), road_color, false)

    # Sidewalk strips.
    var sidewalk := Color("#b7b4ae")
    for x in [-56.0, -40.0, -8.0, 8.0, 40.0, 56.0]:
        make_box(self, Vector3(x, 0.02, 0), Vector3(1.2, 0.18, 180), sidewalk, false)
    for z in [-56.0, -40.0, -8.0, 8.0, 40.0, 56.0]:
        make_box(self, Vector3(0, 0.03, z), Vector3(180, 0.18, 1.2), sidewalk, false)

    # Lane markings.
    var line_color := Color("#d9d4a4")
    for z in [-48.0, 0.0, 48.0]:
        for x in range(-80, 81, 12):
            make_box(self, Vector3(x, 0.03, z), Vector3(6, 0.035, 0.18), line_color, false)
    for x in [-48.0, 0.0, 48.0]:
        for z in range(-80, 81, 12):
            make_box(self, Vector3(x, 0.035, z), Vector3(0.18, 0.035, 6), line_color, false)

    # Procedural city blocks.
    var building_colors := [
        Color("#6f7d84"), Color("#8a7668"), Color("#677487"),
        Color("#8b8b83"), Color("#706a72"), Color("#927d6b")
    ]
    var blocks := [
        Vector3(-24,0,-24), Vector3(24,0,-24),
        Vector3(-24,0,24), Vector3(24,0,24),
        Vector3(-72,0,-24), Vector3(72,0,-24),
        Vector3(-72,0,24), Vector3(72,0,24),
        Vector3(-24,0,-72), Vector3(24,0,-72),
        Vector3(-24,0,72), Vector3(24,0,72),
        Vector3(-72,0,-72), Vector3(72,0,-72),
        Vector3(-72,0,72), Vector3(72,0,72)
    ]

    for i in blocks.size():
        var p: Vector3 = blocks[i]
        var h := 7.0 + float(i % 4) * 2.8
        var w := 13.0 + float((i + 1) % 3) * 2.0
        var d := 13.0 + float((i + 2) % 3) * 2.0
        make_box(self, p + Vector3(0, h * 0.5, 0), Vector3(w, h, d), building_colors[i % building_colors.size()])

        # Simple roof structure and windows.
        make_box(self, p + Vector3(0, h + 0.25, 0), Vector3(w * 0.65, 0.5, d * 0.65), Color("#555a5e"), false)
        for wx in [-0.32, 0.0, 0.32]:
            make_box(self, p + Vector3(w * wx, h * 0.58, -d * 0.51), Vector3(w * 0.12, 1.0, 0.08), Color("#b7d5df"), false)

    # Trees for visual depth.
    for i in 28:
        var tree := Node3D.new()
        tree.position = Vector3(-82 + float((i * 31) % 164), 0, -82 + float((i * 47) % 164))
        add_child(tree)
        make_box(tree, Vector3(0, 1.3, 0), Vector3(0.45, 2.6, 0.45), Color("#5c4434"), false)
        var crown := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 1.4
        sphere.height = 2.5
        crown.mesh = sphere
        crown.position = Vector3(0, 3.1, 0)
        crown.material_override = mat(Color("#3f704d"))
        tree.add_child(crown)

func _make_wheel(parent: Node3D, pos: Vector3) -> MeshInstance3D:
    var wheel := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.62
    cylinder.bottom_radius = 0.62
    cylinder.height = 0.34
    wheel.mesh = cylinder
    wheel.rotation_degrees = Vector3(0, 0, 90)
    wheel.position = pos
    wheel.material_override = mat(Color("#17191b"), 0.1, 0.55)
    parent.add_child(wheel)
    wheels.append(wheel)
    return wheel

func _spawn_player_car() -> void:
    car = CharacterBody3D.new()
    car.name = "PlayerCar"
    car.position = Vector3(0, 0.9, 22)
    add_child(car)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.35, 1.2, 4.7)
    collision.shape = shape
    collision.position.y = 0.55
    car.add_child(collision)

    car_visual = Node3D.new()
    car.add_child(car_visual)

    # Sedan body.
    make_box(car_visual, Vector3(0, 0.62, 0), Vector3(2.25, 0.72, 4.55), Color("#c6c2b9"), false)
    make_box(car_visual, Vector3(0, 1.02, -0.25), Vector3(1.82, 0.58, 2.15), Color("#d0cbc1"), false)

    # Windows.
    make_box(car_visual, Vector3(0, 1.18, -0.88), Vector3(1.62, 0.42, 0.72), Color("#26353d"), false)
    make_box(car_visual, Vector3(0, 1.18, 0.48), Vector3(1.62, 0.42, 0.72), Color("#26353d"), false)

    # Bumpers / lights.
    make_box(car_visual, Vector3(0, 0.52, -2.32), Vector3(2.05, 0.22, 0.18), Color("#eeeeea"), false)
    make_box(car_visual, Vector3(-0.72, 0.7, -2.34), Vector3(0.38, 0.18, 0.08), Color("#f4e8b2"), false)
    make_box(car_visual, Vector3(0.72, 0.7, -2.34), Vector3(0.38, 0.18, 0.08), Color("#f4e8b2"), false)

    for x in [-0.98, 0.98]:
        for z in [-1.52, 1.52]:
            _make_wheel(car_visual, Vector3(x, 0.42, z))

    # Follow camera is a child only for initial setup; position is updated smoothly.
    camera = Camera3D.new()
    camera.current = true
    add_child(camera)

func _spawn_parked_cars() -> void:
    _make_parked_car(Vector3(18, 0.8, 22), Color("#315a88"), 0.0)
    _make_parked_car(Vector3(-18, 0.8, 22), Color("#f1f1eb"), PI)
    _make_parked_car(Vector3(48, 0.8, 18), Color("#3c3d40"), PI * 0.5)
    _make_parked_car(Vector3(-48, 0.8, -18), Color("#8a3434"), -PI * 0.5)

func _make_parked_car(pos: Vector3, color: Color, rot_y: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.rotation.y = rot_y
    add_child(root)
    make_box(root, Vector3(0, 0.55, 0), Vector3(2.1, 0.65, 4.2), color, false)
    make_box(root, Vector3(0, 0.95, -0.15), Vector3(1.7, 0.5, 1.9), Color("#29363d"), false)
    for x in [-0.92, 0.92]:
        for z in [-1.35, 1.35]:
            var w := MeshInstance3D.new()
            var wm := CylinderMesh.new()
            wm.top_radius = 0.52
            wm.bottom_radius = 0.52
            wm.height = 0.28
            w.mesh = wm
            w.rotation_degrees = Vector3(0, 0, 90)
            w.position = Vector3(x, 0.32, z)
            w.material_override = mat(Color("#17191b"))
            root.add_child(w)

func _button(parent: Control, text_value: String, pos: Vector2, size: Vector2) -> Button:
    var b := Button.new()
    b.text = text_value
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 24)
    parent.add_child(b)
    return b

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)

    hud = Label.new()
    hud.position = Vector2(28, 24)
    hud.add_theme_font_size_override("font_size", 26)
    root.add_child(hud)

    status_label = Label.new()
    status_label.position = Vector2(30, 64)
    status_label.add_theme_font_size_override("font_size", 18)
    root.add_child(status_label)

    var minimap := ColorRect.new()
    minimap.position = Vector2(24, 105)
    minimap.size = Vector2(170, 170)
    minimap.color = Color(0.08, 0.1, 0.12, 0.82)
    root.add_child(minimap)

    var map_title := Label.new()
    map_title.text = "CITY MAP"
    map_title.position = Vector2(38, 115)
    map_title.add_theme_font_size_override("font_size", 16)
    root.add_child(map_title)

    # Simplified street grid inside the minimap.
    for x in [70.0, 130.0]:
        var line := ColorRect.new()
        line.position = Vector2(x, 138)
        line.size = Vector2(8, 110)
        line.color = Color("#51565b")
        root.add_child(line)
    for y in [172.0, 218.0]:
        var line2 := ColorRect.new()
        line2.position = Vector2(38, y)
        line2.size = Vector2(140, 8)
        line2.color = Color("#51565b")
        root.add_child(line2)

    var marker := ColorRect.new()
    marker.name = "PlayerMarker"
    marker.position = Vector2(106, 194)
    marker.size = Vector2(8, 8)
    marker.color = Color("#e9c94a")
    root.add_child(marker)

    var gas := _button(root, "▲", Vector2(1110, 565), Vector2(105, 85))
    gas.button_down.connect(func(): touch_gas = true)
    gas.button_up.connect(func(): touch_gas = false)

    var brake := _button(root, "▼", Vector2(1110, 655), Vector2(105, 55))
    brake.button_down.connect(func(): touch_brake = true)
    brake.button_up.connect(func(): touch_brake = false)

    var left := _button(root, "◀", Vector2(890, 620), Vector2(95, 75))
    left.button_down.connect(func(): touch_left = true)
    left.button_up.connect(func(): touch_left = false)

    var right := _button(root, "▶", Vector2(990, 620), Vector2(95, 75))
    right.button_down.connect(func(): touch_right = true)
    right.button_up.connect(func(): touch_right = false)

    var horn := _button(root, "HORN", Vector2(890, 535), Vector2(95, 65))
    horn.button_down.connect(func(): horn_pressed = true)
    horn.button_up.connect(func(): horn_pressed = false)

    var reset := _button(root, "RESET", Vector2(25, 690), Vector2(120, 48))
    reset.pressed.connect(_reset_car)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_R:
        _reset_car()

func _physics_process(delta: float) -> void:
    if not car:
        return

    var throttle := 0.0
    var brake_input := 0.0
    var steer_input := 0.0

    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch_gas:
        throttle = 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or touch_brake:
        brake_input = 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch_left:
        steer_input -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch_right:
        steer_input += 1.0

    # Acceleration / braking.
    if throttle > 0.0:
        speed = move_toward(speed, MAX_SPEED, ACCELERATION * delta)
    elif brake_input > 0.0:
        if speed > 0.0:
            speed = move_toward(speed, 0.0, BRAKE_POWER * delta)
        else:
            speed = move_toward(speed, -REVERSE_SPEED, ACCELERATION * 0.65 * delta)
    else:
        speed = move_toward(speed, 0.0, DRAG * delta)

    # Steering becomes softer at low speed.
    var steer_strength := clamp(abs(speed) / 7.0, 0.0, 1.0)
    steering = move_toward(steering, steer_input, delta * 5.0)
    if abs(speed) > 0.4:
        car.rotation.y -= steering * STEER_RATE * steer_strength * delta * sign(speed)

    var forward := -car.global_transform.basis.z
    car.velocity.x = forward.x * speed
    car.velocity.z = forward.z * speed
    car.velocity.y = -0.5

    var old_position := car.global_position
    car.move_and_slide()

    # Keep the car on the city plane.
    car.global_position.y = 0.9
    distance_driven += old_position.distance_to(car.global_position)

    # A gentle reset if the car gets stuck outside the city.
    if abs(car.global_position.x) > 88 or abs(car.global_position.z) > 88:
        _reset_car()

    _update_wheels(delta)
    _update_camera(delta)

    hud.text = "IRONFALL CITY   |   %03d KM/H   |   %d%% CAR" % [int(abs(speed) * 5.0), health]
    status_label.text = "OFFLINE  •  FREE DRIVE  •  %04d m" % int(distance_driven)

func _update_wheels(delta: float) -> void:
    var wheel_spin := speed * delta * 1.8
    for w in wheels:
        if is_instance_valid(w):
            w.rotate_x(wheel_spin)

func _update_camera(delta: float) -> void:
    var forward := -car.global_transform.basis.z
    var desired := car.global_position - forward * 10.5 + Vector3(0, 5.2, 0)
    camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
    camera_target = car.global_position + forward * 4.0 + Vector3(0, 1.1, 0)
    camera.look_at(camera_target, Vector3.UP)

func _reset_car() -> void:
    car.global_position = Vector3(0, 0.9, 22)
    car.rotation = Vector3.ZERO
    car.velocity = Vector3.ZERO
    speed = 0.0
    steering = 0.0
    health = 100
