extends Node2D

const W:int=1672
const H:int=941
const NEAR_SPEED:float=245.0
const FAR_SPEED:float=110.0
const ROUTES:Array[String]=["straight_catwalk.png","split_deck_bridge.png","enclosed_service_bridge.png","maintenance_spine.png","rail_bridge.png","transfer_bridge.png"]
const NODES:Array[String]=["cantilever_platform.png","balcony_landing.png","ring_landing.png"]
const SPECIAL:Array[String]=["broken_span.png","suspended_walkway.png","ramp_connector.png","suspended_platform.png"]
const VERTICALS:Array[String]=["abyss_column.png","elevator_shaft.png","service_riser.png"]

var rng:=RandomNumberGenerator.new()
var texture_cache:Dictionary={}
var walkmesh:=PackedVector2Array()
var interactions:Array[Dictionary]=[]
var player_pos:=Vector2(250,790)
var facing:float=1.0
var top_y:float=560.0
var bottom_y:float=850.0
var show_debug:bool=false
var msg_timer:float=0.0
var seed_value:int=0
var grammar_name:String=""

@onready var generated_bg:Sprite2D=$GeneratedBackground
@onready var far_modules:Node2D=$FarModules
@onready var mid_modules:Node2D=$MidModules
@onready var play_modules:Node2D=$PlayModules
@onready var foreground_modules:Node2D=$ForegroundModules
@onready var player:Node2D=$Player
@onready var seed_label:Label=$UI/SeedLabel
@onready var prompt:Label=$UI/Prompt
@onready var message:Label=$UI/Message
@onready var debug_label:Label=$UI/Debug
@onready var glow_a:PointLight2D=$FX/GlowA
@onready var glow_b:PointLight2D=$FX/GlowB

func _ready()->void:
    _bind(&"move_left",[KEY_A,KEY_LEFT]); _bind(&"move_right",[KEY_D,KEY_RIGHT])
    _bind(&"move_up",[KEY_W,KEY_UP]); _bind(&"move_down",[KEY_S,KEY_DOWN])
    _bind(&"interact",[KEY_E,KEY_SPACE]); _bind(&"regen",[KEY_R]); _bind(&"debug_mesh",[KEY_F1])
    if "--smoke-test" in OS.get_cmdline_user_args():
        print("STRATA_SMOKE_READY"); get_tree().quit(); return
    var audit_seed:int=-1
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--audit-seed="): audit_seed=int(arg.get_slice("=",1))
    _generate_scene(audit_seed)
    if "--audit-shot" in OS.get_cmdline_user_args():
        await get_tree().process_frame; await get_tree().process_frame; await get_tree().process_frame
        var shot:Image=get_viewport().get_texture().get_image()
        shot.save_png(ProjectSettings.globalize_path("res://audit.png"))
        get_tree().quit()

func _bind(action:StringName,keys:Array)->void:
    if not InputMap.has_action(action): InputMap.add_action(action)
    if InputMap.action_get_events(action).size()>0:return
    for code in keys:
        var ev:=InputEventKey.new(); ev.physical_keycode=code; InputMap.action_add_event(action,ev)

func _process(delta:float)->void:
    if Input.is_action_just_pressed("regen"): _generate_scene(); return
    if Input.is_action_just_pressed("debug_mesh"):
        show_debug=not show_debug; debug_label.visible=show_debug; queue_redraw()
    _move_player(delta); _update_interaction()
    var t:float=float(Time.get_ticks_msec())/1000.0
    glow_a.energy=0.26+0.10*sin(t*2.0); glow_b.energy=0.27+0.11*sin(t*1.7+1.0)
    if msg_timer>0.0:
        msg_timer-=delta
        if msg_timer<=0.0:message.text="R regenerate   WASD move   E interact   F1 walkmesh"

func _generate_scene(fixed_seed:int=-1)->void:
    if fixed_seed>=0: seed_value=fixed_seed; rng.seed=seed_value
    else: rng.randomize(); seed_value=int(rng.randi())
    _clear_modules(far_modules);_clear_modules(mid_modules);_clear_modules(play_modules);_clear_modules(foreground_modules)
    _make_background()
    var choice:int=rng.randi_range(0,2)
    if choice==0: grammar_name="ABYSS CROSSING"; _abyss()
    elif choice==1: grammar_name="MAINTENANCE SPINE"; _maintenance()
    else: grammar_name="VERTICAL LOOP"; _vertical_loop()
    _far_dressing(); _foreground_dressing()
    seed_label.text="Seed %d   %s"%[seed_value,grammar_name]
    print("STRATA_GRAMMAR ",grammar_name," seed=",seed_value)
    prompt.text="";message.text="R regenerate   WASD move   E interact   F1 walkmesh";_update_player_visual();queue_redraw()

