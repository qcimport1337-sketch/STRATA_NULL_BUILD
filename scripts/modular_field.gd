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
    seed_label.visible=false; message.visible=false
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
    glow_a.energy=0.0; glow_b.energy=0.0
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
    var bw:int=418
    var bh:int=235
    var small:Image=Image.create(bw,bh,false,Image.FORMAT_RGBA8)
    for y in range(bh):
        for x in range(bw):
            var px:float=float(x)*4.0
            var py:float=float(y)*4.0
            var dx1:float=(px-690.0)/520.0
            var dy1:float=(py-430.0)/360.0
            var dx2:float=(px-1160.0)/620.0
            var dy2:float=(py-430.0)/410.0
            var fog1:float=exp(-(dx1*dx1+dy1*dy1)*2.0)
            var fog2:float=exp(-(dx2*dx2+dy2*dy2)*2.4)
            var tone:float=11.0+108.0*fog1+54.0*fog2
            small.set_pixel(x,y,Color(tone/255.0,tone/255.0,tone/255.0,1.0))
    small.resize(W,H,Image.INTERPOLATE_BILINEAR)
    var img:Image=small
    var xs:Array[int]=[95,180,285,395,520,650,790,920,1060,1200,1355,1490,1590]
    for x in xs:
        var y0:int=rng.randi_range(70,240)
        var y1:int=rng.randi_range(650,880)
        var a:float=rng.randf_range(0.10,0.22)
        _line(img,Vector2i(x,y0),Vector2i(x,y1),Color(0.64,0.64,0.66,a))
        if rng.randf()<0.65:_line(img,Vector2i(x+8,y0+20),Vector2i(x+8,y1-20),Color(0.10,0.10,0.12,a*0.75))
    for yy in [210,330,470,560]:
        _line(img,Vector2i(0,yy+rng.randi_range(-16,16)),Vector2i(W,yy+rng.randi_range(-18,18)),Color(0.50,0.50,0.52,0.10))
    img.fill_rect(Rect2i(0,0,72,H),Color(0.01,0.01,0.012,1.0))
    img.fill_rect(Rect2i(W-68,0,68,H),Color(0.01,0.01,0.012,1.0))
    img.fill_rect(Rect2i(0,0,W,34),Color(0.012,0.012,0.014,1.0))
    img.fill_rect(Rect2i(0,H-36,W,36),Color(0.008,0.008,0.01,1.0))
    generated_bg.texture=ImageTexture.create_from_image(img)

func _line(img:Image,a:Vector2i,b:Vector2i,col:Color)->void:
    var dx:int=abs(b.x-a.x);var sx:int=1 if a.x<b.x else -1;var dy:int=-abs(b.y-a.y);var sy:int=1 if a.y<b.y else -1;var err:int=dx+dy;var x:int=a.x;var y:int=a.y
    while true:
        if x>=0 and x<W and y>=0 and y<H:img.set_pixel(x,y,img.get_pixel(x,y).blend(col))
        if x==b.x and y==b.y:break
        var e2:int=2*err
        if e2>=dy:err+=dy;x+=sx
        if e2<=dx:err+=dx;y+=sy

func _abyss()->void:
    _module(play_modules,"balcony_landing.png",Vector2(250,694),0.60,false,630,0.96,0.0)
    _module(play_modules,"straight_catwalk.png",Vector2(820,658),1.08,false,625,1.0,-0.012)
    _module(play_modules,"cantilever_platform.png",Vector2(1375,625),0.60,true,630,0.98,0.0)
    _module(mid_modules,"abyss_column.png",Vector2(465,375),0.72,false,-7,0.70,0.0)
    _module(mid_modules,"elevator_shaft.png",Vector2(1260,350),0.67,true,-6,0.62,0.0)
    _module(mid_modules,"service_riser.png",Vector2(850,430),0.54,false,-5,0.46,0.0)
    _module(mid_modules,"transfer_bridge.png",Vector2(950,455),0.34,true,-4,0.34,0.0)
    walkmesh=PackedVector2Array([Vector2(130,805),Vector2(145,720),Vector2(320,690),Vector2(650,670),Vector2(960,655),Vector2(1280,635),Vector2(1525,648),Vector2(1535,715),Vector2(1280,704),Vector2(960,720),Vector2(640,740),Vector2(300,770),Vector2(130,790)])
    player_pos=Vector2(235,765);top_y=620.0;bottom_y=820.0
    interactions=[{"pos":Vector2(1400,640),"radius":85.0,"prompt":"CONTINUE","message":"The route continues through the megastructure."}]
    glow_a.position=Vector2(470,355);glow_b.position=Vector2(1390,610)

