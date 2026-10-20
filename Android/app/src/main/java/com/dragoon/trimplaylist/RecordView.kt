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


internal class RecordView(context: android.content.Context) : View(context) {
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

