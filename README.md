# Trim Playlist

<p align="center">
  <img src="store-assets/trim-playlist-1280x800.png" alt="Trim Playlist desktop player showing playlists, local tracks, and playback controls" width="960">
</p>

Trim Playlist keeps a playlist and can download or trim a video URL. You do that in the app: the Windows window, the same screen in a browser, or the Android and iOS apps.

What changed in this build is in the [release note](https://github.com/DragoonT/url-trimmer/releases/tag/v0.3.2).

## Download this build

The same files are on the [Trim Playlist website](https://dragoont.github.io/url-trimmer/).

| Download | Who it is for | How to open it |
|----------|----------------|----------------|
| [Windows](https://dragoont.github.io/url-trimmer/downloads/Windows/TrimPlaylist-Windows.zip) | Windows | Unzip it. Open **Trim Playlist** inside the `TrimPlaylist` folder. |
| [Windows installer](https://dragoont.github.io/url-trimmer/downloads/Windows/TrimPlaylist-Setup.exe) | Windows | Run the installer. Open **Trim Playlist** from the Start menu. You can also add a desktop shortcut during setup. |
| [Linux](https://dragoont.github.io/url-trimmer/downloads/Linux/TrimPlaylist-Linux.tar.gz) | Linux | Unpack it. Run `start.sh` inside the `TrimPlaylist` folder. |
| [Android](https://dragoont.github.io/url-trimmer/downloads/Android/TrimPlaylist-Android.apk) | Android | Install the APK. If this phone already has 0.1.0, uninstall that copy first. |
| [iPhone and iPad](https://dragoont.github.io/url-trimmer/downloads/iOS/TrimPlaylist-iOS.ipa) | iPhone and iPad | Open the IPA. If this phone already has 0.1.0, uninstall that copy first. |
| [Other OS](https://dragoont.github.io/url-trimmer/downloads/Other-OS/TrimPlaylist-Other-OS.zip) | Other OS | Unzip it, then follow the system notes below. |

The Windows zip and the installer already include what the app needs. You do not install Python yourself for those two files.

Linux needs GTK and WebKit before `start.sh` will open the window. On Debian and Ubuntu, install `libgtk-3-0` and `libwebkit2gtk-4.1-0`.

For Other OS, install Python 3. On a Mac, unzip it and run `pc/start-macos.command`. On NixOS, unzip it, run `nix develop`, then run `python pc/app/trim_playlist_app.py`.

## Phone

The phone apps are version 0.1.0. Android and iPhone and iPad are in the download table above. Building them is described in the [Android](Android/README.md) and [iOS](iOS/README.md) pages.

## In the app

Open **Trim URL** from the title at the top left when you want to download. **Trim Playlist** in that same menu returns to the player.

On the phone, **Trim** saves a file cut from Start to End. **Full download** saves the whole file. Downloads are not added to a playlist on their own.

Playlists, cookie files, and downloaded media stay on that computer or phone.

## Authentication

Trim URL asks you to choose one authentication method.

**Cookie file.** Use a `.txt` cookie file. Choose **Create new**, then:

- **Manual .txt** asks for a name. Type the cookie text into that file, the same way you would in a text editor, and save it. The app stores the name as a `.txt` file and selects it.
- **Import .txt file** takes a cookie `.txt` you already have and selects that file.

**Extension account.** This is only for the browser. Install [Trim Playlist Account Connector](https://chromewebstore.google.com/detail/trim-playlist-account-con/fiimgcmfjndfmhpfekbpomiilkdkbnam) from the Chrome Web Store, then choose **Connect with the extension**. The extension opens the platform in the browser and saves the session. The phone app does not use this extension.

**Platform account.** Sign in inside the Trim Playlist window. On the phone, this is the sign-in page inside the app. It does not open a browser tab and it does not use the extension.

**No authentication.** Use this for a public video that does not need a signed-in account.
