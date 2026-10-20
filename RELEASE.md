# Release note

This build is the folder `dist/TrimPlaylist`. That folder contains only this build.

## Files

- `Windows/TrimPlaylist-Setup.exe` — the Windows installer. After setup, open **Trim Playlist** from the Start menu.
- `Windows/TrimPlaylist-Windows.zip` — Windows. Unzip it and open **Trim Playlist** inside the `TrimPlaylist` folder.
- `Linux/TrimPlaylist-Linux.tar.gz` — Linux. Unpack it and run `start.sh` inside the `TrimPlaylist` folder. Install `libgtk-3-0` and `libwebkit2gtk-4.1-0` on Debian or Ubuntu first.
- `Android/TrimPlaylist-Android.apk` — Android, version 0.1.0.
- `iOS/TrimPlaylist-iOS.ipa` — iPhone and iPad, version 0.1.0.
- `Other-OS/TrimPlaylist-Other-OS.zip` — Other OS. On a Mac, install Python 3 and run `pc/start-macos.command`. On NixOS, run `nix develop`, then `python pc/app/trim_playlist_app.py`.

## What you can do

Cookies, downloads, and trim are in the app.

On Windows, in the browser player, and on the phone, **Create new** adds a cookie file. **Manual .txt** lets you name the file and type the cookies into it. **Import .txt file** stores a cookie `.txt` you already have. The new file is selected for the next download.

Authentication is one of these:

- **Cookie file** — create a named `.txt` or import one, as above.
- **Extension account** — browser only. Install [Trim Playlist Account Connector](https://chromewebstore.google.com/detail/trim-playlist-account-con/fiimgcmfjndfmhpfekbpomiilkdkbnam) from the Chrome Web Store, then choose **Connect with the extension**.
- **Platform account** — sign in inside the Trim Playlist window. The phone uses this same in-app sign-in.
- **No authentication** — a public video that does not need an account.

On the phone, Trim cuts the saved file from Start to End. A full download keeps the whole file.

## Windows notice

The Windows installer is unsigned. Windows can show a security warning before it runs. After installation, start **Trim Playlist** from the Start menu or from the shortcut in the zip.
