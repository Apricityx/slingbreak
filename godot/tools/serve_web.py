#!/usr/bin/env python3
"""Serve only the exported Godot Web directory with isolation headers."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8081)
    parser.add_argument("--directory", type=Path,
                        default=Path(__file__).resolve().parents[2] / "agent-tmp/godot/web-native")
    options = parser.parse_args()
    directory = options.directory.resolve()
    if not (directory / "index.html").is_file():
        parser.error("Missing index.html; run godot/tools/build_web.py first")
    with ThreadingHTTPServer((options.host, options.port), partial(Handler, directory=str(directory))) as server:
        print(f"Serving {directory} at http://{options.host}:{options.port}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
