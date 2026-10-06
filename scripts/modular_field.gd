extends Node2D

const W:int=1672
const H:int=941
const NEAR_SPEED:float=235.0
const FAR_SPEED:float=105.0
const ROUTES:Array[String]=["straight_catwalk.png","split_deck_bridge.png","enclosed_service_bridge.png","maintenance_spine.png","rail_bridge.png","transfer_bridge.png"]
const NODES:Array[String]=["cantilever_platform.png","balcony_landing.png","ring_landing.png"]
const VERTICALS:Array[String]=["abyss_column.png","elevator_shaft.png","service_riser.png"]

var rng:=RandomNumberGenerator.new()
var texture_cache:Dictionary={}
var beacon_texture:Texture2D
var walkmesh:=PackedVector2Array()
var interactions:Array[Dictionary]=[]
var player_pos:=Vector2(245,785)
var facing:float=1.0
var top_y:float=560.0
var bottom_y:float=840.0
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
    seed_label.visible=false; message.visible=false
    glow_a.energy=0.0; glow_b.energy=0.0
    beacon_texture=_make_beacon_texture()
    if "--smoke-test" in OS.get_cmdline_user_args():
        print("STRATA_SMOKE_READY"); get_tree().quit(); return
    var audit_seed:int=-1
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--audit-seed="): audit_seed=int(arg.get_slice("=",1))
    _generate_scene(audit_seed)
    if "--audit-shot" in OS.get_cmdline_user_args():
        await get_tree().process_frame; await get_tree().process_frame; await get_tree().process_frame
        var shot:Image=get_viewport().get_texture().get_image(); shot.save_png(ProjectSettings.globalize_path("res://audit.png")); get_tree().quit()

func _bind(action:StringName,keys:Array)->void:
    if not InputMap.has_action(action):InputMap.add_action(action)
    if InputMap.action_get_events(action).size()>0:return
    for code in keys:
        var ev:=InputEventKey.new();ev.physical_keycode=code;InputMap.action_add_event(action,ev)

func _process(delta:float)->void:
    if Input.is_action_just_pressed("regen"):_generate_scene();return
    if Input.is_action_just_pressed("debug_mesh"):
        show_debug=not show_debug;debug_label.visible=show_debug;queue_redraw()
    _move_player(delta);_update_interaction()
    if msg_timer>0.0:
        msg_timer-=delta
        if msg_timer<=0.0:message.text=""

func _generate_scene(fixed_seed:int=-1)->void:
    if fixed_seed>=0:seed_value=fixed_seed;rng.seed=seed_value
    else:rng.randomize();seed_value=int(rng.randi())
    _clear_modules(far_modules);_clear_modules(mid_modules);_clear_modules(play_modules);_clear_modules(foreground_modules)
    _make_background()
    var choice:int=rng.randi_range(0,2)
    if choice==0:grammar_name="ABYSS CROSSING";_abyss()
    elif choice==1:grammar_name="MAINTENANCE SPINE";_maintenance()
    else:grammar_name="VERTICAL LOOP";_vertical_loop()
    _far_dressing();_foreground_dressing();_semantic_red()
    prompt.text="";_update_player_visual();queue_redraw()

func _clear_modules(parent:Node2D)->void:
    for child in parent.get_children():child.queue_free()

