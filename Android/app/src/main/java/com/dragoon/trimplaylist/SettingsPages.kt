package com.dragoon.trimplaylist

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Context.MODE_PRIVATE
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.provider.OpenableColumns
import android.provider.Settings
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.MotionEvent
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.net.URL
import kotlin.concurrent.thread
import org.json.JSONObject


internal fun MainActivity.newerVersion(remote: String, local: String): Boolean {
        fun parts(value: String) = value.split(".").map { it.toIntOrNull() ?: 0 }
        val left = parts(remote)
        val right = parts(local)
        val width = maxOf(left.size, right.size)
        for (index in 0 until width) {
            val diff = left.getOrElse(index) { 0 } - right.getOrElse(index) { 0 }
            if (diff != 0) return diff > 0
        }
        return false
    }

/** Throttled auto-check: forced on every open/start, and every ~45s while the app stays open. */
internal fun MainActivity.maybeCheckUpdate(force: Boolean) {
        val now = android.os.SystemClock.elapsedRealtime()
        val gap = if (force) 2_500L else 45_000L
        if (now - lastUpdateCheckMs < gap) return
        lastUpdateCheckMs = now
        checkForUpdate(prompt = true)
    }

internal fun MainActivity.fetchLatestJson(): JSONObject? {
        val stamp = System.currentTimeMillis()
        val urls = listOf(
            "https://dragoont.github.io/url-trimmer/latest.json?t=$stamp",
            "https://raw.githubusercontent.com/DragoonT/url-trimmer/main/docs/latest.json?t=$stamp",
        )
        for (url in urls) {
            try {
                val connection = (URL(url).openConnection() as java.net.HttpURLConnection).apply {
                    connectTimeout = 12000
                    readTimeout = 12000
                    instanceFollowRedirects = true
                    setRequestProperty("Cache-Control", "no-cache")
                    setRequestProperty("Pragma", "no-cache")
                    setRequestProperty("User-Agent", "TrimPlaylist/${BuildConfig.VERSION_NAME}")
                }
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                connection.disconnect()
                if (body.isNotBlank()) return JSONObject(body)
            } catch (_: Exception) {
            }
        }
        return null
    }

internal fun MainActivity.checkForUpdate(prompt: Boolean = false) {
        if (updateChecking) return
        updateChecking = true
        latestLine = "Checking…"
        if (history.lastOrNull() == Page.SETTINGS) show()
        thread {
            var line = "Latest version unavailable"
            var apk = ""
            var version = ""
            try {
                val json = fetchLatestJson()
                if (json != null) {
                    version = json.optString("version")
                    if (version.isNotBlank()) {
                        line = "Latest version $version"
                        if (newerVersion(version, BuildConfig.VERSION_NAME)) {
                            apk = json.optString("android")
                        }
                    }
                }
            } catch (_: Exception) {
            }
            runOnUiThread {
                updateChecking = false
                latestLine = line
                latestApk = apk
                latestVersion = version
                if (history.lastOrNull() == Page.SETTINGS) show()
                if (prompt && apk.isNotBlank()) offerUpdatePopup(version, apk)
            }
        }
    }

internal fun MainActivity.offerUpdatePopup(version: String, apk: String) {
        if (isFinishing || isDestroyed || apk.isBlank() || updateBusy) return
        if (appModal != null) return
        val label = version.ifBlank { "a newer build" }
        appConfirm(
            title = "Update available",
            message = "Trim Playlist $label is ready. You are on ${BuildConfig.VERSION_NAME}.",
            confirmLabel = "Update",
            cancelLabel = "Later",
            onConfirm = { downloadUpdate(apk) },
        )
    }

/** In-app update: download the APK inside the app, then hand it to PackageInstaller. */
internal fun MainActivity.downloadUpdate(url: String) {
        if (updateBusy) {
            toast("Update already in progress")
            return
        }
        if (url.isBlank() || !url.startsWith("https://")) {
            toast("Update link unavailable")
            return
        }
        // Only accept the project's own hosted APK / GitHub release assets.
        val host = Uri.parse(url).host.orEmpty().lowercase()
        if (host != "dragoont.github.io" && host != "github.com" && !host.endsWith(".githubusercontent.com")) {
            toast("Update link not trusted")
            return
        }
        updateBusy = true
        downloadCleared = false
        reportDownload("Downloading update · 0%", 0f)
        toast("Downloading update…")
        thread {
            val out = File(cacheDir, "TrimPlaylist-update.apk")
            try {
                val connection = URL(url).openConnection().apply {
                    connectTimeout = 20000
                    readTimeout = 60000
                }
                val total = connection.contentLengthLong
                connection.getInputStream().use { input ->
                    out.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        var read = 0L
                        while (true) {
                            val n = input.read(buffer)
                            if (n <= 0) break
                            output.write(buffer, 0, n)
                            read += n
                            val fraction = if (total > 0) (read.toFloat() / total.toFloat()) else 0.15f
                            reportDownload("Downloading update · ${(fraction * 100).toInt().coerceIn(0, 99)}%", fraction.coerceIn(0f, 0.99f))
                        }
                        output.flush()
                    }
                }
                if (!out.exists() || out.length() < 1024L) throw IllegalStateException("Update file incomplete")
                reportDownload("Installing update…", 1f)
                runOnUiThread { installUpdateApk(out) }
            } catch (error: Exception) {
                out.delete()
                updateBusy = false
                reportDownload(error.message ?: "Update download failed", 0f)
                runOnUiThread { toast(error.message ?: "Update download failed") }
            }
        }
    }

