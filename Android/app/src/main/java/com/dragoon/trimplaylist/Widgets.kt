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


internal fun MainActivity.platformKey() = "connected-$downloadPlatform"

internal fun MainActivity.cookiesDir() = File(filesDir, "cookies").apply { mkdirs() }

internal fun MainActivity.displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0) ?: "Track"
        }
        return uri.lastPathSegment ?: "Track"
    }

internal fun MainActivity.formatTime(ms: Int): String {
        val safe = ms.coerceAtLeast(0) / 1000
        val minutes = (safe % 3600) / 60
        val seconds = safe % 60
        val hours = safe / 3600
        return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, seconds) else "%d:%02d".format(minutes, seconds)
    }

internal fun MainActivity.toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_SHORT).show()

internal fun MainActivity.column(l: Int, t: Int, r: Int, b: Int) = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(l, t, r, b) }

internal fun MainActivity.row() = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }

internal fun MainActivity.label(value: String, size: Float, color: Int, bold: Boolean) = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(color)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

internal fun MainActivity.muted(value: String) = label(value, 13f, soft(), false)

internal fun MainActivity.caption(value: String) = muted(value).apply { setPadding(0, px(8), 0, px(4)) }

internal fun MainActivity.field(hint: String) = EditText(this).apply {
        this.hint = hint
        setTextColor(ink())
        setHintTextColor(soft())
        background = rounded(fieldBg(), 10)
        setPadding(px(12), px(12), px(12), px(12))
        setSingleLine(true)
    }

internal fun MainActivity.dialogField(hint: String) = EditText(this).apply {
        this.hint = hint
        setTextColor(Color.BLACK)
        setSingleLine(true)
    }

internal fun MainActivity.pad(child: View) = FrameLayout(this).apply { setPadding(px(16), px(8), px(16), 0); addView(child) }

internal fun MainActivity.solid(value: String, action: () -> Unit) = TextView(this).apply {
        text = value
        gravity = Gravity.CENTER
        setTextColor(Color.WHITE)
        textSize = 16f
        background = rounded(BRAND, 12)
        setPadding(px(12), px(12), px(12), px(12))
        layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = px(8) }
        setOnClickListener { action() }
    }

internal fun MainActivity.ghost(value: String, action: () -> Unit) = TextView(this).apply {
        text = value
        setTextColor(ink())
        textSize = 16f
        setPadding(px(10), px(8), px(10), px(8))
        setOnClickListener { action() }
    }

internal fun MainActivity.iconPill(kind: String, title: String, filled: Boolean, action: () -> Unit): LinearLayout {
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

internal fun MainActivity.pill(value: String, filled: Boolean, action: () -> Unit) = TextView(this).apply {
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

internal fun MainActivity.iconButton(kind: String, disc: Boolean, lit: Boolean, action: () -> Unit) = Glyph(this).apply {
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

internal fun MainActivity.space(width: Int) = View(this).apply { layoutParams = LinearLayout.LayoutParams(px(width), 1) }

internal fun MainActivity.spaceH(height: Int) = View(this).apply { layoutParams = LinearLayout.LayoutParams(1, px(height)) }

internal fun MainActivity.rounded(color: Int, radius: Int) = GradientDrawable().apply { setColor(color); cornerRadius = px(radius).toFloat() }

internal fun MainActivity.pageBg() = if (dark) Color.BLACK else Color.rgb(244, 245, 247)

internal fun MainActivity.cardBg() = if (dark) Color.rgb(28, 28, 28) else Color.WHITE

internal fun MainActivity.sheetBg() = if (dark) Color.rgb(48, 48, 48) else Color.rgb(232, 234, 238)

internal fun MainActivity.fieldBg() = if (dark) Color.rgb(30, 37, 50) else Color.rgb(255, 255, 255)

internal fun MainActivity.dialogBg() = if (dark) Color.rgb(42, 42, 46) else Color.WHITE

internal fun MainActivity.selectedBg() = if (dark) Color.rgb(36, 36, 36) else Color.rgb(226, 230, 236)

internal fun MainActivity.ink() = if (dark) Color.WHITE else Color.rgb(22, 24, 28)

internal fun MainActivity.soft() = if (dark) Color.rgb(181, 181, 181) else Color.rgb(90, 96, 105)

internal fun MainActivity.px(value: Int) = (value * resources.displayMetrics.density).toInt()

