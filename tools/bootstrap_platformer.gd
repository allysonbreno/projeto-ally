@tool
extends EditorScript

# ======== CONFIG GIT OPCIONAL ========
const REMOTE_URL: String = ""  # ex: "git@github.com:seuuser/seu-repo.git" ou "https://github.com/seuuser/seu-repo.git"
const DEFAULT_BRANCH: String = "main"
const CREATE_RELEASE_TAG: String = "v0.1.0"

# ======== BOOT ========
func _run() -> void:
    print("[bootstrap] Iniciando…")

    _ensure_dirs(["res://scenes", "res://scripts", "res://assets", "res://tools"])

    _setup_input()
    ProjectSettings.set_setting("application/config/name", "Platformer2D by Code")
    ProjectSettings.save()

    # Cria scripts de runtime
    var player_script_path := "res://scripts/Player.gd"
    var enemy_script_path  := "res://scripts/Enemy.gd"
    _write_script(player_script_path, _player_script_source())
    _write_script(enemy_script_path,  _enemy_script_source())

    # Cria e salva cenas
    var player_scene_path := "res://scenes/Player.tscn"
    var enemy_scene_path  := "res://scenes/Enemy.tscn"
    _create_and_save_player_scene(player_scene_path, player_script_path)
    _create_and_save_enemy_scene(enemy_scene_path, enemy_script_path)

    var main_scene_path := "res://scenes/Main.tscn"
    _create_and_save_main_scene(main_scene_path, player_scene_path, enemy_scene_path)

    # Define cena principal
    ProjectSettings.set_setting("application/run/main_scene", main_scene_path)
    ProjectSettings.save()

    # Git
    _ensure_gitignore()
    _git_init_and_first_commit()
    if CREATE_RELEASE_TAG != "":
        _git_tag(CREATE_RELEASE_TAG)

    if REMOTE_URL != "":
        _git_set_remote_and_push(REMOTE_URL, DEFAULT_BRANCH)

    print("[bootstrap] Concluído. Abra e rode a cena principal. :)")

# ======== UTIL FS ========
func _ensure_dirs(paths: Array[String]) -> void:
    for p in paths:
        if not DirAccess.dir_exists_absolute(p):
            var ok := DirAccess.make_dir_recursive_absolute(p)
            if ok != OK:
                push_error("Falha ao criar dir: %s" % p)

func _write_text(path: String, text: String) -> void:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f:
        f.store_string(text)
        f.close()
    else:
        push_error("Não conseguiu escrever em %s" % path)

func _write_script(path: String, src: String) -> void:
    _write_text(path, src)

# ======== INPUT MAP (corrigido) ========
func _setup_input() -> void:
    _ensure_action("move_left",  [ _key(Key.KEY_A), _key(Key.KEY_LEFT) ])
    _ensure_action("move_right", [ _key(Key.KEY_D), _key(Key.KEY_RIGHT) ])
    _ensure_action("jump",       [ _key(Key.KEY_SPACE), _key(Key.KEY_W) ])
    ProjectSettings.save()

func _ensure_action(name: String, events: Array[InputEvent]) -> void:
    if not InputMap.has_action(name):
        InputMap.add_action(name)
    for ev in events:
        InputMap.action_add_event(name, ev)

func _key(k: Key) -> InputEventKey:
    var ev := InputEventKey.new()
    ev.physical_keycode = k  # usa o enum Key.KEY_*
    return ev

# ======== TEXTURAS COLORIDAS ========
func _make_color_texture(size: Vector2i, color: Color) -> Texture2D:
    var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    img.fill(color)
    return ImageTexture.create_from_image(img)

