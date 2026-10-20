# Trim Playlist for iOS

This is the Trim Playlist app for iPhone and iPad, version 0.1.0. Playlists, downloads, trim, and cookie files stay on the device. The app does not embed Python, yt-dlp, or FFmpeg.

## What you can do

- Create, rename, and delete playlists.
- Choose one or more audio or video files. Trim Playlist copies them into the app so they keep playing.
- Paste a direct `http` or `https` link. Turn on Video when the link is a video file.
- Download a video or playlist. Full download saves the whole file. Trim saves a file cut from Start to End. A download is not added to a playlist on its own.
- Add a cookie file with **Create new**. **Manual .txt** asks for a name and then you type the cookies. **Import .txt file** uses a `.txt` you already have. Platform account signs in inside the app.
- Tap a track to play it. Pause, seek, skip, shuffle, repeat one track, or repeat the playlist.
- Move tracks up or down, or remove them from the playlist.

Playback can continue while the phone is locked. Removing a track deletes the copy stored in Trim Playlist. The original file in Files stays where it is.

## Build with Windows IPA Builder and iLoader

1. Set up [Windows IPA Builder](https://github.com/iamjrmh/WindowsIPABuilder) with its LLVM and iOS SDK dependencies. The player is Objective-C and uses UIKit plus AVFoundation.
2. Run the build script, passing the path to `ipabuilder-cli.exe`:

   ```powershell
   .\build-ipa.ps1 -BuilderCli C:\path\to\ipabuilder-cli.exe
   ```

3. Import `dist/Trim Playlist.ipa` using [iLoader](https://github.com/DragoonT/iloader). iLoader can sign and install the IPA with your Apple ID.

Windows IPA Builder makes an ad-hoc IPA. It is not an App Store build and it cannot be uploaded to App Store Connect. A later App Store release still needs a Mac, Xcode, and Apple Developer signing.

## IPA output

The Windows build creates:

```text
dist/Trim Playlist.ipa
```

Import that file in iLoader, which signs and installs it using your Apple ID. The app targets iOS 16.5 and later.
