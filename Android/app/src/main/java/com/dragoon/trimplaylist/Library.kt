package com.dragoon.trimplaylist

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class Track(
    val title: String,
    val uri: String,
    val kind: String,
    val video: Boolean,
)

data class Playlist(
    var name: String,
    val tracks: MutableList<Track>,
)

/** Playlists and the last playback position, stored only on this device. */
class Library(context: Context) {
    private val prefs = context.getSharedPreferences("trim-playlist", Context.MODE_PRIVATE)
    val playlists = mutableListOf<Playlist>()
    var selected = 0
    var currentTrack = -1
    var positionMs = 0
    var repeatMode = 0
    var shuffle = false
    var volume = 1f

    init {
        load()
    }

    fun current(): Playlist = playlists[selected.coerceIn(playlists.indices)]

    fun save() {
        val list = JSONArray()
        playlists.forEach { playlist ->
            val tracks = JSONArray()
            playlist.tracks.forEach { track ->
                tracks.put(
                    JSONObject()
                        .put("title", track.title)
                        .put("uri", track.uri)
                        .put("kind", track.kind)
                        .put("video", track.video),
                )
            }
            list.put(JSONObject().put("name", playlist.name).put("tracks", tracks))
        }
        val root = JSONObject()
            .put("selected", selected)
            .put("currentTrack", currentTrack)
            .put("positionMs", positionMs)
            .put("repeatMode", repeatMode)
            .put("shuffle", shuffle)
            .put("volume", volume.toDouble())
            .put("playlists", list)
        prefs.edit().putString(KEY, root.toString()).apply()
    }

    private fun load() {
        val saved = prefs.getString(KEY, null)
        if (saved != null) {
            readRoot(saved)
        } else {
            migrateNamesOnly(prefs.getString("playlists", null))
        }
        if (playlists.isEmpty()) playlists += Playlist("My playlist", mutableListOf())
        selected = selected.coerceIn(playlists.indices)
        val count = current().tracks.size
        if (currentTrack !in 0 until count) currentTrack = -1
    }

    private fun readRoot(raw: String) {
        val root = JSONObject(raw)
        selected = root.optInt("selected")
        currentTrack = root.optInt("currentTrack", -1)
        positionMs = root.optInt("positionMs")
        repeatMode = root.optInt("repeatMode")
        shuffle = root.optBoolean("shuffle")
        volume = root.optDouble("volume", 1.0).toFloat().coerceIn(0f, 1f)
        val list = root.optJSONArray("playlists") ?: return
        for (i in 0 until list.length()) {
            val item = list.getJSONObject(i)
            val tracks = mutableListOf<Track>()
            val savedTracks = item.optJSONArray("tracks") ?: JSONArray()
            for (t in 0 until savedTracks.length()) {
                val track = savedTracks.optJSONObject(t) ?: continue
                tracks += Track(
                    title = track.optString("title", "Track"),
                    uri = track.optString("uri"),
                    kind = track.optString("kind", "file"),
                    video = track.optBoolean("video"),
                )
            }
            playlists += Playlist(item.optString("name", "Playlist"), tracks)
        }
    }

    private fun migrateNamesOnly(raw: String?) {
        if (raw.isNullOrBlank()) return
        val list = JSONArray(raw)
        for (i in 0 until list.length()) {
            val item = list.optJSONObject(i) ?: continue
            val tracks = mutableListOf<Track>()
            val saved = item.optJSONArray("tracks") ?: JSONArray()
            for (t in 0 until saved.length()) {
                val label = saved.optString(t)
                if (label.isBlank()) continue
                val url = label.removePrefix("ONLINE · ").trim()
                if (url.startsWith("http://") || url.startsWith("https://")) {
                    tracks += Track(url, url, "url", looksLikeVideo(url))
                } else {
                    tracks += Track(label.removePrefix("OFFLINE · ").trim(), "", "missing", false)
                }
            }
            playlists += Playlist(item.optString("name", "Playlist"), tracks)
        }
    }

    companion object {
        private const val KEY = "library-v2"

        fun looksLikeVideo(name: String): Boolean {
            val lower = name.lowercase().substringBefore('?')
            return listOf(".mp4", ".m4v", ".mov", ".mkv", ".webm", ".m3u8").any { lower.endsWith(it) }
        }
    }
}