func _make_background()->void:
    var bw:int=418;var bh:int=235
    var small:=Image.create(bw,bh,false,Image.FORMAT_RGBA8)
    var cx:float=rng.randf_range(760.0,980.0);var cy:float=rng.randf_range(390.0,500.0)
    for y in range(bh):
        for x in range(bw):
            var px:float=float(x)*4.0;var py:float=float(y)*4.0
            var dx:float=(px-cx)/690.0;var dy:float=(py-cy)/430.0
            var fog:float=exp(-(dx*dx+dy*dy)*1.55)
            var tone:float=24.0+126.0*fog
            small.set_pixel(x,y,Color(tone/255.0,tone/255.0,tone/255.0,1.0))
    small.resize(W,H,Image.INTERPOLATE_BILINEAR)
    var img:Image=small
    var x:int=rng.randi_range(65,100)
    while x<W-50:
        var y0:int=rng.randi_range(70,230);var y1:int=rng.randi_range(650,900)
        var span:int=rng.randi_range(18,44);var a:float=rng.randf_range(0.10,0.20)
        _line(img,Vector2i(x,y0),Vector2i(x,y1),Color(0.10,0.10,0.12,a))
        _line(img,Vector2i(x+span,y0+10),Vector2i(x+span,y1-15),Color(0.10,0.10,0.12,a))
        var yy:int=y0+rng.randi_range(30,60)
        while yy<y1-20:
            _line(img,Vector2i(x,yy),Vector2i(x+span,yy+rng.randi_range(-4,4)),Color(0.28,0.28,0.30,a*0.65))
            yy+=rng.randi_range(55,100)
        x+=rng.randi_range(70,125)
    for i in range(rng.randi_range(7,10)):
        var yb:int=rng.randi_range(150,600);var slope:int=rng.randi_range(-55,55);var a:float=rng.randf_range(0.08,0.16)
        _line(img,Vector2i(0,yb),Vector2i(W,yb+slope),Color(0.18,0.18,0.20,a))
        _line(img,Vector2i(0,yb+10),Vector2i(W,yb+slope+10),Color(0.52,0.52,0.54,a*0.55))
        var xx:int=rng.randi_range(0,90)
        while xx<W:
            var yy:int=int(lerp(float(yb),float(yb+slope),float(xx)/float(W)))
            _line(img,Vector2i(xx,yy),Vector2i(xx+32,yy+10),Color(0.16,0.16,0.18,a*0.9))
            xx+=rng.randi_range(75,120)
    for i in range(rng.randi_range(16,26)):
        var xx:int=rng.randi_range(50,W-50);var y0:int=rng.randi_range(20,400);var y1:int=rng.randi_range(y0+70,900)
        _line(img,Vector2i(xx,y0),Vector2i(xx+rng.randi_range(-8,8),y1),Color(0.08,0.08,0.10,rng.randf_range(0.05,0.10)))
    img.fill_rect(Rect2i(0,0,rng.randi_range(38,70),H),Color(0.008,0.008,0.010,1.0))
    img.fill_rect(Rect2i(W-rng.randi_range(38,70),0,70,H),Color(0.008,0.008,0.010,0.97))
    img.fill_rect(Rect2i(0,0,W,rng.randi_range(20,36)),Color(0.008,0.008,0.010,1.0))
    img.fill_rect(Rect2i(0,H-rng.randi_range(20,34),W,34),Color(0.006,0.006,0.008,1.0))
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
    var y:float=rng.randf_range(655.0,690.0)
    _module(play_modules,"balcony_landing.png",Vector2(360,y+10),0.66,false,630,0.98,0.0)
    _module(play_modules,"straight_catwalk.png",Vector2(805,y),rng.randf_range(1.08,1.16),false,625,1.0,rng.randf_range(-0.018,0.006))
    _module(play_modules,"cantilever_platform.png",Vector2(1265,y-14),0.68,true,630,0.98,0.0)
    _module(mid_modules,"abyss_column.png",Vector2(460,370),0.70,false,-7,0.62,0.0)
    _module(mid_modules,"elevator_shaft.png",Vector2(1260,350),0.63,true,-6,0.56,0.0)
    _module(mid_modules,_pick(ROUTES),Vector2(930,450),0.32,true,-5,0.28,rng.randf_range(-0.015,0.015))
    walkmesh=PackedVector2Array([Vector2(125,815),Vector2(140,720),Vector2(315,690),Vector2(645,675),Vector2(965,660),Vector2(1280,640),Vector2(1530,650),Vector2(1540,715),Vector2(1280,705),Vector2(965,720),Vector2(640,742),Vector2(305,772),Vector2(125,800)])
    player_pos=Vector2(225,770);top_y=620.0;bottom_y=830.0
    interactions=[{"pos":Vector2(1400,645),"radius":85.0,"prompt":"CONTINUE","message":"The route continues through the megastructure."}]

