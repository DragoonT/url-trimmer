"""Headless Trim Playlist server for the Tauri desktop shell.

Serves the same player UI and JSON API as the desktop window, without opening
one. The Tauri app spawns this process, reads the TRIM_SERVER_READY line from
stdout, and points its webview at the printed URL. Stopping the process stops
the server.
"""

from __future__ import annotations

import argparse
import sys
import threading
import time
from pathlib import Path

# Same bootstrap as trim_playlist_app.py: make the repo importable when run
# from source (python pc/app/trim_playlist_server_main.py).
for _parent in Path(__file__).resolve().parents:
    if (_parent / "pc" / "app" / "app_paths.py").is_file():
        _root = str(_parent)
        if _root not in sys.path:
            sys.path.insert(0, _root)
        break

# Importing pc.app.app_paths installs the hidden-subprocess patch on Windows so
# ffmpeg / yt-dlp children never flash a console window.
from pc.app.app_paths import is_frozen  # noqa: F401

from pc.server.playlist_server import (
    PLAYLISTS_DIR,
    build_app_url,
    create_server_on_port,
    stop_server,
)

import pc.server.playlist_server as _playlist_server

# The Tauri shell pipes this process's stdout/stderr. Per-request access logs
# would keep writing into that pipe forever, so run the headless server quiet.
_playlist_server.PlaylistHandler.log_message = lambda self, fmt=None, *args: None


def main() -> None:
    parser = argparse.ArgumentParser(description="Trim Playlist headless server (Tauri shell)")
    parser.add_argument("--port", "-p", type=int, default=8765)
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="Bind address (use 0.0.0.0 for LAN access from other devices)",
    )
    args = parser.parse_args()

    server, port = create_server_on_port(args.host, args.port)
    url = build_app_url(args.host, port)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    # The Tauri shell waits for this exact line before opening the window.
    print(f"TRIM_SERVER_READY url={url}", flush=True)
    if port != args.port:
        print(f"TRIM_SERVER_PORT_SHIFTED requested={args.port} actual={port}", flush=True)
    print(f"TRIM_SERVER_PLAYLISTS dir={PLAYLISTS_DIR}", flush=True)
    if not is_frozen():
        print("Server running in headless mode. Stop the process to shut down.", flush=True)

    try:
        while thread.is_alive():
            time.sleep(3600)
    except KeyboardInterrupt:
        pass
    finally:
        stop_server(server, thread)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
