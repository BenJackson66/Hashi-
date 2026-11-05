class_name HashiSound
extends Node
## Original PCM assets, bounded voices, no audio-triggered domain writes.
const CLIPS := {
 "bridge": preload("res://assets/audio/bridge.wav"),
 "remove": preload("res://assets/audio/remove.wav"),
 "island": preload("res://assets/audio/island.wav"),
 "win": preload("res://assets/audio/win.wav"),
 "restore": preload("res://assets/audio/restore.wav"),
 "tap": preload("res://assets/audio/tap.wav"),
 "end": preload("res://assets/audio/end.wav"),
}
const SEA=preload("res://assets/audio/sea.wav")
const HARBOR=preload("res://assets/audio/harbor.wav")
var enabled := true
var suspended := false
var events: Array[String] = []
var voices: Array[AudioStreamPlayer] = []
var ambience: AudioStreamPlayer
var _last: Dictionary = {}
var _context := -1
func _ready() -> void:
	for i in 6:
		var player:=AudioStreamPlayer.new();player.volume_db=-12.0;add_child(player);voices.append(player)
	ambience=AudioStreamPlayer.new();ambience.volume_db=-27.0;add_child(ambience)
func set_enabled(value: bool) -> void:
	enabled=value
	if not value:stop_all()
	else:_resume_ambience()
func stop_all() -> void:
	for voice in voices:voice.stop()
	if ambience!=null:ambience.stop()
func play(kind: String) -> void:
	if not enabled or suspended or not CLIPS.has(kind):return
	var now:=Time.get_ticks_msec()
	if now-int(_last.get(kind,-10000))<35:return
	_last[kind]=now
	events.append(kind)
	if events.size()>32:events.pop_front()
	for voice in voices:
		if not voice.playing:
			voice.stream=CLIPS[kind];voice.pitch_scale=1.0;voice.play();return
	# Keep the mix bounded; do not interrupt a celebration for another tap.
func set_context(progress: int, active: bool = true) -> void:
	var next_context: int = (1 if progress>=3 else 0) if active else -1
	if next_context==_context:return
	_context=next_context
	if ambience==null:return
	ambience.stop()
	if _context>=0:
		var stream:AudioStreamWAV=(HARBOR if _context==1 else SEA).duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/2
		ambience.stream=stream
	_resume_ambience()
func _resume_ambience() -> void:
	if ambience!=null and enabled and not suspended and _context>=0 and not ambience.playing:ambience.play()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		suspended=true;stop_all()
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		suspended=false;_resume_ambience()

func _exit_tree() -> void:
	stop_all()
	for voice in voices:voice.stream=null
	if ambience!=null:ambience.stream=null
