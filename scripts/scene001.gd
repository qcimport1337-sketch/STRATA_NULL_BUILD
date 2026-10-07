extends Node3D

const GRID_X := 260
const GRID_Y := 145
const RELIEF_W := 20.8
const RELIEF_H := 11.6
const START_POS := Vector3(-4.8,0.0,4.2)
const MOVE_SPEED := 3.4
const MOUSE_SENS := 0.0020
const YAW_LIMIT := deg_to_rad(10.0)
const PITCH_LIMIT := deg_to_rad(5.0)

var actor: CharacterBody3D
var model: Node3D
var camera: Camera3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var coat_l: Node3D
var coat_r: Node3D
var yaw := 0.0
var pitch := 0.0
var walk_phase := 0.0
var moving := false
var initialized := false
var dark_mat: StandardMaterial3D
var mid_mat: StandardMaterial3D
var black_mat: StandardMaterial3D

func _ready() -> void:
    _inputs()
    if "--smoke-test" in OS.get_cmdline_user_args():
        print("STRATA_SMOKE_READY")
        get_tree().quit()
        return
    _materials()
    _environment()
    _build_pixel_depth_relief()
    _build_inferred_floor()
    _build_actor()
    _build_camera()
    initialized = true
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _inputs() -> void:
    _bind(&"move_left",[KEY_A,KEY_LEFT])
    _bind(&"move_right",[KEY_D,KEY_RIGHT])
    _bind(&"move_forward",[KEY_W,KEY_UP])
    _bind(&"move_back",[KEY_S,KEY_DOWN])
    _bind(&"recenter",[KEY_Q])

func _bind(action:StringName,keys:Array)->void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if InputMap.action_get_events(action).size()>0:
        return
    for code in keys:
        var ev:=InputEventKey.new()
        ev.physical_keycode=code
        InputMap.add_action(action) if false else null
        InputMap.action_add_event(action,ev)

func _asset_image(name:String)->Image:
    var p:=OS.get_executable_path().get_base_dir().path_join("assets").path_join(name)
    if not FileAccess.file_exists(p):
        p=ProjectSettings.globalize_path("res://assets/"+name)
    var im:=Image.new()
    im.load(p)
    return im

func _materials()->void:
    black_mat=StandardMaterial3D.new()
    black_mat.albedo_color=Color(0.01,0.012,0.014,1)
    black_mat.roughness=0.92
    dark_mat=StandardMaterial3D.new()
    dark_mat.albedo_color=Color(0.035,0.04,0.045,1)
    dark_mat.roughness=0.82
    mid_mat=StandardMaterial3D.new()
    mid_mat.albedo_color=Color(0.12,0.13,0.14,1)
    mid_mat.roughness=0.72

func _environment()->void:
    var wn:=WorldEnvironment.new()
    var e:=Environment.new()
    e.background_mode=Environment.BG_COLOR
    e.background_color=Color(0.08,0.08,0.085,1)
    e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color=Color(0.36,0.37,0.38,1)
    e.ambient_light_energy=0.55
    wn.environment=e
    add_child(wn)
    var l:=DirectionalLight3D.new()
    l.rotation_degrees=Vector3(-35,-25,0)
    l.light_energy=1.1
    l.shadow_enabled=true
    add_child(l)

