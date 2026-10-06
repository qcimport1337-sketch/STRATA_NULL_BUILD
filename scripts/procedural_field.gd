extends Node2D

const W := 1672
const H := 941
const NEAR_SPEED := 245.0
const FAR_SPEED := 110.0
const SOURCES: Array[String] = [
    "page-000.webp","page-001.webp","page-003.webp",
    "page-005.webp","page-006.webp","page-007.webp","page-009.webp"
]

var rng := RandomNumberGenerator.new()
var cache: Dictionary = {}
var walkmesh := PackedVector2Array()
var interactions: Array[Dictionary] = []
var player_pos := Vector2(220,790)
var facing := 1.0
var top_y := 600.0
var bottom_y := 830.0
var debug := false
var msg_timer := 0.0
var seed := 0
var grammar := "ABYSS"

@onready var bg: Sprite2D = $Background
@onready var player: Node2D = $Player
@onready var prompt: Label = $UI/Prompt
@onready var message: Label = $UI/Message
@onready var seed_label: Label = $UI/SeedLabel
@onready var debug_label: Label = $UI/Debug
@onready var glow_a: PointLight2D = $FX/GlowA
@onready var glow_b: PointLight2D = $FX/GlowB

func _ready() -> void:
    _bind(&"move_left",[KEY_A,KEY_LEFT]); _bind(&"move_right",[KEY_D,KEY_RIGHT])
    _bind(&"move_up",[KEY_W,KEY_UP]); _bind(&"move_down",[KEY_S,KEY_DOWN])
    _bind(&"interact",[KEY_E,KEY_SPACE]); _bind(&"regen",[KEY_R]); _bind(&"debug_mesh",[KEY_F1])
    if "--smoke-test" in OS.get_cmdline_user_args():
        print("STRATA_SMOKE_READY")
        get_tree().quit()
        return
    _generate()

func _bind(action:StringName, keys:Array) -> void:
    if not InputMap.has_action(action): InputMap.add_action(action)
    if InputMap.action_get_events(action).size() > 0: return
    for keycode in keys:
        var ev := InputEventKey.new(); ev.physical_keycode = keycode
        InputMap.action_add_event(action,ev)

func _process(delta:float) -> void:
    if Input.is_action_just_pressed("regen"): _generate(); return
    if Input.is_action_just_pressed("debug_mesh"):
        debug = not debug; debug_label.visible = debug; queue_redraw()
    _move(delta); _interaction()
    var t: float = float(Time.get_ticks_msec()) / 1000.0
    glow_a.energy = 0.32 + 0.14*sin(t*2.1)
    glow_b.energy = 0.34 + 0.15*sin(t*1.7+1.0)
    if msg_timer > 0.0:
        msg_timer -= delta
        if msg_timer <= 0.0: message.text = "R regenerate   WASD move   E interact   F1 walkmesh"

func _generate() -> void:
    rng.randomize(); seed = int(rng.randi())
    grammar = "ABYSS" if rng.randi_range(0,1)==0 else "CORRIDOR"
    var img: Image = Image.create(W,H,false,Image.FORMAT_RGBA8)
    img.fill(Color(0.95,0.95,0.95,1))
    if grammar == "ABYSS": _compose_abyss(img); _nav_abyss()
    else: _compose_corridor(img); _nav_corridor()
    _fog(img,Rect2i(0,360,W,210),0.075)
    _frame(img); _red_marks(img)
    bg.texture = ImageTexture.create_from_image(img)
    seed_label.text = "Seed %d   Grammar %s" % [seed,grammar]
    prompt.text = ""; message.text = "R regenerate   WASD move   E interact   F1 walkmesh"
    _update_player(); queue_redraw()

func _compose_abyss(img:Image) -> void:
    var a: Image = _src(SOURCES[rng.randi_range(0,SOURCES.size()-1)])
    var b: Image = _src(SOURCES[rng.randi_range(0,SOURCES.size()-1)])
    var c: Image = _src(SOURCES[rng.randi_range(0,SOURCES.size()-1)])
    _strip(img,a,0,540); _strip(img,b,520,620); _strip(img,c,1110,562)
    img.fill_rect(Rect2i(520+rng.randi_range(-15,20),0,86,H),Color(0.055,0.055,0.06,1))
    img.fill_rect(Rect2i(1110+rng.randi_range(-20,20),0,92,H),Color(0.05,0.05,0.055,1))
    _deck(img)

func _compose_corridor(img:Image) -> void:
    var base: Image = _src("page-001.webp" if rng.randi_range(0,1)==0 else "page-006.webp")
    img.blit_rect(base,Rect2i(0,0,W,H),Vector2i.ZERO)
    _strip(img,_src(SOURCES[rng.randi_range(0,SOURCES.size()-1)]),0,320)
    _strip(img,_src(SOURCES[rng.randi_range(0,SOURCES.size()-1)]),1312,360)
    img.fill_rect(Rect2i(270,0,68,H),Color(0.045,0.045,0.05,1))
    img.fill_rect(Rect2i(1320,0,76,H),Color(0.045,0.045,0.05,1))

func _strip(dst:Image, src:Image, dx:int, width:int) -> void:
    var sx: int = rng.randi_range(0,maxi(0,src.get_width()-width))
    dst.blit_rect(src,Rect2i(sx,0,width,H),Vector2i(dx,0))

