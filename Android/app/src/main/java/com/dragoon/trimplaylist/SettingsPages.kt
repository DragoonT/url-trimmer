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

internal fun MainActivity.checkForUpdate() {
        if (updateChecking) return
        updateChecking = true
        latestLine = "Checking…"
        if (history.last() == Page.SETTINGS) show()
        thread {
            var line = "Latest version unavailable"
            var apk = ""
            try {
                val json = JSONObject(URL("https://dragoont.github.io/url-trimmer/latest.json").readText())
                val version = json.optString("version")
                if (version.isNotBlank()) {
                    line = "Latest version $version"
                    if (newerVersion(version, BuildConfig.VERSION_NAME)) apk = json.optString("android")
                }
            } catch (_: Exception) {
            }
            runOnUiThread {
                updateChecking = false
                latestLine = line
                latestApk = apk
                if (history.last() == Page.SETTINGS) show()
            }
        }
    }

internal fun MainActivity.downloadUpdate(url: String) {
        val request = DownloadManager.Request(Uri.parse(url))
            .setMimeType("application/vnd.android.package-archive")
            .setTitle("Trim Playlist update")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "TrimPlaylist-update.apk")
        updateDownloadId = getSystemService(DownloadManager::class.java).enqueue(request)
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
        if (track == null || (!engine.ready && !engine.playing())) {
            if (noteKey.isNotEmpty() || serviceUp) {
                noteKey = ""
                serviceUp = false
                session.isActive = false
                stopService(Intent(this, PlaybackService::class.java))
            }
            return
        }
        val playing = engine.playing()
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
        session.setPlaybackState(
            PlaybackState.Builder()
                .setActions(
                    PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or
                        PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_SEEK_TO
                )
                .setState(if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED, engine.position().toLong(), if (playing) 1f else 0f)
                .build()
        )
        session.isActive = true
        val key = "${track.uri}|$playing|$line"
        if (!force && key == noteKey) return
        noteKey = key
        pushNotification(track.title, line, playing)
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
        if (!notesBlocked() || notesDialog?.isShowing == true) return
        notesDialog = AlertDialog.Builder(this)
            .setTitle("Notifications are off")
            .setMessage("Turn notifications on to show the playing song on the shade and the lock screen.")
            .setPositiveButton("Turn on") { _, _ ->
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
            }
            .setNegativeButton("Not now", null)
            .show()
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

