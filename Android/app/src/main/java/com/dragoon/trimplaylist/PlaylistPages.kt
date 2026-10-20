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


internal fun MainActivity.listPage(): View {
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

internal fun MainActivity.detailPage(): View {
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

internal fun MainActivity.playlistMenu(index: Int) {
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

internal fun MainActivity.addDownload() {
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

internal fun MainActivity.pickMedia() {
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("audio/*", "video/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }, PICK_MEDIA)
    }

internal fun MainActivity.addPickedMedia(data: Intent) {
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

internal fun MainActivity.removeTrack(index: Int) {
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

internal fun MainActivity.createPlaylist() {
        prompt("New playlist", "", "Create") { name ->
            val title = name.ifBlank { "New playlist" }
            library.playlists += Playlist(title, mutableListOf())
            library.selected = library.playlists.lastIndex
            library.currentTrack = -1
            library.save()
            open(Page.DETAIL)
        }
    }

internal fun MainActivity.renamePlaylist(index: Int) {
        prompt("Rename", library.playlists[index].name, "Save") { name ->
            if (name.isNotEmpty()) library.playlists[index].name = name
            library.save()
            show()
        }
    }

internal fun MainActivity.prompt(title: String, value: String, ok: String, done: (String) -> Unit) {
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

internal fun MainActivity.deletePlaylist(index: Int) {
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

internal fun MainActivity.importCookie(uri: Uri?) {
        if (uri == null) return
        val name = displayName(uri).ifBlank { "imported.txt" }.let { if (it.endsWith(".txt")) it else "$it.txt" }
        val text = contentResolver.openInputStream(uri)?.bufferedReader()?.readText().orEmpty()
        File(cookiesDir(), name).writeText(text)
        cookieName = name
        saveTrim()
        toast("Imported $name")
        show()
    }

internal fun MainActivity.trackRow(index: Int, track: Track, songs: LinearLayout, scroller: ScrollView, selected: Int): View {
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
                AlertDialog.Builder(this@trackRow)
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

internal fun MainActivity.dragSong(songs: LinearLayout, scroller: ScrollView, row: View, selected: Int, event: MotionEvent): Boolean {
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

internal fun MainActivity.hoverIndex(songs: LinearLayout, row: View): Int {
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

internal fun MainActivity.relocate(from: Int, to: Int) {
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