func _clear_modules(parent:Node2D)->void:
    for child in parent.get_children():child.queue_free()

func _make_background()->void:
    var img:Image=Image.create(W,H,false,Image.FORMAT_RGBA8)
    for y in range(H):
        for x in range(W):
            var dx:float=(float(x)-860.0)/760.0
            var dy:float=(float(y)-430.0)/390.0
            var fog:float=exp(-(dx*dx+dy*dy)*1.35)
            var depth:float=1.0-float(y)/float(H-1)
            var tone:float=18.0 + 160.0*fog + 18.0*depth
            img.set_pixel(x,y,Color(tone/255.0,tone/255.0,tone/255.0,1.0))
    img.fill_rect(Rect2i(0,0,34,H),Color(0.015,0.015,0.018,1.0))
    img.fill_rect(Rect2i(W-34,0,34,H),Color(0.015,0.015,0.018,1.0))
    img.fill_rect(Rect2i(0,H-22,W,22),Color(0.015,0.015,0.018,1.0))
    generated_bg.texture=ImageTexture.create_from_image(img)

func _abyss()->void:
    _module(play_modules,_pick(NODES),Vector2(250,675),0.72,false,620,0.96,0.0)
    _module(play_modules,"straight_catwalk.png",Vector2(700,640),0.88,false,625,1.0,rng.randf_range(-0.018,0.018))
    _module(play_modules,_pick(NODES),Vector2(1120,615),0.72,true,630,0.98,0.0)
    _module(mid_modules,_pick(VERTICALS),Vector2(565,360),0.78,false,-7,0.72,0.0)
    _module(mid_modules,_pick(VERTICALS),Vector2(1215,345),0.73,true,-6,0.68,0.0)
    _module(mid_modules,_pick(ROUTES),Vector2(1010,435),0.48,true,-5,0.48,0.0)
    walkmesh=PackedVector2Array([Vector2(90,840),Vector2(95,710),Vector2(315,670),Vector2(650,650),Vector2(975,642),Vector2(1280,620),Vector2(1580,635),Vector2(1600,910),Vector2(90,910)])
    player_pos=Vector2(230,805);top_y=610.0;bottom_y=860.0
    interactions=[{"pos":Vector2(1390,630),"radius":90.0,"prompt":"CONTINUE","message":"The structure continues beyond the fog."}]
    glow_a.position=Vector2(560,350);glow_b.position=Vector2(1360,600)

func _maintenance()->void:
    _module(play_modules,"maintenance_spine.png",Vector2(350,685),0.82,false,620,1.0,0.0)
    _module(play_modules,_pick(["straight_catwalk.png","enclosed_service_bridge.png","transfer_bridge.png"]),Vector2(780,645),0.73,false,625,1.0,0.0)
    _module(play_modules,"balcony_landing.png",Vector2(1220,610),0.73,true,630,1.0,0.0)
    _module(mid_modules,"elevator_shaft.png",Vector2(1120,350),0.72,false,-8,0.70,0.0)
    _module(mid_modules,_pick(["service_riser.png","abyss_column.png"]),Vector2(520,365),0.65,true,-7,0.62,0.0)
    _module(mid_modules,_pick(ROUTES),Vector2(1280,455),0.44,true,-5,0.44,0.0)
    walkmesh=PackedVector2Array([Vector2(70,850),Vector2(70,710),Vector2(300,680),Vector2(610,660),Vector2(920,645),Vector2(1220,620),Vector2(1550,610),Vector2(1600,920),Vector2(70,920)])
    player_pos=Vector2(235,810);top_y=600.0;bottom_y=865.0
    interactions=[{"pos":Vector2(1410,615),"radius":90.0,"prompt":"SERVICE ACCESS","message":"A maintenance branch continues."}]
    glow_a.position=Vector2(380,625);glow_b.position=Vector2(1390,590)

func _vertical_loop()->void:
    _module(play_modules,"ramp_connector.png",Vector2(310,700),0.78,false,620,1.0,0.0)
    _module(play_modules,_pick(["ring_landing.png","cantilever_platform.png"]),Vector2(660,630),0.72,false,625,1.0,0.0)
    _module(play_modules,_pick(["suspended_walkway.png","straight_catwalk.png"]),Vector2(1120,585),0.66,true,630,1.0,0.0)
    _module(mid_modules,"abyss_column.png",Vector2(770,335),0.88,false,-8,0.72,0.0)
    _module(mid_modules,"elevator_shaft.png",Vector2(1310,320),0.61,false,-7,0.60,0.0)
    _module(mid_modules,_pick(ROUTES),Vector2(1060,430),0.42,true,-5,0.45,0.0)
    walkmesh=PackedVector2Array([Vector2(90,860),Vector2(95,745),Vector2(340,700),Vector2(615,655),Vector2(875,630),Vector2(1140,605),Vector2(1480,585),Vector2(1590,640),Vector2(1590,920),Vector2(90,920)])
    player_pos=Vector2(230,820);top_y=575.0;bottom_y=875.0
    interactions=[{"pos":Vector2(865,630),"radius":90.0,"prompt":"LIFT NODE","message":"This landing connects another vertical level."}]
    glow_a.position=Vector2(780,340);glow_b.position=Vector2(1340,570)

