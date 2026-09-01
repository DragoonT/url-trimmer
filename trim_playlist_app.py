"""Trim Playlist desktop application — double-click starts server + app window."""

from __future__ import annotations

import app_paths  # noqa: F401 — installs hidden subprocess on Windows

import argparse
import ctypes
import sys
import threading

import webview

from app_paths import is_frozen
from playlist_server import (
    PLAYLISTS_DIR,
    PlaylistHTTPServer,
    build_app_url,
    create_server_on_port,
    stop_server,
    wait_for_server,
)


def show_error(message: str) -> None:
    if is_frozen():
        ctypes.windll.user32.MessageBoxW(  # type: ignore[attr-defined]
            0,
            message,
            "Trim Playlist",
            0x10,
        )
    else:
        print(message, file=sys.stderr)


def run_desktop_window(
    url: str,
    server: PlaylistHTTPServer,
    host: str,
    port: int,
) -> None:
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    wait_for_server(url)

    webview.create_window(
        "Trim Playlist",
        url,
        width=1280,
        height=820,
        min_size=(960, 640),
        background_color="#0a0a0f",
    )
    webview.start()

    if stop_server(server, thread):
        if not is_frozen():
            print(f"Server stopped. Port {port} is free.")
    else:
        show_error(f"Port {port} is still in use after closing.\nWait a moment or restart the app.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Trim Playlist desktop app")
    parser.add_argument("--port", "-p", type=int, default=8765)
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="Bind address (use 0.0.0.0 for LAN access from other devices)",
    )
    args = parser.parse_args()

    try:
        server, port = create_server_on_port(args.host, args.port)
    except Exception as exc:
        show_error(f"Could not start server:\n\n{exc}")
        sys.exit(1)

    url = build_app_url(args.host, port)

    if not is_frozen():
        print(f"Trim Playlist: {url}")
        if port != args.port:
            print(f"Port {args.port} is in use — switched to {port}")
        print(f"Playlists saved: {PLAYLISTS_DIR}")
        print("Server running inside app. Close the window to stop.")

    try:
        run_desktop_window(url, server, args.host, port)
    except Exception as exc:
        stop_server(server)
        show_error(f"Trim Playlist failed to open:\n\n{exc}")
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