func _maintenance()->void:
    _module(play_modules,"maintenance_spine.png",Vector2(280,690),0.72,false,630,1.0,0.0)
    _module(play_modules,"straight_catwalk.png",Vector2(815,662),0.96,false,625,1.0,-0.008)
    _module(play_modules,"balcony_landing.png",Vector2(1390,635),0.64,true,630,1.0,0.0)
    _module(mid_modules,"service_riser.png",Vector2(470,380),0.69,false,-7,0.66,0.0)
    _module(mid_modules,"elevator_shaft.png",Vector2(1190,355),0.70,false,-6,0.64,0.0)
    _module(mid_modules,"abyss_column.png",Vector2(820,430),0.50,false,-5,0.44,0.0)
    _module(mid_modules,"enclosed_service_bridge.png",Vector2(1030,455),0.34,false,-4,0.34,0.0)
    walkmesh=PackedVector2Array([Vector2(115,815),Vector2(120,720),Vector2(310,690),Vector2(640,672),Vector2(970,660),Vector2(1300,642),Vector2(1530,648),Vector2(1540,720),Vector2(1300,710),Vector2(970,726),Vector2(640,744),Vector2(300,775),Vector2(115,800)])
    player_pos=Vector2(230,780);top_y=625.0;bottom_y=830.0
    interactions=[{"pos":Vector2(1410,645),"radius":85.0,"prompt":"SERVICE ACCESS","message":"A maintenance branch continues deeper."}]
    glow_a.position=Vector2(390,615);glow_b.position=Vector2(1385,620)

func _vertical_loop()->void:
    _module(play_modules,"ramp_connector.png",Vector2(285,705),0.66,false,630,1.0,0.0)
    _module(play_modules,"straight_catwalk.png",Vector2(805,655),0.96,false,625,1.0,-0.008)
    _module(play_modules,"ring_landing.png",Vector2(1370,615),0.64,true,630,1.0,0.0)
    _module(mid_modules,"abyss_column.png",Vector2(730,350),0.82,false,-8,0.72,0.0)
    _module(mid_modules,"elevator_shaft.png",Vector2(1320,330),0.66,false,-7,0.60,0.0)
    _module(mid_modules,"service_riser.png",Vector2(1030,425),0.48,true,-6,0.46,0.0)
    _module(mid_modules,"transfer_bridge.png",Vector2(1000,470),0.32,false,-5,0.32,0.0)
    walkmesh=PackedVector2Array([Vector2(125,835),Vector2(135,748),Vector2(320,705),Vector2(620,677),Vector2(930,655),Vector2(1240,632),Vector2(1500,610),Vector2(1540,625),Vector2(1540,698),Vector2(1260,690),Vector2(940,716),Vector2(620,748),Vector2(310,790),Vector2(125,820)])
    player_pos=Vector2(230,795);top_y=590.0;bottom_y=845.0
    interactions=[{"pos":Vector2(1370,625),"radius":88.0,"prompt":"LIFT NODE","message":"The generated vertical route continues above and below."}]
    glow_a.position=Vector2(730,345);glow_b.position=Vector2(1370,590)