# ======== PLAYER SCENE ========
func _create_and_save_player_scene(scene_path: String, script_path: String) -> void:
    var root := CharacterBody2D.new()
    root.name = "Player"
    root.position = Vector2(100, 300)
    root.collision_layer = 1
    root.collision_mask  = 1  # chão (layer 1)

    # Visual
    var sprite := Sprite2D.new()
    sprite.name = "Sprite2D"
    sprite.texture = _make_color_texture(Vector2i(24, 32), Color(0.2, 0.8, 0.2, 1))
    sprite.centered = true
    root.add_child(sprite)

    # Colisão
    var col := CollisionShape2D.new()
    col.name = "CollisionShape2D"
    var rect := RectangleShape2D.new()
    rect.size = Vector2(20, 30)
    col.shape = rect
    root.add_child(col)

    # Câmera
    var cam := Camera2D.new()
    cam.name = "Camera2D"
    cam.current = true
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 8.0
    root.add_child(cam)

    # Hurtbox (para detectar hitbox do inimigo)
    var hurt := Area2D.new()
    hurt.name = "Hurtbox"
    # layer 3; máscara 2 (vai "ver" a hitbox do inimigo que está na layer 2)
    hurt.collision_layer = 1 << 2
    hurt.collision_mask  = 1 << 1
    var hcol := CollisionShape2D.new()
    var hrect := RectangleShape2D.new()
    hrect.size = Vector2(20, 30)
    hcol.shape = hrect
    hurt.add_child(hcol)
    root.add_child(hurt)

    # Script
    root.set_script(load(script_path))

    # Conecta sinal ao método do Player
    hurt.area_entered.connect(Callable(root, "_on_Hurtbox_area_entered"))

    # Salvar
    var ps := PackedScene.new()
    var ok := ps.pack(root)
    if ok != OK:
        push_error("Falha ao pack Player")
    ResourceSaver.save(ps, scene_path)

# ======== ENEMY SCENE ========
func _create_and_save_enemy_scene(scene_path: String, script_path: String) -> void:
    var root := CharacterBody2D.new()
    root.name = "Enemy"
    root.position = Vector2(600, 300)
    root.collision_layer = 1
    root.collision_mask  = 1

    var sprite := Sprite2D.new()
    sprite.name = "Sprite2D"
    sprite.texture = _make_color_texture(Vector2i(24, 24), Color(0.85, 0.2, 0.2, 1))
    root.add_child(sprite)

    var col := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(20, 20)
    col.shape = rect
    root.add_child(col)

    # Pontos de patrulha
    var left := Marker2D.new()
    left.name = "LeftPoint"
    left.position = Vector2(-100, 0)
    root.add_child(left)

    var right := Marker2D.new()
    right.name = "RightPoint"
    right.position = Vector2(100, 0)
    root.add_child(right)

    # Hitbox (area que machuca o Player)
    var hit := Area2D.new()
    hit.name = "Hitbox"
    hit.collision_layer = 1 << 1   # layer 2
    hit.collision_mask  = 1 << 2   # enxerga hurtbox do player (layer 3)
    var hcol := CollisionShape2D.new()
    var hrect := RectangleShape2D.new()
    hrect.size = Vector2(20, 20)
    hcol.shape = hrect
    hit.add_child(hcol)
    root.add_child(hit)

    # Script
    root.set_script(load(script_path))

    # Salvar
    var ps := PackedScene.new()
    var ok := ps.pack(root)
    if ok != OK:
        push_error("Falha ao pack Enemy")
    ResourceSaver.save(ps, scene_path)

# ======== MAIN SCENE ========
func _create_and_save_main_scene(scene_path: String, player_scene_path: String, enemy_scene_path: String) -> void:
    var root := Node2D.new()
    root.name = "Main"

    # Chão (StaticBody2D)
    var ground := StaticBody2D.new()
    ground.name = "Ground"
    ground.position = Vector2(512, 400)
    ground.collision_layer = 1
    ground.collision_mask  = 0
    var gcol := CollisionShape2D.new()
    var grect := RectangleShape2D.new()
    grect.size = Vector2(1024, 40)
    gcol.shape = grect
    ground.add_child(gcol)

    var gsprite := Sprite2D.new()
    gsprite.texture = _make_color_texture(Vector2i(1024, 40), Color(0.4, 0.4, 0.4, 1))
    gsprite.centered = true
    ground.add_child(gsprite)

    root.add_child(ground)

    # Instancia Player e Enemy
    var player_scene := load(player_scene_path) as PackedScene
    var enemy_scene  := load(enemy_scene_path) as PackedScene

    var player := player_scene.instantiate() as CharacterBody2D
    player.position = Vector2(100, 300)

    var enemy := enemy_scene.instantiate() as CharacterBody2D
    enemy.position = Vector2(700, 300)

    root.add_child(player)
    root.add_child(enemy)

    # Salvar
    var ps := PackedScene.new()
    var ok := ps.pack(root)
    if ok != OK:
        push_error("Falha ao pack Main")
    ResourceSaver.save(ps, scene_path)

