extends Node

func _ready():
    # Ir direto para a nova tela de login com usuário/senha
    call_deferred("_load_login_scene")

func _load_login_scene():
    var user_login_scene = preload("res://user_login.tscn") 
    var user_login = user_login_scene.instantiate()
    get_tree().root.call_deferred("add_child", user_login)
    call_deferred("queue_free")
