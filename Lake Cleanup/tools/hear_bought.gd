## Writes one of the generated sounds out as a wave file, so it can be listened to without
## playing the game up to the moment that fires it.
##
##   godot --headless --path . res://tools/hear_bought.tscn -- found
##
## The name after the dashes is the field on Sfx, without its underscore; the default is the
## crate's pop. Only the sounds still built in code are here — the rest are files in
## assets/sfx. The sounds themselves live in Sfx and are built there; this only asks for
## one and puts the samples in a file with a header on the front.
extends Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var which := String(args[0]) if not args.is_empty() else "catch"
	var sfx := Sfx.new()
	add_child(sfx)
	var path := "user://%s.wav" % which
	var wav: AudioStreamWAV = sfx.get(StringName("_" + which))
	if wav == null:
		push_error("no sound was built")
		get_tree().quit(1)
		return
	var pcm := wav.data
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	out.append_array(_u32(36 + pcm.size()))
	out.append_array("WAVEfmt ".to_ascii_buffer())
	out.append_array(_u32(16))
	out.append_array(_u16(1))
	out.append_array(_u16(1))
	out.append_array(_u32(wav.mix_rate))
	out.append_array(_u32(wav.mix_rate * 2))
	out.append_array(_u16(2))
	out.append_array(_u16(16))
	out.append_array("data".to_ascii_buffer())
	out.append_array(_u32(pcm.size()))
	out.append_array(pcm)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(out)
	file.close()
	print("wrote ", ProjectSettings.globalize_path(path), " (", pcm.size() / 2, " samples)")
	get_tree().quit()


func _u32(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes


func _u16(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(2)
	bytes.encode_u16(0, value)
	return bytes
