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


internal fun MainActivity.playerPage(): View {
        val track = library.current().tracks.getOrNull(library.currentTrack)
        val root = column(px(18), px(12), px(18), px(16)).apply { setBackgroundColor(cardBg()) }
        val top = row().apply { gravity = Gravity.CENTER_VERTICAL }
        top.addView(ghost("⌄") { onBackPressed() })
        top.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        if (track?.video == true && !fullscreen) {
            top.addView(ghost(playbackQuality) { qualityMenu() })
            top.addView(ghost("Fullscreen") { fullscreen = true; show() })
        }
        root.addView(top)
        if (fullscreen && track?.video == true) {
            videoHost = videoFrame(MATCH)
            root.addView(videoHost, LinearLayout.LayoutParams(MATCH, 0, 1f))
            root.addView(ghost("Close") { fullscreen = false; show() })
            return root
        }
        if (track?.video == true) {
            videoHost = videoFrame(px(280))
            root.addView(videoHost, LinearLayout.LayoutParams(MATCH, px(280)).apply { topMargin = px(12) })
        } else {
            val art = RecordView(this)
            root.addView(art, LinearLayout.LayoutParams(MATCH, px(280)).apply { topMargin = px(12) })
        }
        root.addView(spaceH(18))
        root.addView(label(track?.title ?: "Select a track", 22f, ink(), true))
        playerArtist = muted(track?.let { trackLine(it) } ?: " ")
        root.addView(playerArtist)
        val times = row().apply { gravity = Gravity.CENTER_VERTICAL; setPadding(0, px(16), 0, 0) }
        playerTime = muted("0:00")
        playerTotal = muted("0:00")
        playerSeek = SeekBar(this).apply {
            max = 1000
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(bar: SeekBar, value: Int, fromUser: Boolean) {
                    if (fromUser) playerTime?.text = formatTime((value / 1000f * engine.duration()).toInt())
                }
                override fun onStartTrackingTouch(bar: SeekBar) { seeking = true }
                override fun onStopTrackingTouch(bar: SeekBar) {
                    seeking = false
                    engine.seek((bar.progress / 1000f * engine.duration()).toInt())
                }
            })
        }
        times.addView(playerTime)
        times.addView(playerSeek, LinearLayout.LayoutParams(0, WRAP, 1f))
        times.addView(playerTotal)
        root.addView(times)
        val controls = row().apply { gravity = Gravity.CENTER; setPadding(0, px(8), 0, 0) }
        controls.addView(iconButton(if (library.shuffle) "shuffle" else "shuffle", false, library.shuffle) {
            library.shuffle = !library.shuffle
            library.save()
            show()
        })
        controls.addView(iconButton("prev", false, false) { step(-1) })
        playerPlay = iconButton(if (engine.playing()) "pause" else "play", true, false) { togglePlay() }
        controls.addView(playerPlay)
        controls.addView(iconButton("next", false, false) { step(1) })
        controls.addView(iconButton(if (library.repeatMode == 2) "repeat1" else "repeat", false, library.repeatMode != 0) {
            library.repeatMode = (library.repeatMode + 1) % 3
            library.save()
            show()
        })
        root.addView(controls)
        root.addView(View(this), LinearLayout.LayoutParams(1, 0, 1f))
        root.addView(TextView(this).apply {
            text = "QUEUE"
            setTextColor(ink())
            gravity = Gravity.CENTER
            textSize = 13f
            setPadding(0, px(12), 0, px(8))
            setOnClickListener { open(Page.QUEUE) }
        })
        return root
    }