func _far_dressing()->void:
    var xs:Array[int]=[95,220,360,500,650,805,955,1110,1260,1410,1550]
    for i in range(xs.size()):
        _module(far_modules,_pick(VERTICALS),Vector2(xs[i]+rng.randi_range(-24,24),rng.randi_range(245,390)),rng.randf_range(0.36,0.54),rng.randf()>0.55,-80+i,rng.randf_range(0.24,0.38),0.0)
    var ys:Array[int]=[165,245,330,415,500,565]
    for i in range(ys.size()):
        _module(far_modules,_pick(ROUTES),Vector2(rng.randi_range(290,1380),ys[i]+rng.randi_range(-14,14)),rng.randf_range(0.24,0.35),rng.randf()>0.5,-65+i,rng.randf_range(0.19,0.31),rng.randf_range(-0.01,0.01))

func _foreground_dressing()->void:
    if rng.randf()<0.82:_module(foreground_modules,_pick(["service_riser.png","abyss_column.png"]),Vector2(-75,575),1.06,false,2200,0.88,0.0)
    if rng.randf()<0.68:_module(foreground_modules,_pick(["service_riser.png","elevator_shaft.png"]),Vector2(W+78,575),1.02,true,2200,0.84,0.0)
    if rng.randf()<0.55:_module(foreground_modules,_pick(["enclosed_service_bridge.png","maintenance_spine.png"]),Vector2(rng.randi_range(520,1120),95),0.52,rng.randf()>0.5,2150,0.38,rng.randf_range(-0.012,0.012))

func _pick(arr:Array[String])->String:return arr[rng.randi_range(0,arr.size()-1)]

func _module(parent:Node2D,filename:String,pos:Vector2,scale_value:float,flip_x:bool,z:int,opacity:float,rot:float)->void:
    var s:=Sprite2D.new()
    s.texture=_load_texture(filename)
    s.position=pos
    s.scale=Vector2((-scale_value if flip_x else scale_value),scale_value)
    s.rotation=rot
    s.modulate=Color(0.92,0.92,0.94,opacity)
    s.z_index=z
    var mat:=CanvasItemMaterial.new()
    mat.blend_mode=CanvasItemMaterial.BLEND_MODE_MIX
    s.material=mat
    parent.add_child(s)

func _load_texture(filename:String)->Texture2D:
    if texture_cache.has(filename):return texture_cache[filename]
    var path:String=OS.get_executable_path().get_base_dir().path_join("modules").path_join(filename)
    if not FileAccess.file_exists(path):path=ProjectSettings.globalize_path("res://modules").path_join(filename)
    var img:=Image.new();var err:int=img.load(path)
    if err!=OK:img=Image.create(8,8,false,Image.FORMAT_RGBA8);img.fill(Color(1,0,0,0.5))
    var tex:=ImageTexture.create_from_image(img);texture_cache[filename]=tex;return tex

func _move_player(delta:float)->void:
    var v:Vector2=Input.get_vector("move_left","move_right","move_up","move_down")
    if v.length_squared()<0.001:return
    if abs(v.x)>0.05:facing=sign(v.x)
    var d:float=clamp((player_pos.y-top_y)/(bottom_y-top_y),0.0,1.0);var speed:float=lerp(FAR_SPEED,NEAR_SPEED,d);var candidate:Vector2=player_pos+v.normalized()*speed*delta
    if Geometry2D.is_point_in_polygon(candidate,walkmesh):player_pos=candidate
    else:
        var xo:=Vector2(candidate.x,player_pos.y);var yo:=Vector2(player_pos.x,candidate.y)
        if Geometry2D.is_point_in_polygon(xo,walkmesh):player_pos=xo
        elif Geometry2D.is_point_in_polygon(yo,walkmesh):player_pos=yo
    _update_player_visual()

func _update_player_visual()->void:
    player.position=player_pos;var d:float=clamp((player_pos.y-top_y)/(bottom_y-top_y),0.0,1.0);var s:float=lerp(0.40,0.92,d);player.scale=Vector2(s*facing,s);player.z_index=int(player_pos.y)

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
    draw_colored_polygon(walkmesh,Color(1,0.08,0.08,0.08));var closed:=PackedVector2Array(walkmesh);closed.append(walkmesh[0]);draw_polyline(closed,Color(1,0.15,0.15,0.8),2.5,true)
