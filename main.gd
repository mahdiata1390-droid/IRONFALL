extends Node3D

const PLAYER_SPEED := 7.0
const GRAVITY := 20.0
var player: CharacterBody3D
var camera: Camera3D
var gun: MeshInstance3D
var velocity_y := 0.0
var enemies: Array[CharacterBody3D] = []
var enemy_hp: Dictionary = {}
var car: CharacterBody3D
var driving := false
var health := 100
var ammo := 30
var fire_cooldown := 0.0
var hud: Label
var crosshair: Label
var touch_move := Vector2.ZERO
var shoot_touch := false
var e_was_down := false

func _ready():
    _build_world()
    _spawn_player()
    _spawn_enemies()
    _spawn_car()
    _build_hud()

func mat(color: Color, metallic:=0.0, roughness:=0.8) -> StandardMaterial3D:
    var m=StandardMaterial3D.new()
    m.albedo_color=color
    m.metallic=metallic
    m.roughness=roughness
    return m

func box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var n=MeshInstance3D.new()
    var b=BoxMesh.new()
    b.size=size
    n.mesh=b
    n.position=pos
    n.material_override=mat(color)
    parent.add_child(n)
    var body=StaticBody3D.new()
    body.position=pos
    var shape=CollisionShape3D.new()
    var s=BoxShape3D.new()
    s.size=size
    shape.shape=s
    body.add_child(shape)
    parent.add_child(body)
    return n

func _build_world():
    var env=WorldEnvironment.new()
    var e=Environment.new()
    e.background_mode=Environment.BG_COLOR
    e.background_color=Color("#7ea9c4")
    e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color=Color(0.65,0.7,0.75)
    e.ambient_light_energy=1.0
    e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    env.environment=e
    add_child(env)
    var sun=DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-55,-25,0)
    sun.light_energy=1.2
    sun.shadow_enabled=true
    add_child(sun)
    box(self,Vector3(0,-0.35,0),Vector3(100,0.5,100),Color("#68645b"))
    for z in range(-30,31,10):
        box(self,Vector3(-25,2,z),Vector3(8,4,7),Color("#4c7180"))
        box(self,Vector3(25,2,z),Vector3(8,4,7),Color("#7b6654"))
    box(self,Vector3(0,2,-32),Vector3(60,4,3),Color("#6f6659"))
    for i in 8:
        var crate=box(self,Vector3(-12+(i%4)*8,1,-8+(i/4)*8),Vector3(3,2,3),Color("#765b3e"))
    for i in 12:
        var rock=MeshInstance3D.new()
        var sphere=SphereMesh.new()
        sphere.radius=0.8
        sphere.height=1.4
        rock.mesh=sphere
        rock.position=Vector3(-28+i*5,0.7,18+sin(i)*7)
        rock.material_override=mat(Color("#3f4542"))
        add_child(rock)

func _spawn_player():
    player=CharacterBody3D.new()
    player.name="Player"
    add_child(player)
    player.position=Vector3(0,1,12)
    var shape=CollisionShape3D.new()
    var capsule=CapsuleShape3D.new()
    capsule.radius=0.45
    capsule.height=1.8
    shape.shape=capsule
    shape.position.y=0.9
    player.add_child(shape)
    var body=MeshInstance3D.new()
    var mesh=CapsuleMesh.new()
    mesh.radius=0.45
    mesh.height=1.8
    body.mesh=mesh
    body.position.y=0.9
    body.material_override=mat(Color("#20252b"))
    player.add_child(body)
    gun=MeshInstance3D.new()
    var gm=BoxMesh.new()
    gm.size=Vector3(0.18,0.18,1.1)
    gun.mesh=gm
    gun.position=Vector3(0.45,1.25,-0.55)
    gun.material_override=mat(Color("#17191c"),0.7,0.3)
    player.add_child(gun)
    camera=Camera3D.new()
    camera.position=Vector3(0,3.5,6.5)
    camera.rotation_degrees=Vector3(-12,180,0)
    camera.current=true
    player.add_child(camera)

func _spawn_enemies():
    for i in 9:
        var e=CharacterBody3D.new()
        e.name="Enemy_%02d"%i
        add_child(e)
        e.position=Vector3(-25+(i%5)*12,1,-18+(i/5)*18)
        var cs=CollisionShape3D.new()
        var cap=CapsuleShape3D.new()
        cap.radius=0.45
        cap.height=1.8
        cs.shape=cap
        cs.position.y=0.9
        e.add_child(cs)
        var body=MeshInstance3D.new()
        var cm=CapsuleMesh.new()
        cm.radius=0.45
        cm.height=1.8
        body.mesh=cm
        body.position.y=0.9
        body.material_override=mat(Color("#9d3030"))
        e.add_child(body)
        enemies.append(e)
        enemy_hp[e]=3

