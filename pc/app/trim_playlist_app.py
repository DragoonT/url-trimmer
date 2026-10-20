"""Trim Playlist desktop application — double-click starts server + app window."""

from __future__ import annotations

import sys
from pathlib import Path
for _parent in Path(__file__).resolve().parents:
    if (_parent / "pc" / "app" / "app_paths.py").is_file():
        _root = str(_parent)
        if _root not in sys.path:
            sys.path.insert(0, _root)
        break

import pc.app.app_paths  # noqa: F401 — installs hidden subprocess on Windows

import argparse
import ctypes
import sys
import threading
import time
from email.utils import parsedate_to_datetime

import webview

import pc.accounts.account_connections as account_connections
from pc.app.app_paths import is_frozen
from pc.app.app_update import offer_update
from pc.server.playlist_server import (
    PLAYLISTS_DIR,
    PlaylistHTTPServer,
    build_app_url,
    create_server_on_port,
    stop_server,
    wait_for_server,
)


APP_SIGN_IN = {
    'youtube': 'https://accounts.google.com/ServiceLogin?service=youtube&hl=en&passive=true&continue=https%3A%2F%2Fm.youtube.com%2F',
    'facebook': 'https://m.facebook.com/login',
    'instagram': 'https://www.instagram.com/accounts/login/',
    'x': 'https://x.com/i/flow/login',
    'tiktok': 'https://www.tiktok.com/login',
    'twitch': 'https://www.twitch.tv/login',
}


def session_cookies(cookies):
    rows = []
    for cookie in cookies or []:
        for name, morsel in cookie.items():
            domain = str(morsel['domain'] or '')
            expires = morsel['expires']
            expiration = 0
            if expires:
                try:
                    expiration = parsedate_to_datetime(str(expires)).timestamp()
                except (TypeError, ValueError, OverflowError):
                    expiration = 0
            rows.append({
                'domain': domain,
                'name': name,
                'value': morsel.value,
                'path': morsel['path'] or '/',
                'expirationDate': expiration,
                'hostOnly': not domain.startswith('.'),
                'secure': str(morsel['secure']).lower() == 'true',
                'httpOnly': str(morsel['httponly']).lower() == 'true',
            })
    return rows


def signed_in(platform, names):
    markers = account_connections.PLATFORMS[platform][3]
    if platform == 'youtube':
        return bool(names.intersection({'SID', '__Secure-1PSID', '__Secure-3PSID'}))
    return bool(markers) and all(marker in names for marker in markers)


class DesktopSignIn:
    """Platform sign-in inside the app window. The browser extension is not used."""

    def __init__(self):
        self._windows = {}

    def sign_in(self, platform):
        if platform not in APP_SIGN_IN:
            return {'ok': False, 'error': 'Unsupported platform'}
        url = APP_SIGN_IN[platform]
        name = account_connections.PLATFORMS[platform][0]
        window = self._windows.get(platform)
        if window not in webview.windows:
            window = webview.create_window(
                f'Sign in · {name}',
                url,
                width=420,
                height=760,
                background_color='#0e131c',
                text_select=True,
            )
            self._windows[platform] = window
            threading.Thread(target=self._watch, args=(platform, window), daemon=True).start()
        else:
            window.show()
            window.load_url(url)
        return {'ok': True, 'waiting': True}

    def _watch(self, platform, window):
        deadline = time.time() + 600
        domains = account_connections.PLATFORMS[platform][2]
        while time.time() < deadline:
            time.sleep(1)
            if window not in webview.windows:
                return
            try:
                found = session_cookies(window.get_cookies())
            except Exception:
                return
            matched = []
            for cookie in found:
                host = cookie['domain'].lstrip('.').lower()
                if any(host == domain or host.endswith('.' + domain) for domain in domains):
                    matched.append(cookie)
            if not signed_in(platform, {cookie['name'] for cookie in matched}):
                continue
            try:
                token = account_connections.begin(platform)
                account_connections.receive(token, matched, True)
            except Exception:
                continue
            try:
                window.destroy()
            except Exception:
                pass
            self._windows.pop(platform, None)
            return


def show_error(message: str) -> None:
    if is_frozen() and sys.platform == "win32":
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

    window = webview.create_window(
        "Trim Playlist",
        url,
        width=1280,
        height=820,
        min_size=(960, 640),
        background_color="#0a0a0f",
        js_api=DesktopSignIn(),
        text_select=True,
    )
    webview.start(lambda: offer_update(window))

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
