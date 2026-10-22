"""Serve a web export locally, with the headers a threaded Godot build needs.

A threaded web export uses SharedArrayBuffer, which a browser only hands out on a page that
is cross-origin isolated: the page must come with
    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp
`python -m http.server` sends neither, and the game stops on a "SharedArrayBuffer" error
before the boot splash. itch.io sends them when the page's "SharedArrayBuffer support" box
is ticked; this is the same thing for testing at home.

    python tools/serve_web.py [folder] [port]      (defaults: build/web_demo, 8060)
"""

import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class Isolated(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "build/web_demo"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8060
    server = ThreadingHTTPServer(("127.0.0.1", port), partial(Isolated, directory=folder))
    print(f"Serving {folder} on http://127.0.0.1:{port}/", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
