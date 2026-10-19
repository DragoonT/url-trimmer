# Contributing to Trim Playlist

Thank you for helping improve Trim Playlist.

## Build and run by platform

### Windows: source and portable source package

1. Install Python 3.10 or newer.
2. Install dependencies:

   ```powershell
   pip install -r requirements.txt -r requirements-build.txt
   ```

3. Start the desktop app:

   ```powershell
   python trim_playlist_app.py
   ```

The portable source archive contains no executable, installer, account data, or cookie files. Create it from the repository with:

```powershell
python scripts\package-portable-source.py
```

Extract `dist/portable/TrimPlaylist-portable-source.zip`, install Python dependencies, then run `start-playlist.bat`.

### Windows: packaged app and installer

Install Python plus build dependencies, then run:

```powershell
.\scripts\build-desktop.ps1 -Target windows -Installer
```

This creates a folder build at `dist/TrimPlaylist/` and an Inno Setup installer at `dist/installer/TrimPlaylist-Setup.exe`. Close any running copy of Trim Playlist first. For a release that is less likely to be flagged by Windows security tools, use a trusted code-signing certificate:

```powershell
.\scripts\build-desktop.ps1 -Target windows -Installer -CertificateThumbprint YOUR_CERTIFICATE_THUMBPRINT
```

Code signing is required for trustworthy public distribution. Do not distribute a binary that your antivirus has quarantined.

### Linux

Build and test on Linux itself. Install Python 3.10 or newer plus a GTK or Qt webview backend, then create a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-build.txt
pip install 'pywebview[gtk]'
python trim_playlist_app.py
```

For Ubuntu and Debian GTK dependencies, install `python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-webkit2-4.1` before running the app. Build the native folder release with:

```bash
pwsh ./scripts/build-desktop.ps1 -Target linux
```

Package the resulting folder with the target distribution's standard format, such as AppImage, Flatpak, `.deb`, or `.rpm`.

### macOS

Build and test on a Mac. Use a Python virtual environment and install the requirements:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-build.txt
pip install pyobjc-core pyobjc-framework-Cocoa pyobjc-framework-Quartz pyobjc-framework-WebKit pyobjc-framework-security
python trim_playlist_app.py
```

Run `pwsh ./scripts/build-desktop.ps1 -Target macos` for a native PyInstaller folder build. A public macOS release also needs Apple code signing and notarization.

### NixOS and other Linux distributions

Run the source build in a Nix development shell that provides Python, GTK, GObject introspection, and WebKitGTK. Then create the Python virtual environment and install the project requirements as in the Linux instructions. NixOS package names can change with the selected `nixpkgs` revision, so use your distribution's current packages for `python3`, `gtk3`, `gobject-introspection`, and `webkitgtk`.

Other Linux distributions follow the same pattern: install Python and the system packages required by the GTK or Qt pywebview backend, then use the Linux commands above.

### Android APK

Open the [Android](Android/README.md) folder in Android Studio with JDK 17. Build the release APK, then sign it with a release keystore. The checked personal-test output is:

```text
Android/dist/signed/app-release-debugSigned.apk
```

It is signed with an Android debug key, so replace that with a private release key before publishing or relying on updates.

### iOS IPA

Use the [iOS](iOS/README.md) workspace with [Windows IPA Builder](https://github.com/iamjrmh/WindowsIPABuilder):

```powershell
cd iOS
.\build-ipa.ps1 -BuilderCli C:\path\to\ipabuilder-cli.exe
```

The output is `iOS/dist/Trim Playlist.ipa`. Import it into [iLoader](https://github.com/DragoonT/iloader), sign in with your Apple ID, and use **Import any IPA** to sign and install it on your connected iPhone or iPad. This IPA is for personal sideloading. App Store distribution needs a Mac, Xcode, and an Apple Developer signing account.

4. For command-line download and trimming work, use a copy of an example setlist:

   ```powershell
   copy setlist.youtube.example.json setlist.json
   python cut_url.py --config setlist.json
   ```

Do not commit `setlist.json`, cookie files, downloaded media, or private playlist data.

## Before opening a pull request

- Keep changes focused on one user-facing fix or improvement.
- Run syntax and UI checks relevant to your change:

  ```powershell
  python -m py_compile app_paths.py trim_playlist_app.py playlist_server.py
  python tests/check_download_ui.py
  ```

- Test the desktop app manually when changing playback, playlist controls, downloads, cookies, or online media.
- Update `README.md` when a workflow, requirement, or installation step changes.

## Pull requests

Describe the problem, the final behavior, and the validation you performed. Never include cookies, account sessions, private URLs, downloaded files, or other personal data in a pull request, issue, screenshot, or log.

## Reporting bugs

Include the operating system, the app version or commit, the action that caused the problem, and non-sensitive error text. Remove account names, cookies, and private media URLs before posting.
