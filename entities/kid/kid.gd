class_name Kid
extends StaticBody2D

signal died

const HURT_TINT: Color = Color(1.0, 0.4, 0.4)

@export var hurt_sound: AudioStream
## Waktu kebal (dalam detik) setelah terkena hit agar tidak terkena hit berkali-kali dari bola yang sama
@export var iframe_duration: float = 0.5

var _active: bool = true
var _is_invulnerable: bool = false # Status kebal sementara

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _audio: AudioStreamPlayer2D = get_node_or_null(^"AudioStreamPlayer2D")
@onready var _hitbox: Area2D = $Hitbox

func _ready() -> void:
	add_to_group(&"kid")
	_hitbox.body_entered.connect(_on_hit)
	_hitbox.area_entered.connect(_on_hit)

func set_active(active: bool) -> void:
	_active = active

func _on_hit(other: Node) -> void:
	# Jangan terima hit kalau Kid tidak aktif, bola null, atau sedang dalam masa kebal
	if not _active or other == null or _is_invulnerable:
		return
		
	# Pengecekan grup atau nama bola
	if not other.is_in_group(&"enemy_projectile") and not "Ball" in other.name:
		return
		
	# Aktifkan masa kebal sementara
	_is_invulnerable = true
	get_tree().create_timer(iframe_duration).timeout.connect(func(): _is_invulnerable = false)
		
	# Jalankan logika damage
	GameManager.take_damage(1)
	GameEvents.kid_damaged.emit(GameManager.player_health)
	_play_hurt()
	
	# === PERUBAHAN DI SINI ===
	# other.queue_free() -> DIHAPUS agar bola tidak hilang dan bisa memantul secara fisik!
	
	if GameManager.player_health <= 0:
		_active = false
		_is_invulnerable = true # Kunci agar tidak bisa kena hit lagi setelah mati
		died.emit()

func _play_hurt() -> void:
	if _audio != null and hurt_sound != null:
		_audio.stream = hurt_sound
		_audio.play()
	if _sprite == null:
		return
		
	_sprite.modulate = HURT_TINT
	var tween: Tween = create_tween()
	# Durasi kedip merah disesuaikan jadi 0.4 detik (pas dengan iframe) agar tidak terlalu lama merahnya
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_SINE)