func _deck(img:Image) -> void:
    for y in range(570,H):
        var t: float = float(y-570)/float(H-570)
        var left: int = int(70.0*t)
        var right: int = int(float(W) - 210.0*(1.0-t))
        img.fill_rect(Rect2i(left,y,maxi(0,right-left),1),Color(0.06,0.065,0.065,1))
    for x in range(40,1020,40):
        var y: int = int(650.0 - 0.11*float(x))
        img.fill_rect(Rect2i(x,y-18,2,26),Color(0.12,0.12,0.13,1))
        img.fill_rect(Rect2i(x,y,40,2),Color(0.78,0.78,0.78,0.22))

func _fog(img:Image, rect:Rect2i, strength:float) -> void:
    for y in range(rect.position.y,rect.end.y):
        var edge: float = abs((float(y-rect.position.y)/float(rect.size.y))-0.5)*2.0
        var a: float = strength*(1.0-edge)
        if a <= 0.0: continue
        for x in range(rect.position.x,rect.end.x):
            img.set_pixel(x,y,img.get_pixel(x,y).lerp(Color(0.97,0.97,0.97,1),a))

func _frame(img:Image) -> void:
    var c: Color = Color(0.025,0.025,0.03,1)
    img.fill_rect(Rect2i(0,0,W,16),c); img.fill_rect(Rect2i(0,H-16,W,16),c)
    img.fill_rect(Rect2i(0,0,12,H),c); img.fill_rect(Rect2i(W-12,0,12,H),c)

func _red_marks(img:Image) -> void:
    for p in [Vector2i(460,405),Vector2i(1320,610),Vector2i(1020,145)]:
        for yy in range(-3,4):
            for xx in range(-3,4):
                if xx*xx+yy*yy <= 9:
                    var x: int = p.x+xx; var y: int = p.y+yy
                    if x>=0 and x<W and y>=0 and y<H:
                        img.set_pixel(x,y,Color(0.95,0.04,0.04,1))

func _src(name:String) -> Image:
    if cache.has(name): return cache[name]
    var base: String = OS.get_executable_path().get_base_dir().path_join("source_fields").path_join(name)
    if not FileAccess.file_exists(base):
        var fallback: Image = Image.create(W,H,false,Image.FORMAT_RGBA8)
        fallback.fill(Color(0.15,0.15,0.16,1)); cache[name]=fallback; return fallback
    var im: Image = Image.new(); im.load(base); im.convert(Image.FORMAT_RGBA8); cache[name]=im; return im

func _nav_abyss() -> void:
    top_y=600.0; bottom_y=840.0
    walkmesh=PackedVector2Array([Vector2(15,815),Vector2(15,665),Vector2(160,620),Vector2(430,640),Vector2(780,650),Vector2(1050,632),Vector2(1650,575),Vector2(1650,930),Vector2(15,930)])
    interactions=[{"pos":Vector2(1470,605),"radius":90.0,"prompt":"ENTER RED DOOR","message":"A red-marked threshold."},{"pos":Vector2(650,655),"radius":85.0,"prompt":"LOOK INTO ABYSS","message":"Structure disappears into fog."}]
    player_pos=Vector2(220,790); glow_a.position=Vector2(460,405); glow_b.position=Vector2(1320,610)

func _nav_corridor() -> void:
    top_y=300.0; bottom_y=830.0
    walkmesh=PackedVector2Array([Vector2(510,820),Vector2(420,760),Vector2(475,430),Vector2(750,290),Vector2(920,290),Vector2(1220,430),Vector2(1260,760),Vector2(1160,820)])
    interactions=[{"pos":Vector2(835,325),"radius":70.0,"prompt":"ADVANCE","message":"The corridor disappears into haze."},{"pos":Vector2(1160,610),"radius":85.0,"prompt":"SIDE ACCESS","message":"A side passage breaks the wall rhythm."}]
    player_pos=Vector2(820,780); glow_a.position=Vector2(430,390); glow_b.position=Vector2(1180,610)

func _move(delta:float) -> void:
    var v: Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")
    if v.length_squared()<0.001:return
    if abs(v.x)>0.05:facing=sign(v.x)
    var d: float = clamp((player_pos.y-top_y)/(bottom_y-top_y),0.0,1.0)
    var speed: float = lerp(FAR_SPEED,NEAR_SPEED,d)
    var candidate: Vector2 = player_pos+v.normalized()*speed*delta
    if Geometry2D.is_point_in_polygon(candidate,walkmesh):player_pos=candidate
    else:
        var xo: Vector2 = Vector2(candidate.x,player_pos.y); var yo: Vector2 = Vector2(player_pos.x,candidate.y)
        if Geometry2D.is_point_in_polygon(xo,walkmesh):player_pos=xo
        elif Geometry2D.is_point_in_polygon(yo,walkmesh):player_pos=yo
    _update_player()

func _update_player() -> void:
    player.position=player_pos
    var d: float = clamp((player_pos.y-top_y)/(bottom_y-top_y),0.0,1.0)
    var s: float = lerp(0.38,1.02,d)
    player.scale=Vector2(s*facing,s); player.z_index=int(player_pos.y)

func _interaction() -> void:
    var near: Dictionary = {}; var best: float = INF
    for item:Dictionary in interactions:
        var dist: float = player_pos.distance_to(item.pos)
        if dist<=float(item.radius) and dist<best: near=item; best=dist
    if near.is_empty():prompt.text="";return
    prompt.text="E  "+str(near.prompt)
    if Input.is_action_just_pressed("interact"):
        message.text=str(near.message);msg_timer=3.0

func _draw() -> void:
    if not debug:return
    draw_colored_polygon(walkmesh,Color(1,0.1,0.1,0.10))
    var closed: PackedVector2Array = PackedVector2Array(walkmesh);closed.append(walkmesh[0])
    draw_polyline(closed,Color(1,0.2,0.2,0.9),2.5,true)
