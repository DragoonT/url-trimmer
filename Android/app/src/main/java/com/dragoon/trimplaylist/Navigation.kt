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


internal fun MainActivity.titleBar(title: String): View {
        val line = row().apply { gravity = Gravity.CENTER_VERTICAL }
        val button = FrameLayout(this).apply {
            setOnClickListener { openNav() }
            layoutParams = LinearLayout.LayoutParams(px(40), px(40))
            addView(MenuIcon(this@titleBar, ink()), FrameLayout.LayoutParams(MATCH, MATCH))
        }
        line.addView(button)
        line.addView(label(title, 20f, ink(), true).apply { setPadding(px(12), 0, 0, 0) })
        return line
    }

internal fun MainActivity.buildNav() {
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

internal fun MainActivity.navItem(name: String, page: Page) = TextView(this).apply {
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

internal fun MainActivity.openNav() {
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

internal fun MainActivity.closeNav() {
        navScrim.animate().alpha(0f).setDuration(160).withEndAction { navScrim.visibility = View.GONE }.start()
        navPanel.animate().translationX(-px(260).toFloat()).setDuration(180).withEndAction { navPanel.visibility = View.GONE }.start()
    }

internal fun MainActivity.paintNav() {
        navPanel.setBackgroundColor(if (dark) Color.rgb(16, 18, 24) else Color.WHITE)
        for (i in 0 until navPanel.childCount) {
            val child = navPanel.getChildAt(i)
            if (child is TextView) child.setTextColor(if (child.tag is Page) ink() else soft())
        }
    }

internal fun MainActivity.applyBars() {
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

internal fun MainActivity.drop(parent: LinearLayout, captionText: String, options: List<String>, selected: Int, onPick: (Int) -> Unit) {
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

internal fun MainActivity.popup(anchor: View, options: List<String>, onPick: (String) -> Unit) {
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

