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
    internal lateinit var library: Library
    internal lateinit var engine: Engine
    internal lateinit var body: FrameLayout
    internal lateinit var shell: FrameLayout
    internal lateinit var miniWrap: LinearLayout
    internal lateinit var downloadStrip: LinearLayout
    internal lateinit var downloadTrack: FrameLayout
    internal lateinit var downloadFill: View
    internal lateinit var downloadLabel: TextView
    internal var onlineType = 0
    internal var onlineFormat = 0
    internal var onlineDraft = ""
    internal val onlineChoices = mutableListOf<Pair<String, String>>()
    internal val onlinePicked = mutableSetOf<Int>()
    internal var streamBusy = false
    internal val downloadChoices = mutableListOf<Pair<String, String>>()
    internal val downloadPicked = mutableSetOf<Int>()
    internal var downloadChoiceUrl = ""
    internal var downloadBusy = false
    internal var downloadCleared = false
    internal lateinit var navScrim: View
    internal lateinit var navPanel: LinearLayout
    internal val history = ArrayDeque<Page>()
    internal var fullscreen = false
    internal var seeking = false
    internal var editorFile: File? = null
    internal var downloadType = 0
    internal var downloadMode = 0
    internal var downloadFormat = 0
    internal var downloadQuality = 0
    internal var downloadAudio = 0
    internal var downloadAuth = 2
    internal var downloadPlatform = 0
    internal var cookieName = ""
    internal var draftUrl = ""
    internal var draftName = ""
    internal var draftStart = ""
    internal var draftEnd = ""
    internal var draftVolume = "1"
    internal var playbackQuality = "Source"
    internal var dark = true
    internal var notesOn = true
    internal var dragAnchor = 0f
    internal val dragShift = HashMap<View, Int>()
    internal var miniTitle: TextView? = null
    internal var miniPlay: Glyph? = null
    internal var playerSeek: SeekBar? = null
    internal var playerTime: TextView? = null
    internal var playerTotal: TextView? = null
    internal var playerPlay: Glyph? = null
    internal var playerArtist: TextView? = null
    internal var videoHost: FrameLayout? = null
    internal var motion = 0
    internal var closingSheet = false
    internal lateinit var session: MediaSession
    internal var noteKey = ""
    internal var askedNotes = false
    internal var noteDenied = false
    internal var notesDialog: AlertDialog? = null
    internal var serviceUp = false
    internal var cover: Bitmap? = null
    internal val metaCache = HashMap<String, Meta>()
    internal val metaLoading = HashSet<String>()
    internal val metaLabels = ArrayList<Pair<String, TextView>>()
    internal val ticker = Handler(Looper.getMainLooper())
    internal val tick = object : Runnable {
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

    internal var updateDownloadId = -1L
    internal var updateChecking = false
    internal var latestLine = ""
    internal var latestApk = ""

    internal val updateReceiver = object : BroadcastReceiver() {
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

    internal fun show() {
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

    internal fun open(page: Page) {
        motion = 1
        history.add(page)
        show()
    }

    internal fun EditText.remember(current: String, assign: (String) -> Unit): EditText {
        setText(current)
        addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) { assign(s?.toString().orEmpty()); saveTrim() }
        })
        return this
    }

    internal inner class Engine {
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

}
