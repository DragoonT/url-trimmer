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


internal fun MainActivity.paintChoices(parent: LinearLayout, choices: List<Pair<String, String>>, picked: Set<Int>) {
        for (i in 0 until parent.childCount) {
            val child = parent.getChildAt(i) as? TextView ?: continue
            val index = child.tag as? Int ?: continue
            if (index !in choices.indices) continue
            val on = index in picked
            child.text = if (on) "✓  ${choices[index].first}" else "○  ${choices[index].first}"
            child.background = rounded(if (on) selectedBg() else fieldBg(), 10)
        }
    }

internal fun MainActivity.urlPage(): View {
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

internal fun MainActivity.cookiePicker(form: LinearLayout) {
        val names = cookiesDir().listFiles()?.filter { it.extension.equals("txt", true) }?.map { it.name } ?: emptyList()
        val options = listOf("No cookies") + names
        val selected = options.indexOf(cookieName).let { if (it < 0) 0 else it }
        drop(form, "Cookies", options, selected) { cookieName = if (it == 0) "" else options[it]; saveTrim() }
        form.addView(solid("Create new") { createCookie() })
    }

internal fun MainActivity.createCookie() {
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

internal fun MainActivity.editorPage(): View {
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

internal fun MainActivity.platformPicker(form: LinearLayout) {
        val names = listOf("YouTube", "Facebook", "Instagram", "X / Twitter", "TikTok", "Twitch")
        drop(form, "Platform", names, downloadPlatform) { downloadPlatform = it; saveTrim(); show() }
        val connected = getSharedPreferences("trim-playlist", MODE_PRIVATE).getBoolean(platformKey(), false)
        form.addView(muted(if (connected) "Signed in on this phone." else "Not signed in."))
        form.addView(solid(if (connected) "Open ${names[downloadPlatform]} again" else "Sign in to ${names[downloadPlatform]}") {
            open(Page.SIGNIN)
        })
    }

internal fun MainActivity.signInPage(): View {
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

internal fun MainActivity.externalFallback(uri: Uri): String? {
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

internal fun MainActivity.sessionSaved(): Boolean {
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

internal fun MainActivity.saveTrim() {
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

internal fun MainActivity.reportDownload(text: String, fraction: Float) {
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

internal fun MainActivity.placeDownload() {
        val showBar = !downloadCleared && history.lastOrNull() == Page.URL && downloadLabel.text.isNotBlank()
        downloadStrip.visibility = if (showBar) View.VISIBLE else View.GONE
    }

internal fun MainActivity.loadDownloadChoices(pageUrl: String) {
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

internal fun MainActivity.clock(value: String): Double {
        val parts = value.trim().split(":")
        if (parts.isEmpty() || parts.size > 3 || parts.any { it.isBlank() }) error("Use seconds, MM:SS or HH:MM:SS")
        return parts.fold(0.0) { total, part -> total * 60 + part.toDouble() }
    }

internal fun MainActivity.beginDownload(pages: List<String>, trimming: Boolean, trimStart: Double, trimEnd: Double, trimName: String) {
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

internal fun MainActivity.authCookieHeader(host: String): String? {
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