internal fun MainActivity.installUpdateApk(apk: File) {
        if (!apk.exists()) {
            updateBusy = false
            toast("Update file missing")
            return
        }
        if (!packageManager.canRequestPackageInstalls()) {
            pendingUpdateApk = apk.absolutePath
            updateBusy = false
            reportDownload("Allow installs, then return", 1f)
            toast("Allow installs from Trim Playlist, then return")
            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
            return
        }
        try {
            val installer = packageManager.packageInstaller
            val params = android.content.pm.PackageInstaller.SessionParams(
                android.content.pm.PackageInstaller.SessionParams.MODE_FULL_INSTALL,
            ).apply {
                setAppPackageName(packageName)
                if (Build.VERSION.SDK_INT >= 31) {
                    setRequireUserAction(android.content.pm.PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
                }
            }
            val sessionId = installer.createSession(params)
            installer.openSession(sessionId).use { session ->
                apk.inputStream().use { input ->
                    session.openWrite("update.apk", 0, apk.length()).use { output ->
                        input.copyTo(output)
                        session.fsync(output)
                    }
                }
                val callback = Intent(this, UpdateInstallReceiver::class.java)
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
                val pending = PendingIntent.getBroadcast(this, sessionId, callback, flags)
                session.commit(pending.intentSender)
            }
            reportDownload("Confirm install…", 1f)
            toast("Confirm the install prompt")
        } catch (error: Exception) {
            toast(error.message ?: "Couldn't start install")
            reportDownload(error.message ?: "Couldn't start install", 0f)
        } finally {
            updateBusy = false
            placeDownload()
        }
    }

internal fun MainActivity.settingsPage(): View {
        val root = column(px(16), px(18), px(16), px(24)).apply { setBackgroundColor(pageBg()) }
        root.addView(titleBar("Settings"))
        root.addView(spaceH(18))
        root.addView(label("Theme", 14f, soft(), false))
        val themes = row().apply { setPadding(0, px(8), 0, 0) }
        themes.addView(pill("Dark", dark) { chooseTheme(true) })
        themes.addView(space(8))
        themes.addView(pill("Light", !dark) { chooseTheme(false) })
        root.addView(themes)
        root.addView(spaceH(18))
        root.addView(label("Notification", 14f, soft(), false))
        root.addView(muted("Show the playing song on the shade and the lock screen."))
        root.addView(pill(if (notesOn) "Notifications on" else "Notifications off", notesOn) {
            notesOn = !notesOn
            getSharedPreferences("trim-playlist", MODE_PRIVATE).edit().putBoolean("notes", notesOn).apply()
            if (!notesOn) {
                noteKey = ""
                serviceUp = false
                session.isActive = false
                stopService(Intent(this, PlaybackService::class.java))
            } else syncSession(true)
            show()
        })
        root.addView(spaceH(18))
        root.addView(label("Update", 14f, soft(), false))
        root.addView(muted("This version ${BuildConfig.VERSION_NAME}"))
        root.addView(muted(latestLine.ifBlank { "Latest version" }))
        if (latestApk.isNotBlank()) root.addView(pill("Update", true) { downloadUpdate(latestApk) })
        root.addView(pill("Check for update", false) { checkForUpdate() })
        if (latestLine.isBlank() && !updateChecking) root.post { checkForUpdate() }
        return root
    }

internal fun MainActivity.chooseTheme(nextDark: Boolean) {
        if (dark == nextDark) return
        dark = nextDark
        getSharedPreferences("trim-playlist", MODE_PRIVATE).edit().putBoolean("dark", dark).apply()
        paintNav()
        applyBars()
        show()
    }

internal fun MainActivity.aboutPage(): View {
        val root = column(px(16), px(18), px(16), px(24)).apply { setBackgroundColor(pageBg()) }
        root.addView(titleBar("About"))
        root.addView(spaceH(18))
        root.addView(label("Trim Playlist", 28f, ink(), true))
        root.addView(spaceH(8))
        root.addView(muted("Play the songs you keep on this phone. Trim URL saves the file on the phone. Add it to a playlist yourself."))
        root.addView(spaceH(16))
        root.addView(solid("GitHub") {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/DragoonT/url-trimmer")))
        })
        return root
    }

internal fun MainActivity.syncSession(force: Boolean) {
        val track = library.current().tracks.getOrNull(library.currentTrack)
        val bridging = trackSwitching || streamBusy
        if (track == null || (!engine.ready && !engine.playing() && !bridging)) {
            if (noteKey.isNotEmpty() || serviceUp) {
                noteKey = ""
                serviceUp = false
                session.isActive = false
                stopService(Intent(this, PlaybackService::class.java))
            }
            return
        }
        val playing = engine.playing()
        val buffering = bridging && !playing
        val line = formatMeta(track, metaCache[track.uri])
        val artist = line.substringBefore(" · ")
        val duration = engine.duration().toLong().takeIf { it > 0 } ?: (metaCache[track.uri]?.durationMs?.toLong() ?: 0L)
        session.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, track.title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
                .putString(MediaMetadata.METADATA_KEY_ALBUM, library.current().name)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, duration)
                .putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, coverArt())
                .build()
        )
        val state = when {
            playing -> PlaybackState.STATE_PLAYING
            buffering -> PlaybackState.STATE_BUFFERING
            else -> PlaybackState.STATE_PAUSED
        }
        session.setPlaybackState(
            PlaybackState.Builder()
                .setActions(
                    PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or
                        PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_SEEK_TO
                )
                .setState(state, engine.position().toLong(), if (playing) 1f else 0f)
                .build()
        )
        session.isActive = true
        val key = "${track.uri}|$playing|$buffering|$line"
        if (!force && key == noteKey) return
        noteKey = key
        // Keep the foreground service alive across track gaps so Android does not kill audio.
        pushNotification(track.title, line, playing || buffering)
    }