func _build_pixel_depth_relief()->void:
    var color_im:=_asset_image("scene001_bg_patch.png")
    var depth_im:=_asset_image("scene001_depth.png")
    color_im.convert(Image.FORMAT_RGBA8)
    depth_im.convert(Image.FORMAT_RGBA8)
    var verts:=PackedVector3Array()
    var uvs:=PackedVector2Array()
    var idx:=PackedInt32Array()
    verts.resize(GRID_X*GRID_Y)
    uvs.resize(GRID_X*GRID_Y)
    for gy in range(GRID_Y):
        var v:=float(gy)/float(GRID_Y-1)
        for gx in range(GRID_X):
            var u:=float(gx)/float(GRID_X-1)
            var px:=int(u*float(depth_im.get_width()-1))
            var py:=int(v*float(depth_im.get_height()-1))
            var d:=depth_im.get_pixel(px,py).r
            var x:=(u-0.5)*RELIEF_W
            var y:=(0.5-v)*RELIEF_H + 4.9
            var z:=-11.0 + (d-0.48)*5.2
            verts[gy*GRID_X+gx]=Vector3(x,y,z)
            uvs[gy*GRID_X+gx]=Vector2(u,v)
    for gy in range(GRID_Y-1):
        for gx in range(GRID_X-1):
            var a:=gy*GRID_X+gx
            var b:=a+1
            var c:=a+GRID_X
            var d:=c+1
            idx.append_array(PackedInt32Array([a,c,b,b,c,d]))
    var arrays:=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=verts
    arrays[Mesh.ARRAY_TEX_UV]=uvs
    arrays[Mesh.ARRAY_INDEX]=idx
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    var mi:=MeshInstance3D.new()
    mi.mesh=mesh
    var mat:=StandardMaterial3D.new()
    mat.albedo_texture=ImageTexture.create_from_image(color_im)
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mi.material_override=mat
    add_child(mi)

