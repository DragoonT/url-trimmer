# Contributing to Trim Playlist

Thank you for helping improve Trim Playlist.

The app is what users run. Download steps for the current build are in the [release note](RELEASE.md). This page is only for people changing the project.

## Run from source

1. Install Python 3.10 or newer.
2. Install dependencies:

   ```powershell
   pip install -r requirements.txt
   ```

3. Start the desktop window:

   ```powershell
   python pc/app/trim_playlist_app.py
   ```

On Windows you can also double-click `pc/start-playlist.bat`.

## Checks before a pull request

```powershell
python -m py_compile pc/app/app_paths.py pc/app/trim_playlist_app.py pc/server/playlist_server.py pc/downloads/download_jobs.py
python -m unittest tests.test_cookie_files tests.test_download_selection tests.test_account_connections tests.test_online_tracks
python tests/check_download_ui.py
```

Try the desktop window when a change touches playback, playlists, Trim URL, cookies, or online tracks.

## Other systems

- Linux: install Python 3.10 or newer, GTK, and WebKit, then use the same virtual environment and `python pc/app/trim_playlist_app.py`. On Debian and Ubuntu the system packages are `python3-gi`, `python3-gi-cairo`, `gir1.2-gtk-3.0`, and `gir1.2-webkit2-4.1`.
- macOS: on a Mac, run `pc/start-macos.command`. A public Mac download also needs Apple signing.
- NixOS: run `nix develop`, then `python pc/app/trim_playlist_app.py`.
- Android: build steps are in [Android/README.md](Android/README.md).
- iOS: build steps are in [iOS/README.md](iOS/README.md).

## Pull requests

Describe the problem, the behavior a user will see, and the checks you ran. Keep a change focused on one fix or improvement.

When a download step or a user-facing requirement changes, update the [release note](RELEASE.md) if it is about this build, and the [README](README.md) if it is how users open the app.

Never include cookies, account sessions, private URLs, downloaded files, or other personal data in a pull request, issue, screenshot, or log. Do not commit `setlist.json`, cookie files, or media in `output/`.

## Reporting bugs

Include the operating system, whether you used the zip, the installer, Linux, macOS, NixOS, or a phone build, the action that failed, and the error text. Remove account names, cookies, and private media URLs before posting.
