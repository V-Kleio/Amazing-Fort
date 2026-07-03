class_name Kid
extends Area2D

## The child the player protects. A trigger (Area2D) fixed at the bottom-center of the
## arena. Reuses GameManager for HP (Max 3) so the existing loss routing applies.
##
## Contract for the Combat phase (a teammate's work): enemy projectiles must be in the
## group &"enemy_projectile" and on the Projectile collision layer. When one enters the
## trigger the Kid loses 1 HP, the projectile is destroyed, and a hurt flash plays.
##
## Required node tree (see docs/build_setup_guide.html):
##   Kid (Area2D)  <- this script  (layer=Kid, mask=Projectile, monitorable=true)
##    ├ Sprite2D
##    ├ CollisionShape2D            (Box/Rect trigger shape)
##    └ AudioStreamPlayer2D         (optional)

const HURT_TINT: Color = Color(1.0, 0.4, 0.4)

@export var hurt_sound: AudioStream

var _active: bool = true

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _audio: AudioStreamPlayer2D = get_node_or_null(^"AudioStreamPlayer2D")

func _ready() -> void:
	add_to_group(&"kid")
	body_entered.connect(_on_hit)   # RigidBody2D projectiles (e.g. ball.tscn)
	area_entered.connect(_on_hit)   # Area2D projectiles, if the teammate uses those

## Combat toggles this on; during Build there are no projectiles so it's harmless.
func set_active(active: bool) -> void:
	_active = active

func _on_hit(other: Node) -> void:
	if not _active or other == null:
		return
	if not other.is_in_group(&"enemy_projectile"):
		return
	GameManager.take_damage(1)
	GameEvents.kid_damaged.emit(GameManager.player_health)
	_play_hurt()
	other.queue_free()

func _play_hurt() -> void:
	if _audio != null and hurt_sound != null:
		_audio.stream = hurt_sound
		_audio.play()
	if _sprite == null:
		return
	_sprite.modulate = HURT_TINT
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_SINE)