func _far_dressing()->void:
    var anchor_x:Array[int]=[300,830,1390]
    for i in range(anchor_x.size()):
        _module(far_modules,_pick(VERTICALS),Vector2(anchor_x[i]+rng.randi_range(-35,35),rng.randi_range(300,390)),rng.randf_range(0.46,0.62),rng.randf()>0.55,-55+i,rng.randf_range(0.22,0.34),0.0)
    var bridge_y:Array[int]=[300,410,505]
    for i in range(bridge_y.size()):
        _module(far_modules,_pick(ROUTES),Vector2(rng.randi_range(420,1260),bridge_y[i]+rng.randi_range(-20,20)),rng.randf_range(0.30,0.40),rng.randf()>0.5,-48+i,rng.randf_range(0.18,0.28),rng.randf_range(-0.018,0.018))

func _foreground_dressing()->void:
    if rng.randf()<0.50:_module(foreground_modules,_pick(["service_riser.png","abyss_column.png"]),Vector2(-110,610),1.05,false,2200,0.70,0.0)
    if rng.randf()<0.35:_module(foreground_modules,_pick(["service_riser.png","elevator_shaft.png"]),Vector2(W+110,600),1.0,true,2200,0.65,0.0)

func _pick(arr:Array[String])->String:return arr[rng.randi_range(0,arr.size()-1)]

func _module(parent:Node2D,filename:String,pos:Vector2,scale_value:float,flip_x:bool,z:int,opacity:float,rot:float)->void:
    var s:=Sprite2D.new()
    s.texture=_load_texture(filename)
    s.position=pos
    s.scale=Vector2((-scale_value if flip_x else scale_value),scale_value)
    s.rotation=rot
    s.modulate=Color(1,1,1,opacity)
    s.z_index=z
    var mat:=CanvasItemMaterial.new()
    mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
    s.material=mat
    parent.add_child(s)

func _load_texture(filename:String)->Texture2D:
    if texture_cache.has(filename):return texture_cache[filename]
    var path:String=OS.get_executable_path().get_base_dir().path_join("modules").path_join(filename)
    var img:=Image.new();var err:int=img.load(path)
    if err!=OK:img=Image.create(8,8,false,Image.FORMAT_RGBA8);img.fill(Color(1,0,0,0.5))
    var tex:=ImageTexture.create_from_image(img);texture_cache[filename]=tex;return tex

func _move_player(delta:float)->void:
    var v:Vector2=Input.get_vector("move_left","move_right","move_up","move_down")
    if v.length_squared()<0.001:return
    if abs(v.x)>0.05:facing=sign(v.x)
    var d:float=clamp((player_pos.y-top_y)/(bottom_y-top_y),0.0,1.0)
    var speed:float=lerp(FAR_SPEED,NEAR_SPEED,d)
    var candidate:Vector2=player_pos+v.normalized()*speed*delta
    if Geometry2D.is_point_in_polygon(candidate,walkmesh):player_pos=candidate
    else:
        var xo:=Vector2(candidate.x,player_pos.y);var yo:=Vector2(player_pos.x,candidate.y)
        if Geometry2D.is_point_in_polygon(xo,walkmesh):player_pos=xo
        elif Geometry2D.is_point_in_polygon(yo,walkmesh):player_pos=yo
    _update_player_visual()

func _update_player_visual()->void:
    player.position=player_pos
    var d:float=clamp((player_pos.y-top_y)/(bottom_y-top_y),0.0,1.0)
    var s:float=lerp(0.38,1.0,d)
    player.scale=Vector2(s*facing,s);player.z_index=int(player_pos.y)

func _update_interaction()->void:
    var near:Dictionary={};var best:float=INF
    for item:Dictionary in interactions:
        var dist:float=player_pos.distance_to(item.pos)
        if dist<=float(item.radius) and dist<best:near=item;best=dist
    if near.is_empty():prompt.text="";return
    prompt.text="E  "+str(near.prompt)
    if Input.is_action_just_pressed("interact"):message.text=str(near.message);msg_timer=3.0

func _draw()->void:
    if not show_debug:return
    draw_colored_polygon(walkmesh,Color(1,0.08,0.08,0.08))
    var closed:=PackedVector2Array(walkmesh);closed.append(walkmesh[0])
    draw_polyline(closed,Color(1,0.15,0.15,0.8),2.5,true)