func _spawn_car():
    car=CharacterBody3D.new()
    car.name="ArmoredCar"
    car.position=Vector3(12,0.8,10)
    add_child(car)
    var cs=CollisionShape3D.new()
    var sh=BoxShape3D.new()
    sh.size=Vector3(4,1.5,6)
    cs.shape=sh
    car.add_child(cs)
    var body=MeshInstance3D.new()
    var bm=BoxMesh.new()
    bm.size=Vector3(4,1.5,6)
    body.mesh=bm
    body.material_override=mat(Color("#27343a"),0.55,0.35)
    car.add_child(body)
    for x in [-1.9,1.9]:
        for z in [-2.0,2.0]:
            var wheel=MeshInstance3D.new()
            var wm=CylinderMesh.new()
            wm.top_radius=0.55
            wm.bottom_radius=0.55
            wm.height=0.35
            wheel.mesh=wm
            wheel.rotation_degrees=Vector3(0,0,90)
            wheel.position=Vector3(x, -0.35,z)
            wheel.material_override=mat(Color("#111315"))
            car.add_child(wheel)

func _build_hud():
    var layer=CanvasLayer.new()
    add_child(layer)
    hud=Label.new()
    hud.position=Vector2(28,25)
    hud.add_theme_font_size_override("font_size",24)
    layer.add_child(hud)
    crosshair=Label.new()
    crosshair.text="+"
    crosshair.position=Vector2(638,340)
    crosshair.add_theme_font_size_override("font_size",30)
    layer.add_child(crosshair)
    var help=Label.new()
    help.text="WASD  MOVE   •   CLICK  FIRE   •   E  ENTER/EXIT CAR"
    help.position=Vector2(28,670)
    help.add_theme_font_size_override("font_size",18)
    layer.add_child(help)
    var fire=Button.new()
    fire.text="FIRE"
    fire.position=Vector2(1100,570)
    fire.size=Vector2(130,100)
    fire.add_theme_font_size_override("font_size",22)
    fire.button_down.connect(func(): shoot_touch=true)
    fire.button_up.connect(func(): shoot_touch=false)
    layer.add_child(fire)

func _physics_process(delta):
    if not player: return
    fire_cooldown=max(0.0,fire_cooldown-delta)
    var dir=Vector3.ZERO
    dir.x=float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A))
    dir.z=float(Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_W))
    if dir.length()>0:
        dir=dir.normalized()
        player.velocity.x=dir.x*PLAYER_SPEED
        player.velocity.z=dir.z*PLAYER_SPEED
        player.look_at(player.global_position+Vector3(dir.x,0,dir.z),Vector3.UP)
    else:
        player.velocity.x=move_toward(player.velocity.x,0,PLAYER_SPEED*8*delta)
        player.velocity.z=move_toward(player.velocity.z,0,PLAYER_SPEED*8*delta)
    if not player.is_on_floor():
        velocity_y-=GRAVITY*delta
    else:
        velocity_y=-0.5
    player.velocity.y=velocity_y
    player.move_and_slide()
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or shoot_touch:
        _shoot()
    var e_down=Input.is_key_pressed(KEY_E)
    if e_down and not e_was_down:
        if driving:
            driving=false
            car.visible=true
            car.global_position=player.global_position + Vector3(2,0,0)
        elif player.global_position.distance_to(car.global_position)<6.0:
            driving=true
            car.visible=false
    e_was_down=e_down
    if driving:
        car.visible=true
        car.global_position=player.global_position
        car.global_position.y=0.8
    _update_enemies(delta)
    hud.text="IRONFALL   |   HP %d   |   AMMO %d   |   ENEMIES %d   |   %s"%(health,ammo,enemies.size(),("DRIVING" if driving else "ON FOOT"))

func _shoot():
    if fire_cooldown>0 or ammo<=0: return
    fire_cooldown=0.16
    ammo-=1
    var from=camera.global_position
    var to=from + -camera.global_transform.basis.z*100.0
    var q=PhysicsRayQueryParameters3D.create(from,to)
    q.exclude=[player]
    var hit=get_world_3d().direct_space_state.intersect_ray(q)
    if hit and hit.collider:
        var target=hit.collider
        while target and not enemy_hp.has(target):
            target=target.get_parent()
        if target and enemy_hp.has(target):
            enemy_hp[target]-=1
            if enemy_hp[target]<=0:
                enemies.erase(target)
                enemy_hp.erase(target)
                target.queue_free()
    if ammo==0:
        ammo=30

func _update_enemies(delta):
    for e in enemies.duplicate():
        if not is_instance_valid(e): continue
        var d=e.global_position.distance_to(player.global_position)
        if d>3:
            var dir=(player.global_position-e.global_position).normalized()
            e.velocity.x=dir.x*2.0
            e.velocity.z=dir.z*2.0
            e.look_at(e.global_position+Vector3(dir.x,0,dir.z),Vector3.UP)
            e.move_and_slide()
        else:
            health=max(0,health-int(delta*4.0))
            if health<=0:
                player.global_position=Vector3(0,1,12)
                health=100