internal fun MainActivity.queuePage(): View {
        val sheet = object : LinearLayout(this) {
            var startY = 0f
            var pulling = false
            lateinit var scroller: ScrollView
            var fromHeader = false
            override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        startY = ev.rawY
                        pulling = false
                        fromHeader = ev.y < scroller.top
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dy = ev.rawY - startY
                        if (!pulling && fromHeader && dy > px(12)) {
                            pulling = true
                            return true
                        }
                    }
                }
                return super.onInterceptTouchEvent(ev)
            }
            override fun onTouchEvent(event: MotionEvent): Boolean {
                translationY = (event.rawY - startY).coerceAtLeast(0f)
                if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) {
                    if (translationY > px(120)) closeQueue() else animate().translationY(0f).setDuration(180).start()
                    pulling = false
                }
                return true
            }
        }
        sheet.orientation = LinearLayout.VERTICAL
        sheet.setBackgroundColor(sheetBg())
        sheet.setPadding(px(16), px(10), px(16), px(12))
        val handle = View(this).apply { background = rounded(Color.rgb(190, 190, 190), 4) }
        sheet.addView(handle, LinearLayout.LayoutParams(px(46), px(5)).apply { gravity = Gravity.CENTER_HORIZONTAL; bottomMargin = px(12) })
        sheet.addView(label("QUEUE", 16f, ink(), true).apply { gravity = Gravity.CENTER })
        val from = row().apply { gravity = Gravity.CENTER_VERTICAL; setPadding(0, px(12), 0, px(8)) }
        val fromText = column(0, 0, 0, 0)
        fromText.addView(muted("Playing from"))
        fromText.addView(label(library.current().name, 18f, ink(), true))
        from.addView(fromText, LinearLayout.LayoutParams(0, WRAP, 1f))
        sheet.addView(from)
        val scroll = ScrollView(this)
        val songs = column(0, 0, 0, px(12))
        library.current().tracks.forEachIndexed { index, track ->
            songs.addView(trackRow(index, track, songs, scroll, selectedBg()))
        }
        scroll.addView(songs)
        sheet.scroller = scroll
        sheet.addView(scroll, LinearLayout.LayoutParams(MATCH, 0, 1f))
        return sheet
    }

internal fun MainActivity.closeQueue() {
        val sheet = if (body.childCount > 0) body.getChildAt(body.childCount - 1) else return
        sheet.animate().translationY(resources.displayMetrics.heightPixels.toFloat()).setDuration(180).withEndAction {
            if (history.lastOrNull() == Page.QUEUE) {
                history.removeLast()
                motion = 0
                show()
            }
        }.start()
    }

internal fun MainActivity.refreshMini() {
        miniWrap.removeAllViews()
        miniTitle = null
        miniPlay = null
        val page = history.last()
        val track = library.current().tracks.getOrNull(library.currentTrack)
        if (track == null || page == Page.PLAYER || page == Page.QUEUE || page == Page.URL || page == Page.ONLINE || page == Page.EDITOR || page == Page.SIGNIN || page == Page.SETTINGS || page == Page.ABOUT) return
        val bar = row().apply {
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(if (dark) Color.rgb(58, 58, 58) else Color.rgb(226, 228, 232))
            setPadding(px(10), px(8), px(10), px(8))
            setOnClickListener { open(Page.PLAYER) }
        }
        bar.addView(RecordView(this).apply { layoutParams = LinearLayout.LayoutParams(px(42), px(42)) })
        val text = column(px(10), 0, 0, 0)
        miniTitle = label(track.title, 14f, ink(), false)
        text.addView(miniTitle)
        text.addView(lineView(track))
        bar.addView(text, LinearLayout.LayoutParams(0, WRAP, 1f))
        bar.addView(iconButton("prev", false, false) { step(-1) }.apply { layoutParams = LinearLayout.LayoutParams(px(36), px(36)) })
        miniPlay = iconButton(if (engine.playing()) "pause" else "play", false, false) { togglePlay() }.apply {
            layoutParams = LinearLayout.LayoutParams(px(36), px(36))
        }
        bar.addView(miniPlay)
        bar.addView(iconButton("next", false, false) { step(1) }.apply { layoutParams = LinearLayout.LayoutParams(px(36), px(36)) })
        miniWrap.addView(bar)
    }

