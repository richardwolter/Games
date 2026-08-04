## Serves the web export over HTTP so it can be opened in a browser.
##
##   godot --headless --script tools/serve_web.gd
##   then open http://localhost:8099/
##
## A web build cannot be tested from file:// — the loader fetches the wasm and
## the pack, and the browser refuses cross-origin requests for a local file. So
## the build needs a server, and this machine has none: no node, no php, and the
## `python3` on PATH is the Windows Store stub that only offers to install one.
##
## Rather than ship an untested artifact, here is the smallest static server that
## does the job. It is a development tool, not a web server: single connection at
## a time, no security, no range requests, localhost only.
##
## It does send COOP/COEP, because the export is now a THREADED one and a threaded
## Godot build will not start without cross-origin isolation — SharedArrayBuffer
## is only exposed to an isolated page. See _send().
extends SceneTree

const ROOT := "res://build/web"
const PORT := 8099

## Only what a Godot web build actually asks for. Anything else is served as a
## byte stream, which browsers handle fine for downloads.
const TYPES: Dictionary = {
	"html": "text/html; charset=utf-8",
	"js": "text/javascript; charset=utf-8",
	"wasm": "application/wasm",
	"pck": "application/octet-stream",
	"png": "image/png",
	"json": "application/json",
	"worklet.js": "text/javascript; charset=utf-8",
}

var _server := TCPServer.new()


func _initialize() -> void:
	var error := _server.listen(PORT, "127.0.0.1")
	if error != OK:
		print("could not listen on %d: %s" % [PORT, error_string(error)])
		quit()
		return
	print("serving %s at http://localhost:%d/  (ctrl-c to stop)" % [ROOT, PORT])


func _process(_delta: float) -> bool:
	if not _server.is_connection_available():
		return false
	var client := _server.take_connection()
	if client == null:
		return false
	_answer(client)
	return false


func _answer(client: StreamPeerTCP) -> void:
	var request := ""
	# Read until the end of the headers. Bounded, so a client that never sends a
	# blank line cannot wedge the loop.
	for attempt in 2000:
		if client.get_available_bytes() > 0:
			request += client.get_utf8_string(client.get_available_bytes())
			if request.contains("\r\n\r\n"):
				break
		else:
			OS.delay_msec(1)
	if request.is_empty():
		client.disconnect_from_host()
		return

	var target: String = request.get_slice(" ", 1)
	if target == "/" or target.is_empty():
		target = "/index.html"
	target = target.get_slice("?", 0)

	var path: String = ROOT + target
	if not FileAccess.file_exists(path):
		_send(client, 404, "text/plain", ("not found: %s" % target).to_utf8_buffer())
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var body := file.get_buffer(file.get_length())
	file.close()
	_send(client, 200, _type_of(target), body)
	print("  200 %-34s %d bytes" % [target, body.size()])


func _type_of(target: String) -> String:
	var name := target.get_file()
	# Two-part extensions first: index.audio.worklet.js must not be read as
	# "worklet.js" losing to a bare extension lookup.
	for key: String in TYPES:
		if key.contains(".") and name.ends_with(key):
			return TYPES[key]
	return TYPES.get(name.get_extension(), "application/octet-stream")


func _send(client: StreamPeerTCP, code: int, type: String, body: PackedByteArray) -> void:
	var header := (
		"HTTP/1.1 %d OK\r\n" % code
		+ "Content-Type: %s\r\n" % type
		+ "Content-Length: %d\r\n" % body.size()
		+ "Cache-Control: no-store\r\n"
		# Cross-origin isolation, which a THREADED web build cannot start without:
		# SharedArrayBuffer is only exposed to an isolated page, and Godot's threaded
		# export refuses to boot without it. Harmless for a threadless build, so
		# these are sent unconditionally rather than made a mode.
		#
		# itch.io provides the same thing through its "SharedArrayBuffer support"
		# checkbox; this is the local equivalent.
		+ "Cross-Origin-Opener-Policy: same-origin\r\n"
		+ "Cross-Origin-Embedder-Policy: require-corp\r\n"
		+ "Connection: close\r\n\r\n"
	)
	client.put_data(header.to_utf8_buffer())
	client.put_data(body)
	# The data is handed to the OS, not yet on the wire; disconnecting instantly
	# truncates a 38MB wasm. Wait for the socket to drain.
	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		client.poll()
		if client.get_available_bytes() < 0:
			break
		OS.delay_msec(2)
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
	client.disconnect_from_host()