func _maintenance()->void:
    var y:float=rng.randf_range(650.0,680.0)
    _module(play_modules,"maintenance_spine.png",Vector2(390,y+12),0.94,false,630,1.0,0.0)
    _module(play_modules,"rail_bridge.png",Vector2(850,y-2),0.98,false,625,1.0,rng.randf_range(-0.008,0.008))
    _module(play_modules,"balcony_landing.png",Vector2(1285,y-16),0.70,true,630,1.0,0.0)
    _module(mid_modules,"service_riser.png",Vector2(460,380),0.66,false,-7,0.58,0.0)
    _module(mid_modules,"elevator_shaft.png",Vector2(1180,355),0.68,false,-6,0.58,0.0)
    _module(mid_modules,"enclosed_service_bridge.png",Vector2(1010,455),0.31,false,-5,0.28,0.0)
    walkmesh=PackedVector2Array([Vector2(115,815),Vector2(125,720),Vector2(310,690),Vector2(640,675),Vector2(970,660),Vector2(1300,640),Vector2(1530,648),Vector2(1540,720),Vector2(1300,710),Vector2(970,726),Vector2(640,744),Vector2(300,775),Vector2(115,800)])
    player_pos=Vector2(225,780);top_y=620.0;bottom_y=835.0
    interactions=[{"pos":Vector2(1410,645),"radius":85.0,"prompt":"SERVICE ACCESS","message":"A maintenance branch continues deeper."}]

func _vertical_loop()->void:
    var y:float=rng.randf_range(640.0,675.0)
    _module(play_modules,"ramp_connector.png",Vector2(405,y+24),0.86,false,630,1.0,0.0)
    _module(play_modules,"suspended_walkway.png",Vector2(860,y-4),0.96,false,625,1.0,rng.randf_range(-0.012,0.006))
    _module(play_modules,"ring_landing.png",Vector2(1300,y-24),0.72,true,630,1.0,0.0)
    _module(mid_modules,"abyss_column.png",Vector2(720,350),0.78,false,-8,0.64,0.0)
    _module(mid_modules,"elevator_shaft.png",Vector2(1320,330),0.63,false,-7,0.54,0.0)
    _module(mid_modules,"transfer_bridge.png",Vector2(1010,465),0.30,false,-5,0.26,0.0)
    walkmesh=PackedVector2Array([Vector2(125,835),Vector2(135,748),Vector2(320,705),Vector2(620,677),Vector2(930,655),Vector2(1240,632),Vector2(1500,610),Vector2(1540,625),Vector2(1540,698),Vector2(1260,690),Vector2(940,716),Vector2(620,748),Vector2(310,790),Vector2(125,820)])
    player_pos=Vector2(225,795);top_y=590.0;bottom_y=845.0
    interactions=[{"pos":Vector2(1370,625),"radius":88.0,"prompt":"LIFT NODE","message":"The generated vertical route continues above and below."}]

func _far_dressing()->void:
    var xs:Array[int]=[110,255,405,560,720,875,1030,1190,1350,1500]
    for i in range(xs.size()):
        _module(far_modules,_pick(VERTICALS),Vector2(xs[i]+rng.randi_range(-22,22),rng.randi_range(250,405)),rng.randf_range(0.34,0.52),rng.randf()>0.55,-80+i,rng.randf_range(0.27,0.41),0.0)
    var ys:Array[int]=[150,225,300,375,455,535]
    for i in range(ys.size()):
        _module(far_modules,_pick(ROUTES),Vector2(rng.randi_range(300,1380),ys[i]+rng.randi_range(-14,14)),rng.randf_range(0.27,0.41),rng.randf()>0.5,-65+i,rng.randf_range(0.20,0.31),rng.randf_range(-0.012,0.012))
    for i in range(3):
        _module(far_modules,_pick(NODES),Vector2(rng.randi_range(260,1420),rng.randi_range(330,560)),rng.randf_range(0.28,0.42),rng.randf()>0.5,-54+i,rng.randf_range(0.16,0.25),0.0)

