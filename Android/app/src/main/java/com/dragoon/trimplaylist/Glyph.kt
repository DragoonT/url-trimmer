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


internal class Glyph(context: android.content.Context) : View(context) {
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

