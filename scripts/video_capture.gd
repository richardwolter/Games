## Records the game canvas to a video file the player can keep or post.
##
## Web only, and deliberately so. Godot has no runtime video encoder — the
## engine's own movie writer is a startup flag that takes over the whole process
## — so on desktop the honest options were shelling out to an ffmpeg the player
## probably hasn't got, or relaunching the game as a subprocess to render an AVI.
## The build that ships is the web build; every browser already has a video
## encoder wired to the canvas, and using it costs one MediaRecorder.
##
## Everything lives behind is_supported(). On a desktop build JavaScriptBridge
## has no browser to talk to, so the button is simply not offered.
class_name VideoCapture
extends RefCounted

## VP9 first, VP8 second, then whatever the browser will admit to. Safari only
## grew MediaRecorder support recently and answers with mp4, which is fine — the
## file extension follows the type that was actually accepted.
const CODECS: Array[String] = [
	"video/webm;codecs=vp9",
	"video/webm;codecs=vp8",
	"video/webm",
	"video/mp4",
]

## Frames per second asked of captureStream. Matches the replay's own sample rate
## rather than the display's: the recording being filmed is 60Hz, and asking for
## 144 would encode the same frame two and a bit times.
const FPS := 60

## Bits per second. Generous — the footage is one flat-shaded 2D scene with large
## areas of unchanging water, so the encoder spends very little of it, and a
## smeared replay of the one good crossing is not worth the megabyte saved.
const BITRATE := 8_000_000

## The name of the JS object all of this hangs off. One global, created once.
const NS := "window.__straitRec"


## Is there a browser here with a canvas and a MediaRecorder in it?
static func is_supported() -> bool:
	return unavailable_reason().is_empty()


## Why saving a video won't work here, or "" if it will.
##
## A sentence rather than a bool, because the button is now always on the replay
## bar and pressing it has to say something. It was previously built only where
## it worked, which meant the one player most likely to go looking for it — a
## developer running the desktop build — found nothing at all and reasonably
## concluded the feature was broken.
static func unavailable_reason() -> String:
	if not OS.has_feature("web"):
		return "Saving video needs the browser build — Godot can't encode video on the desktop"
	var answer: Variant = JavaScriptBridge.eval(
		"typeof MediaRecorder !== 'undefined'"
		+ " && !!document.querySelector('canvas')"
		+ " && !!document.querySelector('canvas').captureStream",
		true
	)
	if not bool(answer):
		return "This browser can't record the canvas — try Chrome or Firefox"
	return ""


## Start filming the canvas. Returns false if the browser refused, in which case
## nothing was started and the caller should just play the replay unrecorded.
##
## The JS is installed and invoked in one eval rather than kept as a persistent
## callback: there is no message coming back from the browser that the game needs
## to react to, so there is nothing to keep a JavaScriptObject alive for.
static func start() -> bool:
	if not is_supported():
		return false
	var js := """
		(function() {
			var R = %s = %s || {};
			try {
				if (R.rec && R.rec.state === 'recording') { R.rec.stop(); }
				var canvas = document.querySelector('canvas');
				var stream = canvas.captureStream(%d);
				var types = %s;
				var picked = '';
				for (var i = 0; i < types.length; i++) {
					if (MediaRecorder.isTypeSupported(types[i])) { picked = types[i]; break; }
				}
				if (!picked) { return false; }
				R.type = picked;
				R.chunks = [];
				R.rec = new MediaRecorder(stream, {
					mimeType: picked, videoBitsPerSecond: %d
				});
				R.rec.ondataavailable = function(e) {
					if (e.data && e.data.size > 0) { R.chunks.push(e.data); }
				};
				R.rec.start();
				return true;
			} catch (err) {
				console.error('replay capture failed', err);
				return false;
			}
		})()
	""" % [NS, NS, FPS, JSON.stringify(CODECS), BITRATE]
	return bool(JavaScriptBridge.eval(js, true))


## Stop filming and hand the file to the browser's downloader.
##
## The download is triggered from inside the recorder's own onstop handler
## because the last chunk of video does not exist until it fires — asking for the
## blob on the line after stop() reliably produces a file missing its final
## second, which on a fifteen-second clip is the part everyone wants.
static func stop_and_download(base_name: String) -> void:
	if not OS.has_feature("web"):
		return
	var js := """
		(function() {
			var R = %s;
			if (!R || !R.rec || R.rec.state !== 'recording') { return false; }
			R.rec.onstop = function() {
				var blob = new Blob(R.chunks, { type: R.type });
				var url = URL.createObjectURL(blob);
				var a = document.createElement('a');
				a.href = url;
				a.download = %s + (R.type.indexOf('mp4') >= 0 ? '.mp4' : '.webm');
				document.body.appendChild(a);
				a.click();
				document.body.removeChild(a);
				setTimeout(function() { URL.revokeObjectURL(url); }, 10000);
				R.chunks = [];
			};
			R.rec.stop();
			return true;
		})()
	""" % [NS, JSON.stringify(base_name)]
	JavaScriptBridge.eval(js, true)


## Abandon a recording without producing a file — for a replay the player skipped.
static func cancel() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function() {
			var R = %s;
			if (R && R.rec && R.rec.state === 'recording') {
				R.rec.onstop = function() { R.chunks = []; };
				R.rec.stop();
			}
		})()
	""" % NS, true)