internal fun MainActivity.refreshClock() {
        val duration = engine.duration()
        val position = engine.position()
        if (!seeking && duration > 0) {
            playerSeek?.progress = (position * 1000L / duration).toInt().coerceIn(0, 1000)
            playerTime?.text = formatTime(position)
            playerTotal?.text = formatTime(duration)
        }
        val playing = engine.playing()
        playerPlay?.kind = if (playing) "pause" else "play"
        playerPlay?.invalidate()
        miniPlay?.kind = if (playing) "pause" else "play"
        miniPlay?.invalidate()
        val track = library.current().tracks.getOrNull(library.currentTrack)
        if (track != null) playerArtist?.text = trackLine(track)
        if (playing) library.positionMs = position
        syncSession(false)
    }

internal fun MainActivity.refreshChrome() {
        refreshClock()
        refreshMini()
    }

internal fun MainActivity.play(index: Int, seekMs: Int) {
        warnNotesOff()
        val track = library.current().tracks.getOrNull(index) ?: return
        if (track.uri.isBlank()) {
            toast("Choose this file again")
            return
        }
        if (track.kind == "online" && (track.uri.contains("youtube.com") || track.uri.contains("youtu.be"))) {
            if (streamBusy) return
            streamBusy = true
            toast("Opening stream…")
            val audio = !track.video
            val cookie = authCookieHeader("www.youtube.com")
            Thread {
                try {
                    val stream = PhoneDownload.playback(track.uri, audio, cookie)
                    runOnUiThread {
                        streamBusy = false
                        beginPlay(index, Uri.parse(stream), track.video, seekMs)
                    }
                } catch (error: Exception) {
                    runOnUiThread {
                        streamBusy = false
                        toast(error.message ?: "Couldn't open that stream")
                    }
                }
            }.start()
            return
        }
        beginPlay(index, Uri.parse(track.uri), track.video, seekMs)
    }

internal fun MainActivity.beginPlay(index: Int, uri: Uri, video: Boolean, seekMs: Int) {
        library.currentTrack = index
        library.positionMs = seekMs
        library.save()
        if (video && engine.surface == null) engine.queue(uri, seekMs) else engine.play(uri, video, seekMs)
        show()
    }

internal fun MainActivity.togglePlay() {
        if (engine.ready) {
            engine.toggle()
            refreshChrome()
            return
        }
        val index = if (library.currentTrack >= 0) library.currentTrack else 0
        if (library.current().tracks.isEmpty()) toast("Add a song first") else play(index, library.positionMs)
    }

internal fun MainActivity.step(direction: Int) {
        val tracks = library.current().tracks
        if (tracks.isEmpty()) return
        val start = if (library.currentTrack >= 0) library.currentTrack else 0
        if (direction < 0 && engine.position() > 3000) {
            engine.seek(0)
            return
        }
        val next = if (library.shuffle && tracks.size > 1) {
            var pick = start
            while (pick == start) pick = tracks.indices.random()
            pick
        } else {
            val candidate = start + direction
            when {
                candidate in tracks.indices -> candidate
                library.repeatMode == 1 -> if (direction > 0) 0 else tracks.lastIndex
                else -> return
            }
        }
        play(next, 0)
    }

internal fun MainActivity.onTrackEnded() {
        if (library.repeatMode == 2 && library.currentTrack >= 0) play(library.currentTrack, 0)
        else {
            val last = library.currentTrack >= library.current().tracks.lastIndex && !library.shuffle
            if (last && library.repeatMode == 0) {
                engine.ready = false
                library.positionMs = 0
                refreshChrome()
            } else step(1)
        }
    }

internal fun MainActivity.qualityMenu() {
        val options = arrayOf("Source", "1080p", "720p", "480p", "360p")
        AlertDialog.Builder(this).setTitle("Quality").setItems(options) { _, which ->
            playbackQuality = options[which]
            toast(if (which == 0) "Playing the file's own quality" else "This file has one copy. Source is its quality.")
            show()
        }.show()
    }

