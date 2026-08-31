## Loading a picture in a way that survives being exported.
##
## Every sheet in this game was read with `Image.load_from_file` on a globalized path, which
## works beautifully right up until the game is not being run out of its own source folder.
## In an export there is no `res://assets/ui.png` on disk — the file is inside the pack — and
## on the web there is no disk at all, so every one of those calls returns null and the whole
## game falls back to its placeholders at once.
##
## The way that works everywhere is to let the engine's own loader find it: a PNG in the
## project is imported to a texture, and that texture is in the pack. So this asks the loader
## first and only falls back to reading the file directly, which is what the offline tools in
## tools/ need when they have just written a sheet the editor has not imported yet.
class_name Art
extends RefCounted


## A texture, or null if there is no such picture. Try the pack, then the disk.
static func texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		var found := ResourceLoader.load(path, "Texture2D") as Texture2D
		if found != null:
			return found
	var raw := image(path)
	return null if raw == null else ImageTexture.create_from_image(raw)


## The pixels, for the few callers that want to cut a sheet up or blit sheets together
## rather than just draw one.
##
## An imported texture can be handed back compressed, which is no use to anyone reading
## pixels out of it, so it is expanded before it goes anywhere.
static func image(path: String) -> Image:
	if ResourceLoader.exists(path, "Texture2D"):
		var found := ResourceLoader.load(path, "Texture2D") as Texture2D
		if found != null:
			var out := found.get_image()
			if out != null:
				if out.is_compressed():
					out.decompress()
				return out
	# Not imported, or not in the pack: read it off the disk. This is the tools' path, and
	# in an exported game it simply fails, which is what the callers' fallbacks are for.
	return Image.load_from_file(ProjectSettings.globalize_path(path))