internal fun MainActivity.notesBlocked(): Boolean {
        if (!notesOn) return true
        val manager = getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return true
        return Build.VERSION.SDK_INT >= 33 &&
            noteDenied &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
    }

internal fun MainActivity.ensureNotePermission() {
        if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        askedNotes = true
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 44)
    }

internal fun MainActivity.warnNotesOff() {
        if (!notesBlocked() || notesDialog != null || appModal != null) return
        appConfirm(
            title = "Notifications are off",
            message = "Turn notifications on to show the playing song on the shade and the lock screen.",
            confirmLabel = "Turn on",
            cancelLabel = "Not now",
            onConfirm = {
                notesOn = true
                getSharedPreferences("trim-playlist", MODE_PRIVATE).edit().putBoolean("notes", true).apply()
                val manager = getSystemService(NotificationManager::class.java)
                val needsPermission = Build.VERSION.SDK_INT >= 33 &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                if (!manager.areNotificationsEnabled()) {
                    startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                } else if (needsPermission) {
                    ensureNotePermission()
                } else {
                    syncSession(true)
                }
            },
        )
        notesDialog = appModal
    }

internal fun MainActivity.pushNotification(title: String, line: String, playing: Boolean) {
        if (!notesOn) {
            if (serviceUp) {
                serviceUp = false
                noteKey = ""
                stopService(Intent(this, PlaybackService::class.java))
            }
            return
        }
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            noteKey = ""
            return
        }
        ensureChannel()
        val open = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP).putExtra("openPlayer", true),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val note = Notification.Builder(this, "playback")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setLargeIcon(coverArt())
            .setContentTitle(title)
            .setContentText(line)
            .setOngoing(playing)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setContentIntent(open)
            .addAction(android.R.drawable.ic_media_previous, "Previous", serviceAction(PlaybackService.PREV))
            .addAction(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play, if (playing) "Pause" else "Play", serviceAction(PlaybackService.TOGGLE))
            .addAction(android.R.drawable.ic_media_next, "Next", serviceAction(PlaybackService.NEXT))
            .setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0, 1, 2))
            .build()
        val intent = Intent(this, PlaybackService::class.java).putExtra("note", note)
        val manager = getSystemService(NotificationManager::class.java)
        if (!serviceUp) {
            try {
                if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                serviceUp = true
            } catch (_: Exception) {
                manager.notify(PlaybackService.NOTE_ID, note)
            }
        } else {
            manager.notify(PlaybackService.NOTE_ID, note)
        }
    }

internal fun MainActivity.serviceAction(action: String): PendingIntent {
        val intent = Intent(this, PlaybackService::class.java).setAction(action)
        return PendingIntent.getService(this, action.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

internal fun MainActivity.ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel("playback", "Now playing", NotificationManager.IMPORTANCE_LOW)
        channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        channel.setSound(null, null)
        manager.createNotificationChannel(channel)
    }

internal fun MainActivity.coverArt(): Bitmap {
        val uri = library.current().tracks.getOrNull(library.currentTrack)?.uri
        if (!uri.isNullOrBlank()) artCache[uri]?.let { return it }
        cover?.let { return it }
        val size = 256
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.rgb(58, 58, 58)
        canvas.drawRect(0f, 0f, size.toFloat(), size.toFloat(), paint)
        paint.color = Color.rgb(24, 24, 24)
        canvas.drawCircle(size / 2f, size / 2f, size * 0.36f, paint)
        paint.color = Color.rgb(90, 90, 90)
        canvas.drawCircle(size / 2f, size / 2f, size * 0.14f, paint)
        paint.color = Color.rgb(16, 16, 16)
        canvas.drawCircle(size / 2f, size / 2f, size * 0.04f, paint)
        cover = bitmap
        return bitmap
    }