func _foreground_dressing()->void:
    if rng.randf()<0.78:_module(foreground_modules,_pick(["service_riser.png","abyss_column.png"]),Vector2(-60,580),1.03,false,2200,0.90,0.0)
    if rng.randf()<0.66:_module(foreground_modules,_pick(["service_riser.png","elevator_shaft.png"]),Vector2(W+65,575),0.98,true,2200,0.86,0.0)

func _semantic_red()->void:
    var pts:Array[Vector2]=[]
    if grammar_name=="ABYSS CROSSING":pts=[Vector2(315,635),Vector2(1365,600),Vector2(950,430)]
    elif grammar_name=="MAINTENANCE SPINE":pts=[Vector2(285,625),Vector2(1390,600),Vector2(1170,350)]
    else:pts=[Vector2(330,650),Vector2(1360,575),Vector2(720,340)]
    for p in pts:_beacon(p,rng.randf_range(0.65,0.95),1800)

func _make_beacon_texture()->Texture2D:
    var im:=Image.create(48,48,false,Image.FORMAT_RGBA8)
    for y in range(48):
        for x in range(48):
            var dx:float=float(x-24);var dy:float=float(y-24);var d:float=sqrt(dx*dx+dy*dy)
            var a:float=clamp(1.0-d/23.0,0.0,1.0)
            var core:float=clamp(1.0-d/7.0,0.0,1.0)
            im.set_pixel(x,y,Color(1.0,0.03+0.42*core,0.03,a*a*0.42+core*0.58))
    return ImageTexture.create_from_image(im)

func _beacon(pos:Vector2,sc:float,z:int)->void:
    var s:=Sprite2D.new();s.texture=beacon_texture;s.position=pos;s.scale=Vector2(sc,sc);s.z_index=z;foreground_modules.add_child(s)

func _pick(arr:Array[String])->String:return arr[rng.randi_range(0,arr.size()-1)]

func _module(parent:Node2D,filename:String,pos:Vector2,scale_value:float,flip_x:bool,z:int,opacity:float,rot:float)->void:
    var s:=Sprite2D.new();s.texture=_load_texture(filename);s.position=pos;s.scale=Vector2((-scale_value if flip_x else scale_value),scale_value);s.rotation=rot;s.modulate=Color(0.93,0.93,0.95,opacity);s.z_index=z
    var mat:=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_MIX;s.material=mat;parent.add_child(s)

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
    player.position=player_pos;var d:float=clamp((player_pos.y-top_y)/(bottom_y-top_y),0.0,1.0);var s:float=lerp(0.39,0.90,d);player.scale=Vector2(s*facing,s);player.z_index=int(player_pos.y)

func _update_interaction()->void:
    var near:Dictionary={};var best:float=INF
    for item:Dictionary in interactions:
        var dist:float=player_pos.distance_to(item.pos)
        if dist<=float(item.radius) and dist<best:near=item;best=dist
    if near.is_empty():prompt.text="";return
    prompt.text="E  "+str(near.prompt)
    if Input.is_action_just_pressed("interact"):message.visible=true;message.text=str(near.message);msg_timer=3.0

func _draw()->void:
    if not show_debug:return
    draw_colored_polygon(walkmesh,Color(1,0.08,0.08,0.08));var closed:=PackedVector2Array(walkmesh);closed.append(walkmesh[0]);draw_polyline(closed,Color(1,0.15,0.15,0.8),2.5,true)