# ======== SCRIPTS DE RUNTIME ========
func _player_script_source() -> String:
    return '''
extends CharacterBody2D

@export var speed: float = 220.0
@export var jump_velocity: float = -420.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

func _physics_process(delta: float) -> void:
    var input_dir: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    var v: Vector2 = velocity

    if not is_on_floor():
        v.y += gravity * delta
    else:
        if Input.is_action_just_pressed("jump"):
            v.y = jump_velocity

    v.x = input_dir * speed
    velocity = v
    move_and_slide()

func _on_Hurtbox_area_entered(area: Area2D) -> void:
    if area.name == "Hitbox":
        _respawn()

func _respawn() -> void:
    global_position = Vector2(100, 300)
    velocity = Vector2.ZERO
'''

func _enemy_script_source() -> String:
    return '''
extends CharacterBody2D

@export var speed: float = 80.0
var left_x: float
var right_x: float
var dir: int = 1
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

func _ready() -> void:
    var left_point := $LeftPoint.global_position.x
    var right_point := $RightPoint.global_position.x
    left_x = min(left_point, right_point)
    right_x = max(left_point, right_point)

func _physics_process(delta: float) -> void:
    var v: Vector2 = velocity
    if not is_on_floor():
        v.y += gravity * delta
    v.x = dir * speed
    velocity = v
    move_and_slide()

    if (dir == 1 and global_position.x >= right_x) or (dir == -1 and global_position.x <= left_x):
        dir *= -1
        if $Sprite2D:
            $Sprite2D.flip_h = dir < 0
'''

# ======== GIT ========
func _ensure_gitignore() -> void:
    var content := '''
# Godot
.import/
# Editor/OS
.DS_Store
Thumbs.db
# Logs/Temp
*.log
*.tmp
# Builds
/build/
'''
    _write_text("res://.gitignore", content)

func _git_init_and_first_commit() -> void:
    if not _has_git():
        print("[git] 'git' não encontrado no PATH. Pulei inicialização.")
        return
    if not _repo_already_initialized():
        _exec_git(["init"])
        _exec_git(["checkout", "-b", DEFAULT_BRANCH])
    _exec_git(["add", "."])
    _exec_git(["commit", "-m", "chore: bootstrap projeto godot 4 (platformer por código)"])

func _git_tag(tagname: String) -> void:
    if not _has_git(): return
    _exec_git(["tag", tagname], true)

func _git_set_remote_and_push(url: String, branch: String) -> void:
    if not _has_git(): return
    # add origin (ignora erro se já existe)
    _exec_git(["remote", "add", "origin", url], true)
    _exec_git(["push", "-u", "origin", branch], true)
    if CREATE_RELEASE_TAG != "":
        _exec_git(["push", "origin", CREATE_RELEASE_TAG], true)

func _repo_already_initialized() -> bool:
    return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://.git"))

func _has_git() -> bool:
    var out := []
    var code := OS.execute("git", ["--version"], out, true)
    return code == 0

func _exec_git(args: Array[String], ignore_error: bool=false) -> void:
    var out := []
    var code := OS.execute("git", args, out, true)
    if code != 0 and not ignore_error:
        push_error("[git] Erro %d ao executar: git %s\n%s" % [code, " ".join(args), "\n".join(out)])
    else:
        print("[git] git %s\n%s" % [" ".join(args), "\n".join(out)])
