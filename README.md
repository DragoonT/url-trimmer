# Trim Playlist

<p align="center">
  <img src="store-assets/trim-playlist-1280x800.png" alt="Trim Playlist desktop player showing playlists, local tracks, and playback controls" width="960">
</p>

Trim Playlist keeps a playlist and can download or trim a video URL. You do that in the app: the Windows window, the same screen in a browser, or the Android and iOS apps.

What changed in this build is in the [release note](RELEASE.md).

## Download this build

The files are in the `dist/TrimPlaylist` folder.

| File | Who it is for | How to open it |
|------|----------------|----------------|
| `TrimPlaylist-Windows.zip` | Windows | Unzip it. Open **Trim Playlist** inside the `TrimPlaylist` folder. |
| `TrimPlaylist-Setup.exe` | Windows | Run the installer. Open **Trim Playlist** from the Start menu. You can also add a desktop shortcut during setup. |
| `TrimPlaylist-Linux.zip` | Linux | Unzip it. Run `start.sh` inside the `TrimPlaylist` folder. |
| `TrimPlaylist-Other-OS.zip` | macOS and NixOS | Unzip it, then follow the system notes below. |

The Windows zip and the installer already include what the app needs. You do not install Python yourself for those two files.

Linux needs GTK and WebKit before `start.sh` will open the window. On Debian and Ubuntu, install `libgtk-3-0` and `libwebkit2gtk-4.1-0`.

On macOS, install Python 3, unzip `TrimPlaylist-Other-OS.zip`, and run `start-macos.command`.

On NixOS, unzip `TrimPlaylist-Other-OS.zip`, run `nix develop`, then run `python trim_playlist_app.py`.

## Phone

The phone apps are version 0.3.2.

- Android: install `Android/dist/TrimPlaylist-Android.apk`. Building it is described in the [Android](Android/README.md) page.
- iPhone: install `iOS/dist/Trim Playlist.ipa`. Building and installing it is described in the [iOS](iOS/README.md) page.

## In the app

Open **Trim URL** from the title at the top left when you want to download. **Trim Playlist** in that same menu returns to the player.

Choose one authentication method:

- **Cookie file** uses a `.txt` cookie file.
- **Extension account** connects with the browser extension.
- **Platform account** signs in inside the Trim Playlist window.
- **No authentication** is for a public video.

To add a cookie file, choose **Create new**.

- **Manual .txt** asks for a name. You then type the cookie text, the same way you would in a text editor, and save it. The app stores that name as a `.txt` file and selects it.
- **Import .txt file** takes a cookie `.txt` you already have and selects that file.

On the phone, **Trim** saves a file cut from Start to End. **Full download** saves the whole file. Downloads are not added to a playlist on their own.

Playlists, cookie files, and downloaded media stay on that computer or phone.