func _box(pos:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var b:=BoxMesh.new()
    b.size=size
    m.mesh=b
    m.position=pos
    m.material_override=mat
    add_child(m)
    return m

func _build_inferred_floor()->void:
    _box(Vector3(-4.9,-0.09,1.0),Vector3(10.2,0.18,15.0),dark_mat)
    _box(Vector3(5.1,-0.09,-0.6),Vector3(5.2,0.18,12.0),dark_mat)
    _box(Vector3(0.45,-2.1,2.5),Vector3(4.2,4.2,5.8),black_mat)
    _box(Vector3(-1.72,-1.0,2.5),Vector3(0.16,2.0,5.8),mid_mat)
    _box(Vector3(2.62,-1.0,2.5),Vector3(0.16,2.0,5.8),mid_mat)

func _build_actor()->void:
    actor=CharacterBody3D.new()
    actor.position=START_POS
    add_child(actor)
    var cs:=CollisionShape3D.new()
    var cap:=CapsuleShape3D.new()
    cap.radius=0.31
    cap.height=1.7
    cs.shape=cap
    cs.position.y=0.85
    actor.add_child(cs)
    model=Node3D.new()
    actor.add_child(model)
    _build_model()

func _cyl(parent:Node3D,pos:Vector3,r:float,h:float)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var c:=CylinderMesh.new()
    c.top_radius=r
    c.bottom_radius=r
    c.height=h
    c.radial_segments=10
    m.mesh=c
    m.position=pos
    m.material_override=black_mat
    parent.add_child(m)
    return m

func _mbox(parent:Node3D,pos:Vector3,size:Vector3)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var b:=BoxMesh.new()
    b.size=size
    m.mesh=b
    m.position=pos
    m.material_override=black_mat
    parent.add_child(m)
    return m

func _build_model()->void:
    _mbox(model,Vector3(0,1.18,0),Vector3(0.45,0.68,0.25))
    var head:=SphereMesh.new()
    head.radius=0.15
    head.height=0.30
    var hm:=MeshInstance3D.new()
    hm.mesh=head
    hm.position=Vector3(0,1.68,0)
    hm.material_override=black_mat
    model.add_child(hm)
    _mbox(model,Vector3(0,1.42,0.18),Vector3(0.38,0.50,0.16))
    left_leg=Node3D.new()
    left_leg.position=Vector3(-0.13,0.91,0)
    model.add_child(left_leg)
    _cyl(left_leg,Vector3(0,-0.41,0),0.065,0.84)
    right_leg=Node3D.new()
    right_leg.position=Vector3(0.13,0.91,0)
    model.add_child(right_leg)
    _cyl(right_leg,Vector3(0,-0.41,0),0.065,0.84)
    left_arm=Node3D.new()
    left_arm.position=Vector3(-0.29,1.46,0)
    model.add_child(left_arm)
    _cyl(left_arm,Vector3(0,-0.28,0),0.052,0.58)
    right_arm=Node3D.new()
    right_arm.position=Vector3(0.29,1.46,0)
    model.add_child(right_arm)
    _cyl(right_arm,Vector3(0,-0.28,0),0.052,0.58)
    coat_l=Node3D.new()
    coat_l.position=Vector3(-0.11,1.17,0.13)
    model.add_child(coat_l)
    _mbox(coat_l,Vector3(0,-0.44,0),Vector3(0.21,0.88,0.07))
    coat_r=Node3D.new()
    coat_r.position=Vector3(0.11,1.17,0.13)
    model.add_child(coat_r)
    _mbox(coat_r,Vector3(0,-0.44,0),Vector3(0.21,0.88,0.07))

func _build_camera()->void:
    camera=Camera3D.new()
    camera.fov=48.0
    camera.current=true
    add_child(camera)
    _update_camera(true)

func _unhandled_input(event:InputEvent)->void:
    if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
        yaw=clamp(yaw-event.relative.x*MOUSE_SENS,-YAW_LIMIT,YAW_LIMIT)
        pitch=clamp(pitch-event.relative.y*MOUSE_SENS,-PITCH_LIMIT,PITCH_LIMIT)
    elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
        Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseButton and event.pressed:
        Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _physics_process(delta:float)->void:
    if not initialized:
        return
    if Input.is_action_pressed("recenter"):
        yaw=lerp(yaw,0.0,min(1.0,delta*7.0))
        pitch=lerp(pitch,0.0,min(1.0,delta*7.0))
    var iv:=Input.get_vector("move_left","move_right","move_forward","move_back")
    var f:=Vector3(0,0,-1).rotated(Vector3.UP,yaw*0.35)
    var r:=Vector3(1,0,0).rotated(Vector3.UP,yaw*0.35)
    var d:=r*iv.x+f*-iv.y
    moving=d.length_squared()>0.001
    if moving:
        d=d.normalized()
        var cand:=actor.position+d*MOVE_SPEED*delta
        if _walkable(cand):
            actor.position=cand
        model.rotation.y=lerp_angle(model.rotation.y,atan2(d.x,d.z)+PI,min(1.0,delta*10.0))
        walk_phase+=delta*8.0
    else:
        walk_phase+=delta*2.0
    _animate()
    _update_camera(false)

func _walkable(p:Vector3)->bool:
    if p.x < -9.0 or p.x > 8.5 or p.z < -5.5 or p.z > 7.0:
        return false
    if p.x>-1.72 and p.x<2.62 and p.z>0.0 and p.z<5.4:
        return false
    return true

func _animate()->void:
    var amp:=0.62 if moving else 0.03
    var s:=sin(walk_phase)*amp
    left_leg.rotation.x=s
    right_leg.rotation.x=-s
    left_arm.rotation.x=-s*0.6
    right_arm.rotation.x=s*0.6
    coat_l.rotation.x=-0.10+sin(walk_phase+0.7)*(0.12 if moving else 0.02)
    coat_r.rotation.x=-0.12-sin(walk_phase+1.1)*(0.10 if moving else 0.02)

func _update_camera(force:bool)->void:
    var orbit:=Vector3(2.2,2.7,6.3).rotated(Vector3.UP,yaw)
    orbit.y+=pitch*2.2
    var desired:=actor.position+orbit
    var target:=actor.position+Vector3(2.0,1.15,-5.2)
    if force:
        camera.position=desired
    else:
        camera.position=camera.position.lerp(desired,0.12)
    camera.look_at(target,Vector3.UP)
