# Trim Playlist for iOS

This is the on-device Trim Playlist player. It keeps playlists on the iPhone, plays audio and video you choose from Files, and plays a direct media link. YouTube and Facebook downloads, trimming, and cookie files stay in the Windows app. The phone app does not embed Python, yt-dlp, or FFmpeg.

## What you can do

- Create, rename, and delete playlists.
- Choose one or more audio or video files. Trim Playlist copies them into the app so they keep playing.
- Paste a direct `http` or `https` link. Turn on Video when the link is a video file.
- Tap a track to play it. Pause, seek, skip, shuffle, repeat one track, or repeat the playlist.
- Move tracks up or down, or remove them from the playlist.

Playback can continue while the phone is locked. Removing a track deletes the copy stored in Trim Playlist. The original file in Files stays where it is.

## Build with Windows IPA Builder and iLoader

1. Set up [Windows IPA Builder](https://github.com/iamjrmh/WindowsIPABuilder) with its LLVM and iOS SDK dependencies. The player is Objective-C and uses UIKit plus AVFoundation.
2. Run the build script, passing the path to `ipabuilder-cli.exe`:

   ```powershell
   .\build-ipa.ps1 -BuilderCli C:\Users\rtodsan\Downloads\test2\tools\WindowsIPABuilder\ipabuilder-cli.exe
   ```

3. Import `dist/Trim Playlist.ipa` using [iLoader](https://github.com/DragoonT/iloader). iLoader can sign and install the IPA with your Apple ID.

Windows IPA Builder makes an ad-hoc IPA. It is not an App Store build and it cannot be uploaded to App Store Connect. A later App Store release still needs a Mac, Xcode, and Apple Developer signing.

## IPA output

The Windows build creates:

```text
dist/Trim Playlist.ipa
```

Import that file in iLoader, which signs and installs it using your Apple ID. The app targets iOS 16.5 and later.