internal fun MainActivity.videoFrame(height: Int): FrameLayout {
        val frame = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        val texture = TextureView(this).apply {
            surfaceTextureListener = object : TextureView.SurfaceTextureListener {
                override fun onSurfaceTextureAvailable(st: android.graphics.SurfaceTexture, w: Int, h: Int) {
                    engine.attach(Surface(st))
                }
                override fun onSurfaceTextureSizeChanged(st: android.graphics.SurfaceTexture, w: Int, h: Int) = Unit
                override fun onSurfaceTextureDestroyed(st: android.graphics.SurfaceTexture): Boolean {
                    engine.detach()
                    return true
                }
                override fun onSurfaceTextureUpdated(st: android.graphics.SurfaceTexture) = Unit
            }
        }
        frame.addView(texture, FrameLayout.LayoutParams(MATCH, if (height == MATCH) MATCH else height))
        return frame
    }

internal fun MainActivity.lineView(track: Track): TextView {
        val view = muted(trackLine(track))
        metaLabels.add(track.uri to view)
        return view
    }

internal fun MainActivity.trackLine(track: Track): String {
        val known = metaCache[track.uri]
        if (known == null) ensureMeta(track)
        return formatMeta(track, known)
    }

internal fun MainActivity.formatMeta(track: Track, known: Meta?): String {
        val artist = known?.artist ?: guessArtist(track.title)
        val stored = known?.durationMs ?: 0
        val duration = if (stored > 0) stored else if (sameTrack(track)) engine.duration() else 0
        return if (duration > 0) "$artist · ${formatTime(duration)}" else artist
    }

internal fun MainActivity.sameTrack(track: Track) = library.current().tracks.getOrNull(library.currentTrack)?.uri == track.uri

internal fun MainActivity.guessArtist(title: String): String {
        val name = title.substringBeforeLast('.')
        val parts = name.split(" - ").map { it.trim() }.filter { it.isNotEmpty() }
        val head = parts.firstOrNull().orEmpty()
        return when {
            parts.size >= 3 && head.all { it.isDigit() } -> parts[1]
            parts.size >= 2 && !head.all { it.isDigit() } -> parts[0]
            else -> "Unknown artist"
        }
    }

internal fun MainActivity.ensureMeta(track: Track) {
        if (track.uri.isBlank() || metaLoading.contains(track.uri) || metaCache.containsKey(track.uri)) return
        metaLoading.add(track.uri)
        thread(name = "track-meta") {
            val loaded = readMeta(track)
            runOnUiThread {
                metaCache[track.uri] = loaded
                val line = formatMeta(track, loaded)
                metaLabels.filter { it.first == track.uri && it.second.isAttachedToWindow }.forEach { it.second.text = line }
                if (sameTrack(track)) {
                    playerArtist?.text = line
                    syncSession(true)
                }
            }
        }
    }

internal fun MainActivity.readMeta(track: Track): Meta {
        val guess = guessArtist(track.title)
        return try {
            val retriever = MediaMetadataRetriever()
            val uri = Uri.parse(track.uri)
            when {
                track.uri.startsWith("content:") || track.uri.startsWith("file:") -> retriever.setDataSource(this, uri)
                track.uri.startsWith("/") -> retriever.setDataSource(track.uri)
                track.uri.startsWith("http://") || track.uri.startsWith("https://") -> retriever.setDataSource(track.uri, HashMap())
                else -> retriever.setDataSource(this, uri)
            }
            val artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)?.takeIf { it.isNotBlank() }
                ?: retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST)?.takeIf { it.isNotBlank() }
                ?: guess
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toIntOrNull() ?: 0
            retriever.release()
            Meta(artist, duration)
        } catch (_: Exception) {
            Meta(guess, 0)
        }
    }

