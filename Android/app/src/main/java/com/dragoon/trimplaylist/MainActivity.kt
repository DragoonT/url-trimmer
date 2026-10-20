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

class MainActivity : Activity() {
    private enum class Page { LIST, DETAIL, PLAYER, QUEUE, URL, ONLINE, EDITOR, SIGNIN, SETTINGS, ABOUT }

    private lateinit var library: Library
    private lateinit var engine: Engine
    private lateinit var body: FrameLayout
    private lateinit var shell: FrameLayout
    private lateinit var miniWrap: LinearLayout
    private lateinit var downloadStrip: LinearLayout
    private lateinit var downloadTrack: FrameLayout
    private lateinit var downloadFill: View
    private lateinit var downloadLabel: TextView
    private var onlineType = 0
    private var onlineFormat = 0
    private var onlineDraft = ""
    private val onlineChoices = mutableListOf<Pair<String, String>>()
    private val onlinePicked = mutableSetOf<Int>()
    private var streamBusy = false
    private val downloadChoices = mutableListOf<Pair<String, String>>()
    private val downloadPicked = mutableSetOf<Int>()
    private var downloadChoiceUrl = ""
    private var downloadBusy = false
    private var downloadCleared = false
    private lateinit var navScrim: View
    private lateinit var navPanel: LinearLayout
    private val history = ArrayDeque<Page>()
    private var fullscreen = false
    private var seeking = false
    private var editorFile: File? = null
    private var downloadType = 0
    private var downloadMode = 0
    private var downloadFormat = 0
    private var downloadQuality = 0
    private var downloadAudio = 0
    private var downloadAuth = 2
    private var downloadPlatform = 0
    private var cookieName = ""
    private var draftUrl = ""
    private var draftName = ""
    private var draftStart = ""
    private var draftEnd = ""
    private var draftVolume = "1"
    private var playbackQuality = "Source"
    private var dark = true
    private var notesOn = true
    private var dragAnchor = 0f
    private val dragShift = HashMap<View, Int>()
    private var miniTitle: TextView? = null
    private var miniPlay: Glyph? = null
    private var playerSeek: SeekBar? = null
    private var playerTime: TextView? = null
    private var playerTotal: TextView? = null
    private var playerPlay: Glyph? = null
    private var playerArtist: TextView? = null
    private var videoHost: FrameLayout? = null
    private var motion = 0
    private var closingSheet = false
    private lateinit var session: MediaSession
    private var noteKey = ""
    private var askedNotes = false
    private var noteDenied = false
    private var notesDialog: AlertDialog? = null
    private var serviceUp = false
    private var cover: Bitmap? = null
    private val metaCache = HashMap<String, Meta>()
    private val metaLoading = HashSet<String>()
    private val metaLabels = ArrayList<Pair<String, TextView>>()
    private val ticker = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            refreshClock()
            ticker.postDelayed(this, 400)
        }
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        library = Library(this)
        val prefs = getSharedPreferences("trim-playlist", MODE_PRIVATE)
        dark = prefs.getBoolean("dark", true)
        notesOn = prefs.getBoolean("notes", true)
        downloadType = prefs.getInt("trim-type", 0)
        downloadMode = prefs.getInt("trim-mode", 0)
        downloadFormat = prefs.getInt("trim-format", 0)
        downloadQuality = prefs.getInt("trim-quality", 0)
        downloadAudio = prefs.getInt("trim-audio", 0)
        downloadAuth = prefs.getInt("trim-auth", 2)
        downloadPlatform = prefs.getInt("trim-platform", 0)
        cookieName = prefs.getString("trim-cookie", "") ?: ""
        draftUrl = prefs.getString("trim-url", "") ?: ""
        draftName = prefs.getString("trim-name", "") ?: ""
        draftStart = prefs.getString("trim-start", "") ?: ""
        draftEnd = prefs.getString("trim-end", "") ?: ""
        draftVolume = prefs.getString("trim-volume", "1") ?: "1"
        engine = Engine()
        engine.onChange = { refreshChrome() }
        session = MediaSession(this, "TrimPlaylist")
        session.setCallback(object : MediaSession.Callback() {
            override fun onPlay() { runOnUiThread { if (!engine.playing()) togglePlay() } }
            override fun onPause() { runOnUiThread { if (engine.playing()) togglePlay() } }
            override fun onSkipToNext() { runOnUiThread { step(1) } }
            override fun onSkipToPrevious() { runOnUiThread { step(-1) } }
            override fun onSeekTo(pos: Long) { runOnUiThread { engine.seek(pos.toInt()) } }
        })
        PlaybackBridge.onAction = { action ->
            runOnUiThread {
                when (action) {
                    PlaybackService.PREV -> step(-1)
                    PlaybackService.NEXT -> step(1)
                    PlaybackService.TOGGLE -> togglePlay()
                }
            }
        }
        history.add(Page.LIST)
        shell = FrameLayout(this).apply { setBackgroundColor(pageBg()) }
        body = FrameLayout(this)
        miniWrap = column(0, 0, 0, 0)
        val column = column(0, 0, 0, 0).apply { setBackgroundColor(pageBg()) }
        column.addView(body, LinearLayout.LayoutParams(MATCH, 0, 1f))
        downloadStrip = column(px(16), px(8), px(16), px(8)).apply {
            setBackgroundColor(cardBg())
            visibility = View.GONE
        }
        downloadLabel = muted(" ").apply { layoutParams = LinearLayout.LayoutParams(0, WRAP, 1f) }
        val clear = label("Clear", 13f, BRAND, true).apply {
            setPadding(px(8), 0, 0, 0)
            setOnClickListener { downloadCleared = true; downloadStrip.visibility = View.GONE }
        }
        val head = row()
        head.addView(downloadLabel)
        head.addView(clear)
        downloadTrack = FrameLayout(this).apply { setBackgroundColor(if (dark) Color.rgb(40, 44, 54) else Color.rgb(210, 214, 220)) }
        downloadFill = View(this).apply {
            setBackgroundColor(BRAND)
            pivotX = 0f
            scaleX = 0f
        }
        downloadTrack.addView(downloadFill, FrameLayout.LayoutParams(MATCH, MATCH))
        downloadStrip.addView(head)
        downloadStrip.addView(downloadTrack, LinearLayout.LayoutParams(MATCH, px(6)).apply { topMargin = px(6) })
        column.addView(downloadStrip)
        column.addView(miniWrap)
        shell.addView(column, FrameLayout.LayoutParams(MATCH, MATCH))
        buildNav()
        setContentView(shell)
        applyBars()
        show()
        ticker.post(tick)
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(updateReceiver, filter, RECEIVER_NOT_EXPORTED)
        else registerReceiver(updateReceiver, filter)
        if (notesOn) ensureNotePermission()
    }

    override fun onStop() {
        library.positionMs = engine.position()
        library.save()
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("openPlayer", false) && library.currentTrack >= 0 && history.last() != Page.PLAYER) {
            motion = 1
            history.add(Page.PLAYER)
            show()
        }
    }

    override fun onDestroy() {
        unregisterReceiver(updateReceiver)
        ticker.removeCallbacks(tick)
        PlaybackBridge.onAction = null
        noteKey = ""
        stopService(Intent(this, PlaybackService::class.java))
        session.release()
        engine.release()
        super.onDestroy()
    }

    private var updateDownloadId = -1L
    private var updateChecking = false
    private var latestLine = ""
    private var latestApk = ""

    private val updateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
            if (id != updateDownloadId) return
            if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                return
            }
            val uri = getSystemService(DownloadManager::class.java).getUriForDownloadedFile(id) ?: return
            startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        }
    }

    private fun newerVersion(remote: String, local: String): Boolean {
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

    private fun checkForUpdate() {
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

    private fun downloadUpdate(url: String) {
        val request = DownloadManager.Request(Uri.parse(url))
            .setMimeType("application/vnd.android.package-archive")
            .setTitle("Trim Playlist update")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "TrimPlaylist-update.apk")
        updateDownloadId = getSystemService(DownloadManager::class.java).enqueue(request)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 44) {
            noteDenied = grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED
            if (!noteDenied) syncSession(true)
        }
    }

    @Deprecated("Phone back stack")
    override fun onBackPressed() {
        if (navPanel.visibility == View.VISIBLE) {
            closeNav()
            return
        }
        if (fullscreen) {
            fullscreen = false
            show()
            return
        }
        if (history.size > 1) {
            closingSheet = history.last() == Page.PLAYER || history.last() == Page.QUEUE
            motion = -1
            history.removeLast()
            show()
            return
        }
        @Suppress("DEPRECATION")
        super.onBackPressed()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK || data == null) return
        if (requestCode == PICK_MEDIA) addPickedMedia(data)
        if (requestCode == PICK_COOKIE) importCookie(data.data)
    }

    private fun show() {
        playerSeek = null
        playerTime = null
        playerTotal = null
        playerPlay = null
        playerArtist = null
        videoHost = null
        metaLabels.clear()
        val page = history.last()
        val pageView = when (page) {
            Page.LIST -> listPage()
            Page.DETAIL -> detailPage()
            Page.PLAYER -> playerPage()
            Page.QUEUE -> queuePage()
            Page.URL -> urlPage()
            Page.ONLINE -> onlinePage()
            Page.EDITOR -> editorPage()
            Page.SIGNIN -> signInPage()
            Page.SETTINGS -> settingsPage()
            Page.ABOUT -> aboutPage()
        }
        val previous = if (body.childCount > 0) body.getChildAt(body.childCount - 1) else null
        val direction = motion
        val sheet = closingSheet
        motion = 0
        closingSheet = false
        body.addView(pageView, FrameLayout.LayoutParams(MATCH, MATCH))
        if (previous == null || direction == 0) {
            if (previous != null) body.removeView(previous)
        } else if (direction > 0 && (page == Page.PLAYER || page == Page.QUEUE)) {
            val travel = resources.displayMetrics.heightPixels.toFloat()
            pageView.translationY = travel
            pageView.animate().translationY(0f).setDuration(280).setInterpolator(DecelerateInterpolator()).withEndAction {
                body.removeView(previous)
            }.start()
        } else if (direction > 0) {
            val travel = resources.displayMetrics.widthPixels.toFloat()
            pageView.translationX = travel
            pageView.animate().translationX(0f).setDuration(240).withEndAction { body.removeView(previous) }.start()
        } else if (sheet) {
            body.removeView(pageView)
            body.addView(pageView, 0)
            previous.animate().translationY(resources.displayMetrics.heightPixels.toFloat()).setDuration(240).withEndAction {
                body.removeView(previous)
            }.start()
        } else {
            body.removeView(pageView)
            body.addView(pageView, 0)
            previous.animate().translationX(resources.displayMetrics.widthPixels.toFloat()).setDuration(220).withEndAction {
                body.removeView(previous)
            }.start()
        }
        refreshMini()
        placeDownload()
    }

    private fun open(page: Page) {
        motion = 1
        history.add(page)
        show()
    }

    private fun listPage(): View {
        val root = column(px(16), px(18), px(16), px(12)).apply { setBackgroundColor(pageBg()) }
        root.addView(titleBar("Trim Playlist"))
        val scroll = ScrollView(this)
        val list = column(0, px(12), 0, px(80))
        if (library.playlists.isEmpty()) list.addView(muted("No playlists yet."))
        library.playlists.forEachIndexed { index, playlist ->
            val row = row().apply {
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, px(10), 0, px(10))
                setOnClickListener {
                    library.selected = index
                    library.save()
                    open(Page.DETAIL)
                }
            }
            row.addView(RecordView(this).apply { layoutParams = LinearLayout.LayoutParams(px(56), px(56)) })
            val text = column(px(12), 0, 0, 0)
            text.addView(label(playlist.name, 16f, ink(), true))
            text.addView(muted("${playlist.tracks.size} song${if (playlist.tracks.size == 1) "" else "s"}"))
            row.addView(text, LinearLayout.LayoutParams(0, WRAP, 1f))
            row.addView(ghost("⋮") {
                playlistMenu(index)
            })
            list.addView(row)
        }
        scroll.addView(list)
        root.addView(scroll, LinearLayout.LayoutParams(MATCH, 0, 1f))
        val fab = label("+  New playlist", 16f, Color.BLACK, true).apply {
            background = rounded(Color.WHITE, 28)
            setPadding(px(18), px(12), px(18), px(12))
            setOnClickListener { createPlaylist() }
        }
        val fabRow = row().apply { gravity = Gravity.END }
        fabRow.addView(fab)
        root.addView(fabRow)
        return root
    }

    private fun detailPage(): View {
        val playlist = library.current()
        val root = column(px(16), px(12), px(16), px(8)).apply { setBackgroundColor(pageBg()) }
        val top = row().apply { gravity = Gravity.CENTER_VERTICAL }
        top.addView(ghost("←") { onBackPressed() })
        top.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        top.addView(ghost("⋮") { playlistMenu(library.selected) })
        root.addView(top)
        val head = row().apply { setPadding(0, px(8), 0, px(12)) }
        head.addView(RecordView(this).apply { layoutParams = LinearLayout.LayoutParams(px(108), px(108)) })
        val titles = column(px(14), 0, 0, 0)
        titles.addView(label(playlist.name, 26f, ink(), true))
        titles.addView(muted("Playlist · ${playlist.tracks.size} songs"))
        head.addView(titles, LinearLayout.LayoutParams(0, WRAP, 1f))
        root.addView(head)
        val actions = row()
        actions.addView(iconPill("shuffle", "Shuffle", library.shuffle) {
            library.shuffle = !library.shuffle
            library.save()
            if (playlist.tracks.isNotEmpty()) play(if (library.shuffle) playlist.tracks.indices.random() else 0, 0)
            show()
        })
        actions.addView(space(8))
        actions.addView(iconPill("play", "Play", true) {
            if (playlist.tracks.isEmpty()) toast("Add a song first") else play(0, 0)
        })
        root.addView(actions)
        val scroll = ScrollView(this)
        val songs = column(0, px(12), 0, px(8))
        if (playlist.tracks.isEmpty()) songs.addView(muted("No songs yet. Use ⋮ to add files or an online song."))
        playlist.tracks.forEachIndexed { index, track ->
            songs.addView(trackRow(index, track, songs, scroll, selectedBg()))
        }
        scroll.addView(songs)
        root.addView(scroll, LinearLayout.LayoutParams(MATCH, 0, 1f))
        return root
    }

    private fun playerPage(): View {
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

    private fun queuePage(): View {
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

    private fun closeQueue() {
        val sheet = if (body.childCount > 0) body.getChildAt(body.childCount - 1) else return
        sheet.animate().translationY(resources.displayMetrics.heightPixels.toFloat()).setDuration(180).withEndAction {
            if (history.lastOrNull() == Page.QUEUE) {
                history.removeLast()
                motion = 0
                show()
            }
        }.start()
    }

    private fun paintChoices(parent: LinearLayout, choices: List<Pair<String, String>>, picked: Set<Int>) {
        for (i in 0 until parent.childCount) {
            val child = parent.getChildAt(i) as? TextView ?: continue
            val index = child.tag as? Int ?: continue
            if (index !in choices.indices) continue
            val on = index in picked
            child.text = if (on) "✓  ${choices[index].first}" else "○  ${choices[index].first}"
            child.background = rounded(if (on) selectedBg() else fieldBg(), 10)
        }
    }

    private fun urlPage(): View {
        val scroll = ScrollView(this).apply { setBackgroundColor(pageBg()) }
        val form = column(px(16), px(16), px(16), px(24))
        form.addView(titleBar("Trim URL"))
        form.addView(ghost("Back to playlist") { history.clear(); history.add(Page.LIST); show() })
        drop(form, "Download type", listOf("Single video", "Entire playlist"), downloadType) {
            downloadType = it
            downloadChoices.clear()
            downloadPicked.clear()
            downloadChoiceUrl = ""
            saveTrim()
            show()
        }
        form.addView(caption("Video URL"))
        val url = field("https://…").remember(draftUrl) {
            if (it != draftUrl) {
                downloadChoices.clear()
                downloadPicked.clear()
                downloadChoiceUrl = ""
            }
            draftUrl = it
        }
        form.addView(url)
        drop(form, "Mode", listOf("Full download", "Trim"), if (downloadType == 1) 0 else downloadMode) {
            downloadMode = it
            if (it == 1 && downloadPicked.size > 1) {
                val keep = downloadPicked.minOrNull()
                downloadPicked.clear()
                if (keep != null) downloadPicked.add(keep)
            }
            saveTrim()
            show()
        }
        drop(form, "Format", listOf("MP4 video", "MP3 music"), downloadFormat) { downloadFormat = it; saveTrim(); show() }
        if (downloadFormat == 0) drop(form, "Video quality", listOf("Best available", "1080", "720", "480", "360"), downloadQuality) { downloadQuality = it; saveTrim() }
        else drop(form, "MP3 quality", listOf("Best quality (VBR)", "320 kbps", "256 kbps", "192 kbps", "128 kbps", "96 kbps", "64 kbps"), downloadAudio) { downloadAudio = it; saveTrim() }
        if (downloadType == 1) form.addView(muted("Playlist downloads always use Full mode and each video’s original title."))
        val name = field("Use original title").remember(draftName) { draftName = it }
        val start = field("0:00").remember(draftStart) { draftStart = it }
        val end = field("3:30").remember(draftEnd) { draftEnd = it }
        if (downloadType == 0 && downloadMode == 1) {
            form.addView(caption("Filename (optional)"))
            form.addView(name)
            form.addView(caption("Start"))
            form.addView(start)
            form.addView(caption("End"))
            form.addView(end)
            form.addView(muted("The saved file is cut from Start to End."))
        }
        drop(form, "Authentication", listOf("Cookie file", "Platform account", "No authentication"), downloadAuth) { downloadAuth = it; saveTrim(); show() }
        if (downloadAuth == 0) cookiePicker(form)
        if (downloadAuth == 1) platformPicker(form)
        form.addView(caption("Volume multiplier"))
        val volume = field("1").remember(draftVolume.ifBlank { "1" }) { draftVolume = it.ifBlank { "1" } }
        form.addView(volume)
        form.addView(muted("1 = original volume · 2 = boost"))
        form.addView(muted("The file stays in Downloads. Add it to a playlist from the playlist menu."))
        val picking = downloadType == 0 && downloadChoices.isNotEmpty()
        if (picking) {
            form.addView(spaceH(8))
            form.addView(muted(if (downloadMode == 1) "Choose one video. Nothing is downloaded until you continue." else "Choose the videos in this playlist. Nothing is downloaded until you continue."))
            downloadChoices.forEachIndexed { index, (title, _) ->
                val picked = index in downloadPicked
                form.addView(spaceH(6))
                form.addView(TextView(this).apply {
                    text = if (picked) "✓  $title" else "○  $title"
                    setTextColor(ink())
                    textSize = 16f
                    setPadding(px(12), px(12), px(12), px(12))
                    background = rounded(if (picked) selectedBg() else fieldBg(), 10)
                    tag = index
                    setOnClickListener {
                        if (downloadMode == 1) {
                            downloadPicked.clear()
                            downloadPicked.add(index)
                        } else if (index in downloadPicked) {
                            downloadPicked.remove(index)
                        } else {
                            downloadPicked.add(index)
                        }
                        paintChoices(form, downloadChoices, downloadPicked)
                    }
                })
            }
        }
        form.addView(spaceH(8))
        form.addView(solid(if (picking) "Download selected" else "Start download") {
            val entered = url.text.toString().trim()
            if (!entered.startsWith("http://") && !entered.startsWith("https://")) {
                toast("Enter a video or playlist URL")
                return@solid
            }
            if (downloadBusy) {
                toast("A download is already running")
                return@solid
            }
            saveTrim()
            val trimming = downloadType == 0 && downloadMode == 1
            val trimStart: Double
            val trimEnd: Double
            val trimName = draftName.trim()
            if (trimming) {
                try {
                    trimStart = clock(draftStart)
                    trimEnd = clock(draftEnd)
                } catch (error: Exception) {
                    toast(error.message ?: "Use seconds, MM:SS or HH:MM:SS")
                    return@solid
                }
                if (trimStart < 0 || trimEnd <= trimStart) {
                    toast("End must be after start")
                    return@solid
                }
            } else {
                trimStart = 0.0
                trimEnd = 0.0
            }
            val playlist = entered.contains("list=")
            if (downloadType == 0 && playlist) {
                if (downloadChoiceUrl != entered || downloadChoices.isEmpty()) {
                    loadDownloadChoices(entered)
                    return@solid
                }
                val chosen = downloadPicked.sorted().mapNotNull { downloadChoices.getOrNull(it)?.second }
                if (chosen.isEmpty()) toast("Select a video") else beginDownload(chosen, trimming, trimStart, trimEnd, trimName)
                return@solid
            }
            beginDownload(listOf(entered), trimming, trimStart, trimEnd, trimName)
        })
        scroll.addView(form)
        return scroll
    }

    private fun cookiePicker(form: LinearLayout) {
        val names = cookiesDir().listFiles()?.filter { it.extension.equals("txt", true) }?.map { it.name } ?: emptyList()
        val options = listOf("No cookies") + names
        val selected = options.indexOf(cookieName).let { if (it < 0) 0 else it }
        drop(form, "Cookies", options, selected) { cookieName = if (it == 0) "" else options[it]; saveTrim() }
        form.addView(solid("Create new") { createCookie() })
    }

    private fun createCookie() {
        AlertDialog.Builder(this)
            .setTitle("Create cookie file")
            .setItems(arrayOf("Manual .txt", "Import .txt file")) { _, which ->
                if (which == 0) {
                    val name = field("File name")
                    AlertDialog.Builder(this)
                        .setTitle("Cookie file name")
                        .setView(pad(name))
                        .setPositiveButton("Edit") { _, _ ->
                            val clean = name.text.toString().trim().ifBlank { "cookies" }.removeSuffix(".txt") + ".txt"
                            editorFile = File(cookiesDir(), clean)
                            if (!editorFile!!.exists()) editorFile!!.writeText("# Netscape HTTP Cookie File\n")
                            cookieName = clean
                            saveTrim()
                            open(Page.EDITOR)
                        }
                        .setNegativeButton("Cancel", null)
                        .show()
                } else {
                    startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/plain"
                    }, PICK_COOKIE)
                }
            }
            .show()
    }

    private fun editorPage(): View {
        val file = editorFile ?: File(cookiesDir(), "cookies.txt")
        val root = column(px(16), px(12), px(16), px(12)).apply { setBackgroundColor(pageBg()) }
        root.addView(label(file.name, 18f, ink(), true))
        root.addView(muted("Type the cookie file here, the same way you would in a text editor."))
        val editor = EditText(this).apply {
            setTextColor(ink())
            setHintTextColor(MUTED)
            typeface = Typeface.MONOSPACE
            background = rounded(Color.rgb(20, 24, 32), 10)
            setPadding(px(12), px(12), px(12), px(12))
            gravity = Gravity.TOP
        }
        root.addView(editor, LinearLayout.LayoutParams(MATCH, 0, 1f))
        root.addView(solid("Save") {
            cookiesDir().mkdirs()
            file.writeText(editor.text.toString())
            cookieName = file.name
            toast("Saved ${file.name}")
            onBackPressed()
        })
        return root
    }

    private fun platformPicker(form: LinearLayout) {
        val names = listOf("YouTube", "Facebook", "Instagram", "X / Twitter", "TikTok", "Twitch")
        drop(form, "Platform", names, downloadPlatform) { downloadPlatform = it; saveTrim(); show() }
        val connected = getSharedPreferences("trim-playlist", MODE_PRIVATE).getBoolean(platformKey(), false)
        form.addView(muted(if (connected) "Signed in on this phone." else "Not signed in."))
        form.addView(solid(if (connected) "Open ${names[downloadPlatform]} again" else "Sign in to ${names[downloadPlatform]}") {
            open(Page.SIGNIN)
        })
    }

    private fun signInPage(): View {
        val names = listOf("YouTube", "Facebook", "Instagram", "X / Twitter", "TikTok", "Twitch")
        val urls = listOf(
            "https://accounts.google.com/ServiceLogin?service=youtube&hl=en&passive=true&continue=https%3A%2F%2Fm.youtube.com%2F",
            "https://m.facebook.com/login",
            "https://www.instagram.com/accounts/login/",
            "https://x.com/i/flow/login",
            "https://www.tiktok.com/login",
            "https://www.twitch.tv/login",
        )
        val root = column(0, 0, 0, 0).apply { setBackgroundColor(Color.WHITE) }
        val bar = row().apply {
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(pageBg())
            setPadding(px(12), px(10), px(12), px(10))
        }
        bar.addView(label(names[downloadPlatform], 18f, ink(), true), LinearLayout.LayoutParams(0, WRAP, 1f))
        val done = TextView(this).apply {
            text = "Done"
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            textSize = 15f
            background = rounded(BRAND, 12)
            setPadding(px(16), px(8), px(16), px(8))
            setOnClickListener {
                val signedIn = sessionSaved()
                getSharedPreferences("trim-playlist", MODE_PRIVATE).edit().putBoolean(platformKey(), signedIn).apply()
                toast(if (signedIn) "Signed in to ${names[downloadPlatform]}" else "Finish the login on this page, then tap Done")
                if (signedIn) onBackPressed()
            }
        }
        bar.addView(done)
        root.addView(bar)
        val status = TextView(this).apply {
            text = "Loading ${names[downloadPlatform]} inside Trim Playlist"
            setTextColor(Color.rgb(30, 30, 30))
            textSize = 13f
            setPadding(px(12), px(8), px(12), px(8))
            setBackgroundColor(Color.rgb(232, 236, 242))
        }
        root.addView(status)
        val web = WebView(this).apply { setBackgroundColor(Color.WHITE) }
        val cookies = CookieManager.getInstance()
        cookies.setAcceptCookie(true)
        cookies.setAcceptThirdPartyCookies(web, true)
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.settings.javaScriptCanOpenWindowsAutomatically = true
        web.settings.mediaPlaybackRequiresUserGesture = true
        web.settings.userAgentString = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val uri = request.url
                val scheme = uri.scheme?.lowercase().orEmpty()
                if (scheme == "http" || scheme == "https") return false
                val next = externalFallback(uri)
                if (next != null) view.loadUrl(next)
                else status.text = "That link stays inside Trim Playlist"
                return true
            }
            override fun onPageFinished(view: WebView?, url: String?) {
                status.text = "Sign in on this page, then tap Done"
            }
        }
        web.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                if (newProgress in 1..99) status.text = "Loading ${names[downloadPlatform]} · $newProgress%"
            }
            override fun onCreateWindow(view: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message): Boolean {
                val href = view.hitTestResult.extra
                if (!href.isNullOrBlank()) view.loadUrl(href)
                return false
            }
        }
        web.loadUrl(urls[downloadPlatform])
        root.addView(web, LinearLayout.LayoutParams(MATCH, 0, 1f))
        return root
    }

    private fun externalFallback(uri: Uri): String? {
        val raw = uri.toString()
        val browser = Regex("browser_fallback_url=([^;]+)").find(raw)?.groupValues?.getOrNull(1)
        if (!browser.isNullOrBlank()) return Uri.decode(browser)
        if (uri.scheme.equals("intent", true)) {
            val body = raw.removePrefix("intent:").substringBefore("#Intent")
            val inner = Regex("scheme=([^;]+)").find(raw)?.groupValues?.getOrNull(1)
            if ((inner == "http" || inner == "https") && body.startsWith("//")) return "$inner:$body"
        }
        return null
    }

    private fun sessionSaved(): Boolean {
        val cookies = CookieManager.getInstance()
        cookies.flush()
        val probes = when (downloadPlatform) {
            0 -> listOf("https://youtube.com", "https://m.youtube.com", "https://accounts.google.com", "https://google.com")
            1 -> listOf("https://facebook.com", "https://m.facebook.com")
            2 -> listOf("https://instagram.com", "https://www.instagram.com")
            3 -> listOf("https://x.com", "https://twitter.com")
            4 -> listOf("https://tiktok.com", "https://www.tiktok.com")
            else -> listOf("https://twitch.tv", "https://www.twitch.tv")
        }
        val blob = probes.mapNotNull { cookies.getCookie(it) }.joinToString("; ")
        val markers = when (downloadPlatform) {
            0 -> listOf("SAPISID=", "LOGIN_INFO=", "__Secure-1PSID=")
            1 -> listOf("c_user=")
            2 -> listOf("sessionid=", "ds_user_id=")
            3 -> listOf("auth_token=")
            4 -> listOf("sessionid=")
            else -> listOf("auth-token=")
        }
        return markers.any { blob.contains(it) }
    }

    private fun refreshMini() {
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

    private fun refreshClock() {
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

    private fun refreshChrome() {
        refreshClock()
        refreshMini()
    }

    private fun play(index: Int, seekMs: Int) {
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

    private fun beginPlay(index: Int, uri: Uri, video: Boolean, seekMs: Int) {
        library.currentTrack = index
        library.positionMs = seekMs
        library.save()
        if (video && engine.surface == null) engine.queue(uri, seekMs) else engine.play(uri, video, seekMs)
        show()
    }

    private fun togglePlay() {
        if (engine.ready) {
            engine.toggle()
            refreshChrome()
            return
        }
        val index = if (library.currentTrack >= 0) library.currentTrack else 0
        if (library.current().tracks.isEmpty()) toast("Add a song first") else play(index, library.positionMs)
    }

    private fun step(direction: Int) {
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

    private fun onTrackEnded() {
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

    private fun playlistMenu(index: Int) {
        val here = index == library.selected && history.last() == Page.DETAIL
        val items = if (here) arrayOf("Add files", "Add download", "Online", "Rename", "Delete") else arrayOf("Open", "Rename", "Delete")
        AlertDialog.Builder(this).setItems(items) { _, which ->
            val action = items[which]
            when (action) {
                "Open" -> { library.selected = index; open(Page.DETAIL) }
                "Add files" -> pickMedia()
                "Add download" -> addDownload()
                "Online" -> { onlineChoices.clear(); onlinePicked.clear(); open(Page.ONLINE) }
                "Rename" -> renamePlaylist(index)
                "Delete" -> deletePlaylist(index)
            }
        }.show()
    }

    private fun addDownload() {
        val folder = File(getExternalFilesDir(null) ?: filesDir, "Downloads")
        val used = library.current().tracks.map { it.uri }.toSet()
        val files = folder.listFiles()?.filter { file ->
            file.isFile && !file.name.endsWith(".video.mp4") && !file.name.endsWith(".audio.m4a") && file.toURI().toString() !in used
        }?.sortedByDescending { it.lastModified() }.orEmpty()
        if (files.isEmpty()) {
            toast("No downloads to add")
            return
        }
        val labels = files.map { it.name.substringBeforeLast('.') }.toTypedArray()
        val checked = BooleanArray(files.size)
        AlertDialog.Builder(this)
            .setTitle("Add download")
            .setMultiChoiceItems(labels, checked) { _, which, on -> checked[which] = on }
            .setPositiveButton("Add") { _, _ ->
                files.forEachIndexed { index, file ->
                    if (!checked[index]) return@forEachIndexed
                    val title = file.name.substringBeforeLast('.')
                    library.current().tracks += Track(title, file.toURI().toString(), "file", Library.looksLikeVideo(file.name))
                }
                library.save()
                show()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun pickMedia() {
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("audio/*", "video/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }, PICK_MEDIA)
    }

    private fun addPickedMedia(data: Intent) {
        val uris = mutableListOf<Uri>()
        val clip = data.clipData
        if (clip != null) for (i in 0 until clip.itemCount) uris += clip.getItemAt(i).uri else data.data?.let { uris += it }
        uris.forEach { uri ->
            try { contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: SecurityException) {}
            val name = displayName(uri)
            val mime = contentResolver.getType(uri).orEmpty()
            library.current().tracks += Track(name, uri.toString(), "file", mime.startsWith("video") || Library.looksLikeVideo(name))
        }
        library.save()
        show()
    }

    private fun onlinePage(): View {
        val scroll = ScrollView(this).apply { setBackgroundColor(pageBg()) }
        val form = column(px(16), px(16), px(16), px(24))
        form.addView(titleBar("Online"))
        form.addView(ghost("Back to playlist") {
            if (history.size > 1) history.removeLast()
            show()
        })
        form.addView(muted("This plays with internet data. The video stays online and is not saved on this phone."))
        drop(form, "Add", listOf("Single video", "Entire playlist"), onlineType) {
            onlineType = it
            onlineChoices.clear()
            onlinePicked.clear()
            show()
        }
        form.addView(caption("Video URL"))
        val url = field("https://…").remember(onlineDraft) { onlineDraft = it }
        form.addView(url)
        drop(form, "Authentication", listOf("Cookie file", "Platform account", "No authentication"), downloadAuth) { downloadAuth = it; saveTrim(); show() }
        if (downloadAuth == 0) cookiePicker(form)
        if (downloadAuth == 1) platformPicker(form)
        drop(form, "Format", listOf("MP4 video", "Audio only"), onlineFormat) { onlineFormat = it }
        form.addView(spaceH(8))
        form.addView(solid("Load") {
            val entered = url.text.toString().trim()
            if (!entered.startsWith("http://") && !entered.startsWith("https://")) {
                toast("Enter a video or playlist URL")
                return@solid
            }
            if (streamBusy) return@solid
            streamBusy = true
            toast("Loading…")
            val cookie = authCookieHeader(if (entered.contains("youtu")) "www.youtube.com" else (Uri.parse(entered).host ?: ""))
            Thread {
                try {
                    val found = PhoneDownload.catalog(entered, cookie)
                    val playlist = entered.contains("list=")
                    runOnUiThread {
                        streamBusy = false
                        if (!playlist || onlineType == 1) addOnline(found)
                        else {
                            onlineChoices.clear()
                            onlineChoices += found
                            onlinePicked.clear()
                            show()
                        }
                    }
                } catch (error: Exception) {
                    runOnUiThread {
                        streamBusy = false
                        toast(error.message ?: "Couldn't read that URL")
                    }
                }
            }.start()
        })
        if (onlineType == 0 && onlineChoices.isNotEmpty()) {
            form.addView(spaceH(12))
            form.addView(muted("Choose the videos to add."))
            onlineChoices.forEachIndexed { index, (title, _) ->
                val picked = index in onlinePicked
                form.addView(TextView(this).apply {
                    text = if (picked) "✓  $title" else "○  $title"
                    setTextColor(ink())
                    textSize = 16f
                    setPadding(px(12), px(12), px(12), px(12))
                    background = rounded(if (picked) selectedBg() else fieldBg(), 10)
                    tag = index
                    setOnClickListener {
                        if (index in onlinePicked) onlinePicked.remove(index) else onlinePicked.add(index)
                        paintChoices(form, onlineChoices, onlinePicked)
                    }
                })
                form.addView(spaceH(6))
            }
            form.addView(solid("Add selected") {
                val chosen = onlinePicked.sorted().mapNotNull { onlineChoices.getOrNull(it) }
                if (chosen.isEmpty()) toast("Select a video") else addOnline(chosen)
            })
        }
        scroll.addView(form)
        return scroll
    }

    private fun addOnline(entries: List<Pair<String, String>>) {
        val video = onlineFormat == 0
        entries.forEach { (title, page) ->
            library.current().tracks += Track(title, page, "online", video)
        }
        library.save()
        onlineChoices.clear()
        onlinePicked.clear()
        if (history.lastOrNull() == Page.ONLINE && history.size > 1) history.removeLast()
        toast("Added ${entries.size}")
        show()
    }

    private fun removeTrack(index: Int) {
        val tracks = library.current().tracks
        if (index !in tracks.indices) return
        tracks.removeAt(index)
        when {
            library.currentTrack == index -> {
                engine.stop()
                library.currentTrack = -1
            }
            library.currentTrack > index -> library.currentTrack -= 1
        }
        library.save()
        show()
    }

    private fun createPlaylist() {
        prompt("New playlist", "", "Create") { name ->
            val title = name.ifBlank { "New playlist" }
            library.playlists += Playlist(title, mutableListOf())
            library.selected = library.playlists.lastIndex
            library.currentTrack = -1
            library.save()
            open(Page.DETAIL)
        }
    }

    private fun renamePlaylist(index: Int) {
        prompt("Rename", library.playlists[index].name, "Save") { name ->
            if (name.isNotEmpty()) library.playlists[index].name = name
            library.save()
            show()
        }
    }

    private fun prompt(title: String, value: String, ok: String, done: (String) -> Unit) {
        val input = EditText(this).apply {
            setText(value)
            hint = "Playlist name"
            setTextColor(ink())
            setHintTextColor(soft())
            background = rounded(fieldBg(), 10)
            setPadding(px(12), px(12), px(12), px(12))
            setSingleLine(true)
        }
        val box = column(px(18), px(18), px(18), px(12)).apply { setBackgroundColor(dialogBg()) }
        box.addView(label(title, 18f, ink(), true))
        box.addView(spaceH(12))
        box.addView(input)
        val buttons = row().apply { gravity = Gravity.END; setPadding(0, px(8), 0, 0) }
        val dialog = AlertDialog.Builder(this).setView(box).create()
        buttons.addView(TextView(this).apply {
            text = "Cancel"
            setTextColor(soft())
            textSize = 15f
            setPadding(px(12), px(10), px(12), px(10))
            setOnClickListener { dialog.dismiss() }
        })
        buttons.addView(TextView(this).apply {
            text = ok
            setTextColor(if (dark) Color.WHITE else BRAND)
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(px(12), px(10), px(4), px(10))
            setOnClickListener {
                done(input.text.toString().trim())
                dialog.dismiss()
            }
        })
        box.addView(buttons)
        dialog.window?.setBackgroundDrawable(rounded(dialogBg(), 16))
        dialog.show()
    }

    private fun deletePlaylist(index: Int) {
        if (library.playlists.size == 1) {
            toast("Keep at least one playlist")
            return
        }
        library.playlists.removeAt(index)
        library.selected = 0
        library.currentTrack = -1
        engine.stop()
        library.save()
        if (history.last() == Page.DETAIL) onBackPressed() else show()
    }

    private fun importCookie(uri: Uri?) {
        if (uri == null) return
        val name = displayName(uri).ifBlank { "imported.txt" }.let { if (it.endsWith(".txt")) it else "$it.txt" }
        val text = contentResolver.openInputStream(uri)?.bufferedReader()?.readText().orEmpty()
        File(cookiesDir(), name).writeText(text)
        cookieName = name
        saveTrim()
        toast("Imported $name")
        show()
    }

    private fun qualityMenu() {
        val options = arrayOf("Source", "1080p", "720p", "480p", "360p")
        AlertDialog.Builder(this).setTitle("Quality").setItems(options) { _, which ->
            playbackQuality = options[which]
            toast(if (which == 0) "Playing the file's own quality" else "This file has one copy. Source is its quality.")
            show()
        }.show()
    }

    private fun titleBar(title: String): View {
        val line = row().apply { gravity = Gravity.CENTER_VERTICAL }
        val button = FrameLayout(this).apply {
            setOnClickListener { openNav() }
            layoutParams = LinearLayout.LayoutParams(px(40), px(40))
            addView(MenuIcon(this@MainActivity), FrameLayout.LayoutParams(MATCH, MATCH))
        }
        line.addView(button)
        line.addView(label(title, 20f, ink(), true).apply { setPadding(px(12), 0, 0, 0) })
        return line
    }

    private fun buildNav() {
        navScrim = View(this).apply {
            setBackgroundColor(0x99000000.toInt())
            visibility = View.GONE
            setOnClickListener { closeNav() }
        }
        shell.addView(navScrim, FrameLayout.LayoutParams(MATCH, MATCH))
        navPanel = column(px(18), px(36), px(18), px(18)).apply {
            setBackgroundColor(if (dark) Color.rgb(16, 18, 24) else Color.rgb(255, 255, 255))
            visibility = View.GONE
        }
        navPanel.addView(label("Library", 13f, soft(), false).apply { setPadding(px(12), 0, 0, px(14)) })
        navPanel.addView(navItem("Trim Playlist", Page.LIST))
        navPanel.addView(navItem("Trim URL", Page.URL))
        navPanel.addView(navItem("Settings", Page.SETTINGS))
        navPanel.addView(navItem("About", Page.ABOUT))
        shell.addView(navPanel, FrameLayout.LayoutParams(px(260), MATCH).apply { gravity = Gravity.START })
    }

    private fun navItem(name: String, page: Page) = TextView(this).apply {
        text = name
        textSize = 18f
        setTextColor(ink())
        tag = page
        setPadding(px(14), px(16), px(14), px(16))
        layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { bottomMargin = px(8) }
        setOnClickListener {
            closeNav()
            history.clear()
            history.add(page)
            motion = 0
            show()
        }
    }

    private fun openNav() {
        val section = when (history.last()) {
            Page.URL, Page.EDITOR, Page.SIGNIN -> Page.URL
            Page.SETTINGS -> Page.SETTINGS
            Page.ABOUT -> Page.ABOUT
            else -> Page.LIST
        }
        for (i in 0 until navPanel.childCount) {
            val child = navPanel.getChildAt(i)
            if (child.tag is Page) child.background = rounded(if (child.tag == section) if (dark) Color.rgb(40, 48, 64) else Color.rgb(220, 228, 240) else Color.TRANSPARENT, 10)
        }
        navScrim.visibility = View.VISIBLE
        paintNav()
        navScrim.alpha = 0f
        navScrim.animate().alpha(1f).setDuration(180).start()
        navPanel.visibility = View.VISIBLE
        navPanel.translationX = -px(260).toFloat()
        navPanel.animate().translationX(0f).setDuration(220).setInterpolator(DecelerateInterpolator()).start()
    }

    private fun closeNav() {
        navScrim.animate().alpha(0f).setDuration(160).withEndAction { navScrim.visibility = View.GONE }.start()
        navPanel.animate().translationX(-px(260).toFloat()).setDuration(180).withEndAction { navPanel.visibility = View.GONE }.start()
    }

    private fun settingsPage(): View {
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

    private fun chooseTheme(nextDark: Boolean) {
        if (dark == nextDark) return
        dark = nextDark
        getSharedPreferences("trim-playlist", MODE_PRIVATE).edit().putBoolean("dark", dark).apply()
        paintNav()
        applyBars()
        show()
    }

    private fun aboutPage(): View {
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

    private fun paintNav() {
        navPanel.setBackgroundColor(if (dark) Color.rgb(16, 18, 24) else Color.WHITE)
        for (i in 0 until navPanel.childCount) {
            val child = navPanel.getChildAt(i)
            if (child is TextView) child.setTextColor(if (child.tag is Page) ink() else soft())
        }
    }

    private fun applyBars() {
        window.statusBarColor = pageBg()
        window.navigationBarColor = pageBg()
        if (Build.VERSION.SDK_INT >= 30) {
            val appearance = if (dark) 0 else android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(
                appearance,
                android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
            )
        }
    }

    private fun trackRow(index: Int, track: Track, songs: LinearLayout, scroller: ScrollView, selected: Int): View {
        val row = row().apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, px(8), 0, px(8))
            if (index == library.currentTrack) setBackgroundColor(selected)
            setOnClickListener { play(songs.indexOfChild(this).coerceAtLeast(0), 0) }
        }
        row.addView(RecordView(this).apply { layoutParams = LinearLayout.LayoutParams(px(46), px(46)) })
        val info = column(px(10), 0, 0, 0)
        info.addView(label(track.title, 15f, ink(), false))
        info.addView(lineView(track))
        row.addView(info, LinearLayout.LayoutParams(0, WRAP, 1f))
        row.addView(TextView(this).apply {
            text = "×"
            setTextColor(soft())
            textSize = 22f
            gravity = Gravity.CENTER
            setPadding(px(8), px(8), px(4), px(8))
            setOnClickListener {
                val at = songs.indexOfChild(row)
                AlertDialog.Builder(this@MainActivity)
                    .setTitle("Remove this song?")
                    .setMessage(track.title)
                    .setPositiveButton("Remove") { _, _ -> removeTrack(at) }
                    .setNegativeButton("Cancel", null)
                    .show()
            }
        })
        row.addView(TextView(this).apply {
            this.text = "≡"
            setTextColor(ink())
            textSize = 22f
            gravity = Gravity.CENTER
            setPadding(px(12), px(8), px(4), px(8))
            setOnTouchListener { _, event -> dragSong(songs, scroller, row, selected, event) }
        })
        return row
    }

    private fun dragSong(songs: LinearLayout, scroller: ScrollView, row: View, selected: Int, event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dragAnchor = event.rawY
                dragShift.clear()
                row.parent?.requestDisallowInterceptTouchEvent(true)
                scroller.requestDisallowInterceptTouchEvent(true)
                row.elevation = px(18).toFloat()
                row.alpha = 0.96f
            }
            MotionEvent.ACTION_MOVE -> {
                row.translationY = event.rawY - dragAnchor
                val from = songs.indexOfChild(row)
                val target = hoverIndex(songs, row)
                val height = row.height
                for (i in 0 until songs.childCount) {
                    val child = songs.getChildAt(i)
                    if (i == from) continue
                    val shift = when {
                        from < target && i in (from + 1)..target -> -height
                        target < from && i in target until from -> height
                        else -> 0
                    }
                    if (dragShift[child] != shift) {
                        dragShift[child] = shift
                        child.animate().translationY(shift.toFloat()).setDuration(140).start()
                    }
                }
                val loc = IntArray(2)
                scroller.getLocationOnScreen(loc)
                val local = event.rawY - loc[1]
                when {
                    local < px(64) -> scroller.scrollBy(0, -px(18))
                    local > scroller.height - px(64) -> scroller.scrollBy(0, px(18))
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val from = songs.indexOfChild(row)
                val target = hoverIndex(songs, row)
                for (i in 0 until songs.childCount) songs.getChildAt(i).animate().cancel()
                row.translationY = 0f
                row.elevation = 0f
                row.alpha = 1f
                for (i in 0 until songs.childCount) songs.getChildAt(i).translationY = 0f
                dragShift.clear()
                if (from >= 0 && target >= 0 && target != from) {
                    songs.removeView(row)
                    songs.addView(row, target)
                    relocate(from, target)
                    for (i in 0 until songs.childCount) {
                        songs.getChildAt(i).setBackgroundColor(if (i == library.currentTrack) selected else Color.TRANSPARENT)
                    }
                    library.save()
                }
            }
        }
        return true
    }

    private fun hoverIndex(songs: LinearLayout, row: View): Int {
        val from = songs.indexOfChild(row)
        if (from < 0) return -1
        val loc = IntArray(2)
        row.getLocationOnScreen(loc)
        val center = loc[1] + row.height / 2f
        var target = from
        for (i in 0 until songs.childCount) {
            if (i == from) continue
            val child = songs.getChildAt(i)
            child.getLocationOnScreen(loc)
            val mid = loc[1] - child.translationY + child.height / 2f
            if (i > from && center > mid) target = i
            if (i < from && center < mid && (target == from || i < target)) target = i
        }
        return target
    }

    private fun relocate(from: Int, to: Int) {
        val tracks = library.current().tracks
        if (from !in tracks.indices || to !in tracks.indices) return
        tracks.add(to, tracks.removeAt(from))
        val current = library.currentTrack
        library.currentTrack = when {
            current == from -> to
            from < current && to >= current -> current - 1
            from > current && to <= current -> current + 1
            else -> current
        }
    }

    private inner class MenuIcon(context: android.content.Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ink()
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
        override fun onDraw(canvas: Canvas) {
            paint.strokeWidth = height * 0.08f
            val left = width * 0.22f
            val right = width * 0.78f
            canvas.drawLine(left, height * 0.32f, right, height * 0.32f, paint)
            canvas.drawLine(left, height * 0.50f, right, height * 0.50f, paint)
            canvas.drawLine(left, height * 0.68f, right, height * 0.68f, paint)
        }
    }

    private fun drop(parent: LinearLayout, captionText: String, options: List<String>, selected: Int, onPick: (Int) -> Unit) {
        parent.addView(caption(captionText))
        val current = options.getOrElse(selected) { options.first() }
        val box = TextView(this).apply {
            text = "$current   ▾"
            setTextColor(ink())
            textSize = 16f
            background = rounded(fieldBg(), 10)
            setPadding(px(12), px(14), px(12), px(14))
            setOnClickListener { popup(this, options) { choice -> onPick(options.indexOf(choice)) } }
        }
        parent.addView(box)
        parent.addView(spaceH(8))
    }

    private fun popup(anchor: View, options: List<String>, onPick: (String) -> Unit) {
        val list = column(0, px(4), 0, px(4)).apply { background = rounded(dialogBg(), 12) }
        options.forEach { option ->
            list.addView(TextView(this).apply {
                text = option
                setTextColor(ink())
                textSize = 16f
                setPadding(px(14), px(12), px(14), px(12))
            })
        }
        val scroll = ScrollView(this).apply { addView(list) }
        val popup = PopupWindow(scroll, anchor.width.coerceAtLeast(px(220)), px(48 * options.size.coerceAtMost(6)), true)
        popup.setBackgroundDrawable(rounded(dialogBg(), 12))
        popup.isOutsideTouchable = true
        options.forEachIndexed { index, _ ->
            (list.getChildAt(index) as TextView).setOnClickListener {
                popup.dismiss()
                onPick(options[index])
            }
        }
        popup.showAsDropDown(anchor)
    }

    private fun videoFrame(height: Int): FrameLayout {
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

    private data class Meta(val artist: String, val durationMs: Int)

    private fun lineView(track: Track): TextView {
        val view = muted(trackLine(track))
        metaLabels.add(track.uri to view)
        return view
    }

    private fun trackLine(track: Track): String {
        val known = metaCache[track.uri]
        if (known == null) ensureMeta(track)
        return formatMeta(track, known)
    }

    private fun formatMeta(track: Track, known: Meta?): String {
        val artist = known?.artist ?: guessArtist(track.title)
        val stored = known?.durationMs ?: 0
        val duration = if (stored > 0) stored else if (sameTrack(track)) engine.duration() else 0
        return if (duration > 0) "$artist · ${formatTime(duration)}" else artist
    }

    private fun sameTrack(track: Track) = library.current().tracks.getOrNull(library.currentTrack)?.uri == track.uri

    private fun guessArtist(title: String): String {
        val name = title.substringBeforeLast('.')
        val parts = name.split(" - ").map { it.trim() }.filter { it.isNotEmpty() }
        val head = parts.firstOrNull().orEmpty()
        return when {
            parts.size >= 3 && head.all { it.isDigit() } -> parts[1]
            parts.size >= 2 && !head.all { it.isDigit() } -> parts[0]
            else -> "Unknown artist"
        }
    }

    private fun ensureMeta(track: Track) {
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

    private fun readMeta(track: Track): Meta {
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

    private fun syncSession(force: Boolean) {
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

    private fun notesBlocked(): Boolean {
        if (!notesOn) return true
        val manager = getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return true
        return Build.VERSION.SDK_INT >= 33 &&
            noteDenied &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
    }

    private fun ensureNotePermission() {
        if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        askedNotes = true
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 44)
    }

    private fun warnNotesOff() {
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

    private fun pushNotification(title: String, line: String, playing: Boolean) {
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

    private fun serviceAction(action: String): PendingIntent {
        val intent = Intent(this, PlaybackService::class.java).setAction(action)
        return PendingIntent.getService(this, action.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel("playback", "Now playing", NotificationManager.IMPORTANCE_LOW)
        channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        channel.setSound(null, null)
        manager.createNotificationChannel(channel)
    }

    private fun coverArt(): Bitmap {
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

    private fun platformKey() = "connected-$downloadPlatform"
    private fun cookiesDir() = File(filesDir, "cookies").apply { mkdirs() }
    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0) ?: "Track"
        }
        return uri.lastPathSegment ?: "Track"
    }

    private fun formatTime(ms: Int): String {
        val safe = ms.coerceAtLeast(0) / 1000
        val minutes = (safe % 3600) / 60
        val seconds = safe % 60
        val hours = safe / 3600
        return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, seconds) else "%d:%02d".format(minutes, seconds)
    }

    private fun saveTrim() {
        getSharedPreferences("trim-playlist", MODE_PRIVATE).edit()
            .putInt("trim-type", downloadType)
            .putInt("trim-mode", downloadMode)
            .putInt("trim-format", downloadFormat)
            .putInt("trim-quality", downloadQuality)
            .putInt("trim-audio", downloadAudio)
            .putInt("trim-auth", downloadAuth)
            .putInt("trim-platform", downloadPlatform)
            .putString("trim-cookie", cookieName)
            .putString("trim-url", draftUrl)
            .putString("trim-name", draftName)
            .putString("trim-start", draftStart)
            .putString("trim-end", draftEnd)
            .putString("trim-volume", draftVolume)
            .apply()
    }

    private fun reportDownload(text: String, fraction: Float) {
        runOnUiThread {
            if (downloadCleared) return@runOnUiThread
            downloadStrip.setBackgroundColor(cardBg())
            downloadLabel.text = text
            downloadLabel.setTextColor(soft())
            downloadTrack.setBackgroundColor(if (dark) Color.rgb(40, 44, 54) else Color.rgb(210, 214, 220))
            downloadFill.pivotX = 0f
            downloadFill.scaleX = fraction.coerceIn(0f, 1f)
            placeDownload()
        }
    }

    private fun placeDownload() {
        val showBar = !downloadCleared && history.lastOrNull() == Page.URL && downloadLabel.text.isNotBlank()
        downloadStrip.visibility = if (showBar) View.VISIBLE else View.GONE
    }

    private fun loadDownloadChoices(pageUrl: String) {
        downloadBusy = true
        toast("Loading playlist…")
        val cookie = authCookieHeader(if (pageUrl.contains("youtu")) "www.youtube.com" else (Uri.parse(pageUrl).host ?: ""))
        Thread {
            try {
                val found = PhoneDownload.catalog(pageUrl, cookie)
                runOnUiThread {
                    downloadBusy = false
                    downloadChoices.clear()
                    downloadChoices += found
                    downloadPicked.clear()
                    downloadChoiceUrl = pageUrl
                    show()
                }
            } catch (error: Exception) {
                runOnUiThread {
                    downloadBusy = false
                    toast(error.message ?: "Couldn't read that playlist")
                }
            }
        }.start()
    }

    private fun clock(value: String): Double {
        val parts = value.trim().split(":")
        if (parts.isEmpty() || parts.size > 3 || parts.any { it.isBlank() }) error("Use seconds, MM:SS or HH:MM:SS")
        return parts.fold(0.0) { total, part -> total * 60 + part.toDouble() }
    }

    private fun beginDownload(pages: List<String>, trimming: Boolean, trimStart: Double, trimEnd: Double, trimName: String) {
        downloadBusy = true
        downloadCleared = false
        val audio = downloadFormat == 1
        val heights = intArrayOf(0, 1080, 720, 480, 360)
        val maxHeight = heights.getOrElse(downloadQuality) { 0 }
        val cookieHost = if (pages.firstOrNull()?.contains("youtu") == true) "www.youtube.com" else (Uri.parse(pages.firstOrNull().orEmpty()).host ?: "youtube.com")
        val cookie = authCookieHeader(cookieHost)
        reportDownload("Starting · 0%", 0f)
        Thread {
            try {
                val items = pages.flatMap { PhoneDownload.items(it, audio, maxHeight, cookie) }
                val folder = File(getExternalFilesDir(null) ?: filesDir, "Downloads")
                items.forEachIndexed { index, item ->
                    val place = if (items.size > 1) "${index + 1}/${items.size} · " else ""
                    var file = PhoneDownload.save(folder, item, cookie) { fraction ->
                        if (fraction < 0f) reportDownload("Downloading ${item.title} · $place", 0.08f)
                        else reportDownload("Downloading ${item.title} · $place${(fraction * 100).toInt()}%", fraction)
                    }
                    if (trimming) {
                        reportDownload("Trimming ${item.title} · $place", 0.98f)
                        file = PhoneDownload.cut(file, trimStart, trimEnd, trimName.ifBlank { item.title.substringBefore(" · ") })
                    }
                }
                val word = if (items.size == 1) "file" else "files"
                reportDownload("Saved ${items.size} $word · 100%", 1f)
            } catch (error: Exception) {
                reportDownload(error.message ?: "Download failed", 0f)
            } finally {
                downloadBusy = false
            }
        }.start()
    }

    private fun authCookieHeader(host: String): String? {
        if (downloadAuth == 2) return null
        if (downloadAuth == 1) return CookieManager.getInstance().getCookie("https://$host")?.takeIf { it.isNotBlank() }
        if (cookieName.isBlank()) return null
        val file = File(cookiesDir(), cookieName)
        if (!file.exists()) return null
        val pairs = file.readLines().mapNotNull { line ->
            if (line.isBlank() || line.startsWith("#")) return@mapNotNull null
            val parts = line.split('\t')
            if (parts.size < 7) return@mapNotNull null
            val domain = parts[0].removePrefix(".").lowercase()
            val target = host.lowercase()
            if (target != domain && !target.endsWith(".$domain") && !domain.endsWith(target)) return@mapNotNull null
            "${parts[5]}=${parts[6]}"
        }
        return pairs.joinToString("; ").ifBlank { null }
    }

    private fun toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    private fun column(l: Int, t: Int, r: Int, b: Int) = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(l, t, r, b) }
    private fun row() = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
    private fun label(value: String, size: Float, color: Int, bold: Boolean) = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(color)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }
    private fun muted(value: String) = label(value, 13f, soft(), false)
    private fun caption(value: String) = muted(value).apply { setPadding(0, px(8), 0, px(4)) }
    private fun field(hint: String) = EditText(this).apply {
        this.hint = hint
        setTextColor(ink())
        setHintTextColor(soft())
        background = rounded(fieldBg(), 10)
        setPadding(px(12), px(12), px(12), px(12))
        setSingleLine(true)
    }
    private fun EditText.remember(current: String, assign: (String) -> Unit): EditText {
        setText(current)
        addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) { assign(s?.toString().orEmpty()); saveTrim() }
        })
        return this
    }
    private fun dialogField(hint: String) = EditText(this).apply {
        this.hint = hint
        setTextColor(Color.BLACK)
        setSingleLine(true)
    }
    private fun pad(child: View) = FrameLayout(this).apply { setPadding(px(16), px(8), px(16), 0); addView(child) }
    private fun solid(value: String, action: () -> Unit) = TextView(this).apply {
        text = value
        gravity = Gravity.CENTER
        setTextColor(Color.WHITE)
        textSize = 16f
        background = rounded(BRAND, 12)
        setPadding(px(12), px(12), px(12), px(12))
        layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = px(8) }
        setOnClickListener { action() }
    }
    private fun ghost(value: String, action: () -> Unit) = TextView(this).apply {
        text = value
        setTextColor(ink())
        textSize = 16f
        setPadding(px(10), px(8), px(10), px(8))
        setOnClickListener { action() }
    }
    private fun iconPill(kind: String, title: String, filled: Boolean, action: () -> Unit): LinearLayout {
        val box = row().apply {
            gravity = Gravity.CENTER_VERTICAL
            background = if (filled) rounded(Color.WHITE, 24) else GradientDrawable().apply {
                cornerRadius = px(24).toFloat()
                setStroke(px(1), ink())
            }
            setPadding(px(16), px(8), px(18), px(8))
            setOnClickListener { action() }
        }
        box.addView(Glyph(this).apply {
            this.kind = kind
            this.markColor = if (filled) Color.BLACK else ink()
            val size = px(22)
            layoutParams = LinearLayout.LayoutParams(size, size)
        })
        box.addView(label("  $title", 16f, if (filled) Color.BLACK else ink(), false))
        return box
    }
    private fun pill(value: String, filled: Boolean, action: () -> Unit) = TextView(this).apply {
        text = value
        gravity = Gravity.CENTER
        setTextColor(if (filled) Color.BLACK else ink())
        textSize = 16f
        background = if (filled) rounded(Color.WHITE, 24) else GradientDrawable().apply {
            cornerRadius = px(24).toFloat()
            setStroke(px(1), ink())
        }
        setPadding(px(22), px(10), px(22), px(10))
        setOnClickListener { action() }
    }
    private fun iconButton(kind: String, disc: Boolean, lit: Boolean, action: () -> Unit) = Glyph(this).apply {
        this.kind = kind
        this.disc = disc
        this.lit = lit
        val size = if (disc) px(68) else px(48)
        layoutParams = LinearLayout.LayoutParams(size, size).apply {
            marginStart = px(4)
            marginEnd = px(4)
        }
        setOnClickListener { action() }
    }
    private fun space(width: Int) = View(this).apply { layoutParams = LinearLayout.LayoutParams(px(width), 1) }
    private fun spaceH(height: Int) = View(this).apply { layoutParams = LinearLayout.LayoutParams(1, px(height)) }
    private fun rounded(color: Int, radius: Int) = GradientDrawable().apply { setColor(color); cornerRadius = px(radius).toFloat() }
    private fun pageBg() = if (dark) Color.BLACK else Color.rgb(244, 245, 247)
    private fun cardBg() = if (dark) Color.rgb(28, 28, 28) else Color.WHITE
    private fun sheetBg() = if (dark) Color.rgb(48, 48, 48) else Color.rgb(232, 234, 238)
    private fun fieldBg() = if (dark) Color.rgb(30, 37, 50) else Color.rgb(255, 255, 255)
    private fun dialogBg() = if (dark) Color.rgb(42, 42, 46) else Color.WHITE
    private fun selectedBg() = if (dark) Color.rgb(36, 36, 36) else Color.rgb(226, 230, 236)
    private fun ink() = if (dark) Color.WHITE else Color.rgb(22, 24, 28)
    private fun soft() = if (dark) Color.rgb(181, 181, 181) else Color.rgb(90, 96, 105)
    private fun px(value: Int) = (value * resources.displayMetrics.density).toInt()

    private class Glyph(context: android.content.Context) : View(context) {
        var kind = "play"
        var lit = false
        var disc = false
        var markColor = Color.WHITE
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND }

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f
            val cy = h / 2f
            if (disc) {
                paint.style = Paint.Style.FILL
                paint.color = Color.WHITE
                canvas.drawCircle(cx, cy, minOf(w, h) / 2f, paint)
            }
            paint.color = if (disc) Color.BLACK else if (lit) Color.rgb(80, 160, 255) else markColor
            val s = minOf(w, h) * if (disc) 0.26f else 0.32f
            when (kind) {
                "pause" -> {
                    paint.style = Paint.Style.FILL
                    canvas.drawRoundRect(cx - s * 0.72f, cy - s, cx - s * 0.18f, cy + s, 3f, 3f, paint)
                    canvas.drawRoundRect(cx + s * 0.18f, cy - s, cx + s * 0.72f, cy + s, 3f, 3f, paint)
                }
                "prev", "next" -> drawSkip(canvas, cx, cy, s, kind == "next")
                "shuffle" -> drawShuffle(canvas, cx, cy, s)
                "repeat", "repeat1" -> drawRepeat(canvas, cx, cy, s, kind == "repeat1")
                else -> {
                    paint.style = Paint.Style.FILL
                    val path = Path()
                    path.moveTo(cx - s * 0.45f, cy - s)
                    path.lineTo(cx + s * 0.9f, cy)
                    path.lineTo(cx - s * 0.45f, cy + s)
                    path.close()
                    canvas.drawPath(path, paint)
                }
            }
        }

        private fun drawSkip(canvas: Canvas, cx: Float, cy: Float, s: Float, forward: Boolean) {
            paint.style = Paint.Style.FILL
            val dir = if (forward) 1f else -1f
            val path = Path()
            path.moveTo(cx - dir * s * 0.05f, cy - s)
            path.lineTo(cx + dir * s, cy)
            path.lineTo(cx - dir * s * 0.05f, cy + s)
            path.close()
            canvas.drawPath(path, paint)
            canvas.drawRoundRect(cx - dir * s * 1.05f, cy - s, cx - dir * s * 0.62f, cy + s, 2f, 2f, paint)
        }

        private fun drawShuffle(canvas: Canvas, cx: Float, cy: Float, s: Float) {
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = s * 0.22f
            val top = Path()
            top.moveTo(cx - s, cy - s * 0.45f)
            top.cubicTo(cx - s * 0.1f, cy - s * 0.45f, cx + s * 0.1f, cy + s * 0.45f, cx + s * 0.72f, cy + s * 0.45f)
            canvas.drawPath(top, paint)
            val bottom = Path()
            bottom.moveTo(cx - s, cy + s * 0.45f)
            bottom.cubicTo(cx - s * 0.1f, cy + s * 0.45f, cx + s * 0.1f, cy - s * 0.45f, cx + s * 0.72f, cy - s * 0.45f)
            canvas.drawPath(bottom, paint)
            paint.style = Paint.Style.FILL
            arrowHead(canvas, cx + s * 0.72f, cy - s * 0.45f, s * 0.45f, -0.4f)
            arrowHead(canvas, cx + s * 0.72f, cy + s * 0.45f, s * 0.45f, 0.4f)
        }

        private fun drawRepeat(canvas: Canvas, cx: Float, cy: Float, s: Float, one: Boolean) {
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = s * 0.2f
            canvas.drawArc(cx - s, cy - s * 0.85f, cx + s * 0.75f, cy + s * 0.85f, 30f, 290f, false, paint)
            paint.style = Paint.Style.FILL
            arrowHead(canvas, cx + s * 0.15f, cy - s * 0.85f, s * 0.42f, -1.2f)
            if (one) {
                paint.textAlign = Paint.Align.CENTER
                paint.textSize = s * 0.85f
                canvas.drawText("1", cx - s * 0.05f, cy + s * 0.28f, paint)
            }
        }

        private fun arrowHead(canvas: Canvas, x: Float, y: Float, size: Float, tilt: Float) {
            canvas.save()
            canvas.translate(x, y)
            canvas.rotate(tilt * 57f)
            val path = Path()
            path.moveTo(size, 0f)
            path.lineTo(-size * 0.6f, -size * 0.55f)
            path.lineTo(-size * 0.6f, size * 0.55f)
            path.close()
            canvas.drawPath(path, paint)
            canvas.restore()
        }
    }

    private class RecordView(context: android.content.Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        override fun onDraw(canvas: Canvas) {
            val c = width / 2f
            val r = minOf(width, height) / 2f
            paint.color = Color.rgb(58, 58, 58)
            canvas.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), r / 8f, r / 8f, paint)
            paint.color = Color.rgb(30, 30, 30)
            canvas.drawCircle(c, height / 2f, r * 0.72f, paint)
            paint.color = Color.rgb(70, 70, 70)
            canvas.drawCircle(c, height / 2f, r * 0.28f, paint)
            paint.color = Color.rgb(20, 20, 20)
            canvas.drawCircle(c, height / 2f, r * 0.08f, paint)
        }
    }

    private inner class Engine {
        private val player = MediaPlayer()
        private var token = 0
        var surface: Surface? = null
        var ready = false
        var volume = 1f
        private var queued: Pair<Uri, Int>? = null
        private var videoMode = false
        var onChange: (() -> Unit)? = null
        private val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(audioAttributes())
            .setOnAudioFocusChangeListener { if (it == AudioManager.AUDIOFOCUS_LOSS) { pause(); onChange?.invoke() } }
            .build()

        fun attach(next: Surface) {
            surface?.release()
            surface = next
            if (videoMode && ready) try { player.setSurface(next) } catch (_: IllegalStateException) {}
            queued?.let { (uri, seek) -> queued = null; play(uri, true, seek) }
        }

        fun detach() {
            try { player.setSurface(null) } catch (_: IllegalStateException) {}
            surface?.release()
            surface = null
        }

        fun queue(uri: Uri, seekMs: Int) { queued = uri to seekMs; videoMode = true }

        fun play(uri: Uri, video: Boolean, seekMs: Int) {
            val current = ++token
            ready = false
            videoMode = video
            queued = null
            getSystemService(AudioManager::class.java).requestAudioFocus(focusRequest)
            try {
                player.reset()
                player.setAudioAttributes(audioAttributes())
                val headers = if (uri.host?.contains("googlevideo") == true) {
                    mapOf("User-Agent" to "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip")
                } else emptyMap()
                if (headers.isEmpty()) player.setDataSource(this@MainActivity, uri) else player.setDataSource(this@MainActivity, uri, headers)
                player.setSurface(if (video) surface else null)
                player.setOnPreparedListener {
                    if (current != token) return@setOnPreparedListener
                    ready = true
                    applyVolume()
                    if (seekMs > 0) it.seekTo(seekMs)
                    it.start()
                    onChange?.invoke()
                }
                player.setOnCompletionListener { if (current == token) onTrackEnded() }
                player.setOnErrorListener { _, _, _ ->
                    if (current == token) { ready = false; toast("Couldn't play that track") }
                    true
                }
                player.prepareAsync()
            } catch (_: Exception) {
                ready = false
                toast("Couldn't open that track")
            }
        }

        fun toggle() {
            if (!ready) return
            if (playing()) pause() else try { player.start() } catch (_: IllegalStateException) {}
        }
        fun pause() { if (ready) try { if (player.isPlaying) player.pause() } catch (_: IllegalStateException) {} }
        fun stop() { token += 1; ready = false; queued = null; try { player.reset() } catch (_: IllegalStateException) {} }
        fun seek(ms: Int) { if (ready && ms >= 0) try { player.seekTo(ms) } catch (_: IllegalStateException) {} }
        fun position() = try { if (ready) player.currentPosition else library.positionMs } catch (_: IllegalStateException) { 0 }
        fun duration() = try { if (ready) player.duration.coerceAtLeast(0) else 0 } catch (_: IllegalStateException) { 0 }
        fun playing() = try { ready && player.isPlaying } catch (_: IllegalStateException) { false }
        fun applyVolume() { if (ready) try { player.setVolume(volume, volume) } catch (_: IllegalStateException) {} }
        fun release() { token += 1; surface?.release(); surface = null; player.release() }
        private fun audioAttributes() = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
    }

    companion object {
        private const val PICK_MEDIA = 41
        private const val PICK_COOKIE = 42
        private const val BG = 0xFF000000.toInt()
        private const val MUTED = 0xFFB5B5B5.toInt()
        private const val BRAND = 0xFF3276FF.toInt()
        private const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
        private const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
    }
}
