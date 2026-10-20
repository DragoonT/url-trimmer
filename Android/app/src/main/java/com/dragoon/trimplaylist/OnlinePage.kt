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


internal fun MainActivity.onlinePage(): View {
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

internal fun MainActivity.addOnline(entries: List<Pair<String, String>>) {
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

