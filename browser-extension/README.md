# Trim Playlist Account Connector

This connector is optional: Trim Playlist can download account-restricted content using a valid imported cookie file without this extension. See the project README for that workflow.

The connector is awaiting Chrome Web Store review. For personal use before publication, run `dist/personal-setup/TrimPlaylistPersonalSetup.exe` and choose **Prepare personal extension**, or use this source folder directly. Keep the selected folder on your computer while the unpacked extension is installed.

1. In Helium (or another Chromium browser), open its Extensions page.
2. Enable Developer mode, choose **Load unpacked**, and select `browser-extension-personal/` (prepared by the setup tool) or this `browser-extension/` source folder containing `manifest.json`. If the connection page is already open, reload it so the browser can load the connector into that page. The Get cookies.txt LOCALLY extension is separate and does not provide this connection.
3. Restart Trim Playlist with the updated executable, or run `python pc/server/playlist_server.py`.
4. Under Trim URL, choose **Sign in to platform** and pick a platform.
5. Sign in on the platform page. The connector saves that platform’s session in the project’s `cookies/` folder and closes the two tabs it opened.
6. The app shows **Signed in (saved session)** and selects the new cookie file. Reconnect to refresh an expired session.

Supports YouTube, Facebook, Instagram, X/Twitter, TikTok, and Twitch. YouTube checks the page’s logged-in flag; the other platforms detect their authentication cookies. This indicates a saved browser session, not a guarantee every download will work. Passwords are entered only on the platform. **Disconnect** removes the app’s saved cookie file; it does not log you out of your browser.

The extension reads only the selected platform’s cookies, in the cookie store of its sign-in tab, after you start a connection. They are sent only to the local Trim Playlist server using a one-use token that expires after ten minutes. Cookie files are account credentials: keep them private; they are ignored by Git. Nothing is uploaded to an external service. Local account connection is disabled for LAN clients.

Firefox does not load this Chromium Manifest V3 extension as-is. This build targets Helium and other compatible Chromium browsers without hardcoding which browser opens.
