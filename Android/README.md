# Trim Playlist for Android

This is the Trim Playlist app for Android, version 0.1.0. Playlists, downloads, trim, and cookie files stay on the phone. The app does not embed Python, yt-dlp, or FFmpeg.

## What you can do

- Create, rename, and delete playlists.
- Choose one or more audio or video files. Trim Playlist remembers the files you picked.
- Paste a direct `http` or `https` link to an audio or video file, and mark it as audio or video.
- Download a video or playlist. Full download saves the whole file. Trim saves a file cut from Start to End. A download is not added to a playlist on its own.
- Add a cookie file with **Create new**. **Manual .txt** asks for a name and then you type the cookies. **Import .txt file** uses a `.txt` you already have. Platform account signs in inside the app.
- Tap a track to play it. Pause, seek, skip, shuffle, repeat one track, or repeat the playlist.
- Move tracks up or down, or remove them from the playlist.

Files already on the phone are not copied. A track saved by an older build that only stored a name has to be chosen again before it can play.

## Build

1. Install Android Studio and JDK 17.
2. Open this `Android` folder in Android Studio.
3. Let Android Studio install the configured Gradle and Kotlin components, then run the `app` configuration on a device or emulator.

The app targets Android 8.0 and later.

## APK output

`dist/TrimPlaylist-Android.apk` is a debug-signed build of this player. You can install that file for personal testing, or open this folder in Android Studio and use Run. A Play Store release needs your own keystore.
