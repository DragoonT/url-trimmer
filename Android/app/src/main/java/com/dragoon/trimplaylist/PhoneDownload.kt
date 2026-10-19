package com.dragoon.trimplaylist

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer

/** Saves a direct file or a YouTube video onto this phone and reports 0–1 progress. */
object PhoneDownload {
    private const val CHROME = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    data class Item(val title: String, val url: String, val ext: String, val video: Boolean, val audioUrl: String? = null, val fallbackUrl: String? = null)

    fun items(pageUrl: String, audio: Boolean, maxHeight: Int, cookie: String?): List<Item> {
        val list = Regex("[?&]list=([A-Za-z0-9_-]+)").find(pageUrl)?.groupValues?.get(1)
        val ids = when {
            list != null && (pageUrl.contains("youtube.com") || pageUrl.contains("youtu.be")) -> playlistIds(list, cookie)
            pageUrl.contains("youtube.com") || pageUrl.contains("youtu.be") -> listOf(videoId(pageUrl) ?: error("That YouTube link has no video"))
            else -> return listOf(directItem(pageUrl, cookie))
        }
        return ids.map { stream(it, audio, maxHeight, cookie) }
    }

    fun catalog(pageUrl: String, cookie: String?): List<Pair<String, String>> {
        val youtube = pageUrl.contains("youtube.com") || pageUrl.contains("youtu.be")
        if (!youtube) {
            val name = pageUrl.substringBefore('?').substringAfterLast('/').ifBlank { "Online" }
            return listOf(name to pageUrl)
        }
        val list = Regex("[?&]list=([A-Za-z0-9_-]+)").find(pageUrl)?.groupValues?.get(1)
        if (list != null) {
            return playlistEntries(list, cookie).map { (id, title) -> title to "https://www.youtube.com/watch?v=$id" }
        }
        val id = videoId(pageUrl) ?: error("That YouTube link has no video")
        val title = runCatching { stream(id, false, 0, cookie).title.substringBefore(" · ") }.getOrDefault(id)
        return listOf(title to "https://www.youtube.com/watch?v=$id")
    }

    fun playback(pageUrl: String, audio: Boolean, cookie: String?): String {
        val youtube = pageUrl.contains("youtube.com") || pageUrl.contains("youtu.be")
        if (!youtube) return pageUrl
        val id = videoId(pageUrl) ?: error("That YouTube link has no video")
        return stream(id, audio, 0, cookie, split = false).url
    }

    private fun videoId(url: String) = Regex("(?:v=|youtu\\.be/|shorts/|embed/)([A-Za-z0-9_-]{11})").find(url)?.groupValues?.get(1)

    private fun playlistIds(id: String, cookie: String?): List<String> {
        val fromApi = runCatching {
            val body = """{"browseId":"VL$id","context":{"client":{"clientName":"WEB","clientVersion":"2.20250301.01.00","hl":"en"}}}"""
            idsIn(post("https://www.youtube.com/youtubei/v1/browse?prettyPrint=false", body, cookie, mapOf("User-Agent" to CHROME)))
        }.getOrDefault(emptyList())
        if (fromApi.isNotEmpty()) return fromApi
        val page = get(
            "https://www.youtube.com/playlist?list=$id",
            cookie,
            mapOf("User-Agent" to CHROME, "Accept-Language" to "en"),
        )
        val fromPage = idsIn(page)
        if (fromPage.isEmpty()) error("No videos were found in that playlist")
        return fromPage
    }

    private fun playlistEntries(id: String, cookie: String?): List<Pair<String, String>> {
        val page = get(
            "https://www.youtube.com/playlist?list=$id",
            cookie,
            mapOf("User-Agent" to CHROME, "Accept-Language" to "en"),
        )
        val titles = linkedMapOf<String, String>()
        val marker = Regex(""""videoId":"([A-Za-z0-9_-]{11})"""")
        var from = 0
        while (from < page.length) {
            val hit = marker.find(page, from) ?: break
            val video = hit.groupValues[1]
            val window = page.substring(hit.range.last, minOf(page.length, hit.range.last + 900))
            val text = Regex(""""title":\{"runs":\[\{"text":"((?:\\.|[^"\\])*)"""").find(window)?.groupValues?.get(1)
            if (!text.isNullOrBlank() && video !in titles) titles[video] = jsonText(text)
            from = hit.range.last
        }
        val ids = if (titles.isEmpty()) idsIn(page) else titles.keys.toList()
        if (ids.isEmpty()) error("No videos were found in that playlist")
        return ids.map { it to (titles[it] ?: it) }
    }

    private fun jsonText(raw: String) = raw.replace("\\\"", "\"").replace("\\u0026", "&").replace("\\/", "/").replace("\\\\", "\\")

    private fun idsIn(text: String) = Regex(""""videoId":"([A-Za-z0-9_-]{11})"""").findAll(text).map { it.groupValues[1] }.distinct().toList()

    private fun stream(id: String, audio: Boolean, maxHeight: Int, cookie: String?, split: Boolean = true): Item {
        val body = """{"videoId":"$id","context":{"client":{"clientName":"ANDROID","clientVersion":"20.10.38","androidSdkVersion":30,"hl":"en","gl":"US"}}}"""
        val headers = mapOf("User-Agent" to "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip")
        val player = "https://www.youtube.com/youtubei/v1/player?prettyPrint=false"
        var text = post(player, body, null, headers)
        var root = JSONObject(text)
        var status = root.optJSONObject("playabilityStatus")?.optString("status").orEmpty()
        if (status == "LOGIN_REQUIRED" && !cookie.isNullOrBlank()) {
            text = post(player, body, cookie, headers)
            root = JSONObject(text)
            status = root.optJSONObject("playabilityStatus")?.optString("status").orEmpty()
        }
        if (status == "LOGIN_REQUIRED") {
            error(if (cookie.isNullOrBlank()) "Sign in to YouTube, then start the download again" else "YouTube did not accept the saved login for this video")
        }
        val playability = root.optJSONObject("playabilityStatus")
        if (playability != null && status != "OK") error(playability.optString("reason").ifBlank { "YouTube did not allow this video" })
        val title = root.optJSONObject("videoDetails")?.optString("title").orEmpty().ifBlank { id }
        val streaming = root.optJSONObject("streamingData") ?: error("YouTube did not give a file for $title")
        val combined = runCatching { pickVideo(streaming, maxHeight).optString("url") }.getOrNull()?.takeIf { it.isNotBlank() }
        if (!audio && split) {
            val picture = pickHighVideo(streaming, maxHeight)
            val sound = runCatching { pickAudio(streaming) }.getOrNull()
            if (picture != null && sound != null) {
                val height = picture.optInt("height")
                return Item("$title · ${height}p", picture.optString("url"), "mp4", true, sound.optString("url"), combined)
            }
        }
        val chosen = if (audio) pickAudio(streaming) else pickVideo(streaming, maxHeight)
        val ext = when {
            chosen.optString("mimeType").contains("webm") && audio -> "webm"
            chosen.optString("mimeType").contains("audio") -> "m4a"
            else -> "mp4"
        }
        val address = chosen.optString("url")
        return Item(title, address, ext, !audio, fallbackUrl = combined?.takeIf { it != address })
    }

    private fun pickHighVideo(streaming: JSONObject, maxHeight: Int): JSONObject? {
        val rows = streaming.optJSONArray("adaptiveFormats") ?: return null
        var best: JSONObject? = null
        for (i in 0 until rows.length()) {
            val item = rows.getJSONObject(i)
            val mime = item.optString("mimeType")
            if (!mime.startsWith("video/mp4") || !mime.contains("avc1") || item.optString("url").isBlank()) continue
            val height = item.optInt("height")
            if (height <= 0 || (maxHeight > 0 && height > maxHeight)) continue
            if (best == null || height > best.optInt("height")) best = item
        }
        return best
    }

    private fun pickAudio(streaming: JSONObject): JSONObject {
        val rows = streaming.optJSONArray("adaptiveFormats") ?: JSONArray()
        var best: JSONObject? = null
        for (i in 0 until rows.length()) {
            val item = rows.getJSONObject(i)
            if (!item.optString("mimeType").startsWith("audio/") || item.optString("url").isBlank()) continue
            val current = best
            if (current == null) {
                best = item
                continue
            }
            val itemMp4 = item.optString("mimeType").contains("mp4")
            val currentMp4 = current.optString("mimeType").contains("mp4")
            if ((itemMp4 && !currentMp4) || (itemMp4 == currentMp4 && item.optInt("bitrate") > current.optInt("bitrate"))) best = item
        }
        return best ?: error("YouTube locked this file. Sign-in covers private videos. The Windows app unlocks signed files and can cut or convert them.")
    }

    private fun pickVideo(streaming: JSONObject, maxHeight: Int): JSONObject {
        val rows = streaming.optJSONArray("formats") ?: JSONArray()
        var best: JSONObject? = null
        for (i in 0 until rows.length()) {
            val item = rows.getJSONObject(i)
            if (item.optString("url").isBlank()) continue
            val height = item.optInt("height")
            if (maxHeight > 0 && height > maxHeight) continue
            if (best == null || height > best.optInt("height")) best = item
        }
        if (best == null) {
            for (i in 0 until rows.length()) {
                val item = rows.getJSONObject(i)
                if (item.optString("url").isNotBlank()) best = item
            }
        }
        return best ?: error("YouTube locked this file. Sign-in covers private videos. The Windows app unlocks signed files and can cut or convert them.")
    }

    private fun directItem(pageUrl: String, cookie: String?): Item {
        val connection = open(pageUrl, cookie, null)
        connection.requestMethod = "GET"
        connection.instanceFollowRedirects = true
        val code = connection.responseCode
        val type = connection.contentType.orEmpty()
        connection.disconnect()
        if (code >= 400) error("The link returned $code")
        if (type.startsWith("text/html")) error("That page is not a media file this phone can save")
        val path = pageUrl.substringBefore('?').substringAfterLast('/')
        val ext = path.substringAfterLast('.', "mp4").lowercase().take(4)
        val video = type.startsWith("video") || ext in setOf("mp4", "m4v", "mov", "mkv", "webm")
        return Item(path.ifBlank { "Download" }, pageUrl, if (ext.length in 2..4) ext else if (video) "mp4" else "m4a", video)
    }

    fun save(dir: File, item: Item, cookie: String?, onProgress: (Float) -> Unit): File {
        dir.mkdirs()
        try {
            return saveParts(dir, item, cookie, onProgress)
        } catch (error: Exception) {
            val fallback = item.fallbackUrl
            if (fallback.isNullOrBlank() || error.message?.contains("403") != true) throw error
            return fetch(dir, item.title, "mp4", fallback, null, onProgress)
        }
    }

    private fun saveParts(dir: File, item: Item, cookie: String?, onProgress: (Float) -> Unit): File {
        val audioUrl = item.audioUrl
        if (audioUrl.isNullOrBlank()) return fetch(dir, item.title, item.ext, item.url, cookie, onProgress)
        val videoPart = unique(dir, "${item.title} picture", "mp4")
        val audioPart = unique(dir, "${item.title} sound", "m4a")
        val combined = unique(dir, item.title, "mp4")
        try {
            fetchTo(videoPart, item.url, cookie) { onProgress(it * 0.8f) }
            fetchTo(audioPart, audioUrl, cookie) { onProgress(0.8f + it * 0.15f) }
            onProgress(0.96f)
            join(videoPart, audioPart, combined)
            onProgress(1f)
        } finally {
            videoPart.delete()
            audioPart.delete()
        }
        return combined
    }

    private fun fetch(dir: File, title: String, ext: String, url: String, cookie: String?, onProgress: (Float) -> Unit): File {
        val file = unique(dir, title, ext)
        fetchTo(file, url, cookie, onProgress)
        return file
    }

    private fun fetchTo(file: File, url: String, cookie: String?, onProgress: (Float) -> Unit) {
        val host = runCatching { URL(url).host.orEmpty() }.getOrDefault("")
        val mediaCookie = if (host.endsWith("youtube.com") || host.endsWith("youtu.be")) cookie else null
        val connection = open(url, mediaCookie, mapOf("User-Agent" to "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip"))
        connection.instanceFollowRedirects = true
        connection.connectTimeout = 20000
        connection.readTimeout = 0
        val code = connection.responseCode
        if (code >= 400) {
            connection.disconnect()
            error("Download stopped ($code)")
        }
        val total = connection.contentLengthLong
        if (total <= 0) onProgress(-1f)
        connection.inputStream.use { input ->
            FileOutputStream(file).use { output ->
                val buffer = ByteArray(64 * 1024)
                var got = 0L
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    output.write(buffer, 0, count)
                    got += count
                    if (total > 0) onProgress(got.toFloat() / total)
                }
            }
        }
        connection.disconnect()
        onProgress(1f)
    }

    private fun join(video: File, audio: File, out: File) {
        val videoSource = MediaExtractor()
        val audioSource = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            videoSource.setDataSource(video.absolutePath)
            audioSource.setDataSource(audio.absolutePath)
            val videoTrack = track(videoSource, "video/")
            val audioTrack = track(audioSource, "audio/")
            videoSource.selectTrack(videoTrack)
            audioSource.selectTrack(audioTrack)
            muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val videoOut = muxer.addTrack(videoSource.getTrackFormat(videoTrack))
            val audioOut = muxer.addTrack(audioSource.getTrackFormat(audioTrack))
            muxer.start()
            writeTrack(videoSource, muxer, videoOut)
            writeTrack(audioSource, muxer, audioOut)
            muxer.stop()
        } catch (error: Exception) {
            out.delete()
            throw error
        } finally {
            muxer?.release()
            videoSource.release()
            audioSource.release()
        }
    }

    private fun track(source: MediaExtractor, prefix: String): Int {
        for (index in 0 until source.trackCount) {
            val format = source.getTrackFormat(index)
            val mime = if (format.containsKey(MediaFormat.KEY_MIME)) format.getString(MediaFormat.KEY_MIME).orEmpty() else ""
            if (mime.startsWith(prefix)) return index
        }
        error("Could not join the high quality video and its audio")
    }

    private fun writeTrack(source: MediaExtractor, muxer: MediaMuxer, track: Int) {
        val buffer = ByteBuffer.allocate(4 * 1024 * 1024)
        val info = MediaCodec.BufferInfo()
        while (true) {
            val size = source.readSampleData(buffer, 0)
            if (size < 0) break
            val flags = if (source.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
            info.set(0, size, source.sampleTime, flags)
            muxer.writeSampleData(track, buffer, info)
            source.advance()
        }
    }

    private fun post(url: String, body: String, cookie: String?, extra: Map<String, String> = emptyMap()): String {
        val connection = open(url, cookie, extra + mapOf("Content-Type" to "application/json"))
        connection.requestMethod = "POST"
        connection.doOutput = true
        connection.outputStream.use { it.write(body.toByteArray()) }
        return read(connection)
    }

    private fun get(url: String, cookie: String?, extra: Map<String, String>): String {
        val connection = open(url, cookie, extra)
        connection.requestMethod = "GET"
        connection.instanceFollowRedirects = true
        return read(connection)
    }

    private fun read(connection: HttpURLConnection): String {
        val code = connection.responseCode
        val stream = if (code >= 400) connection.errorStream else connection.inputStream
        val text = stream?.bufferedReader()?.readText().orEmpty()
        connection.disconnect()
        if (code >= 400) error("YouTube returned $code")
        return text
    }

    private fun open(url: String, cookie: String?, extra: Map<String, String>?): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 20000
        connection.readTimeout = 30000
        connection.setRequestProperty("User-Agent", "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip")
        if (!cookie.isNullOrBlank()) connection.setRequestProperty("Cookie", cookie)
        extra?.forEach { (key, value) -> connection.setRequestProperty(key, value) }
        return connection
    }

    fun cut(source: File, startSec: Double, endSec: Double, title: String): File {
        val ext = source.extension.ifBlank { "mp4" }
        val dest = File(source.parentFile, "${source.name}.cut.$ext")
        val probe = MediaExtractor()
        probe.setDataSource(source.absolutePath)
        val chosen = mutableListOf<Int>()
        var videoTrack = -1
        for (index in 0 until probe.trackCount) {
            val mime = probe.getTrackFormat(index).getString(MediaFormat.KEY_MIME).orEmpty()
            if (mime.startsWith("video/") && videoTrack < 0) videoTrack = index
            if (mime.startsWith("video/") || mime.startsWith("audio/")) chosen += index
        }
        probe.release()
        if (chosen.isEmpty()) error("Could not trim that file")
        val startUs = (startSec * 1_000_000).toLong()
        val endUs = (endSec * 1_000_000).toLong()
        var origin = startUs
        if (videoTrack >= 0) {
            val finder = MediaExtractor()
            finder.setDataSource(source.absolutePath)
            finder.selectTrack(videoTrack)
            finder.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            if (finder.sampleTime >= 0) origin = finder.sampleTime
            finder.release()
        }
        val muxer = MediaMuxer(dest.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var wrote = false
        try {
            val outputs = chosen.map { index ->
                val format = MediaExtractor().also {
                    it.setDataSource(source.absolutePath)
                }.let { extractor ->
                    val format = extractor.getTrackFormat(index)
                    extractor.release()
                    format
                }
                muxer.addTrack(format)
            }
            muxer.start()
            chosen.forEachIndexed { index, track ->
                val extractor = MediaExtractor()
                extractor.setDataSource(source.absolutePath)
                extractor.selectTrack(track)
                extractor.seekTo(origin, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
                val buffer = ByteBuffer.allocate(1024 * 1024)
                val info = MediaCodec.BufferInfo()
                while (true) {
                    val size = extractor.readSampleData(buffer, 0)
                    if (size < 0) break
                    val time = extractor.sampleTime
                    if (time < 0 || time >= endUs) break
                    if (time >= origin) {
                        val flags = if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
                        info.set(0, size, time - origin, flags)
                        muxer.writeSampleData(outputs[index], buffer, info)
                        wrote = true
                    }
                    extractor.advance()
                }
                extractor.release()
            }
            if (!wrote) error("That range is outside the file")
            muxer.stop()
        } catch (error: Exception) {
            dest.delete()
            runCatching { muxer.release() }
            throw error
        }
        muxer.release()
        val named = unique(source.parentFile ?: dest.parentFile, title.ifBlank { source.nameWithoutExtension }, ext)
        if (!dest.renameTo(named)) dest.copyTo(named, overwrite = true).also { dest.delete() }
        source.delete()
        return named
    }

    private fun unique(dir: File, title: String, ext: String): File {
        val clean = title.replace(Regex("""[\\/:*?"<>|]"""), " ").trim().take(80).ifBlank { "track" }
        var file = File(dir, "$clean.$ext")
        var n = 2
        while (file.exists()) {
            file = File(dir, "$clean $n.$ext")
            n += 1
        }
        return file
    }
}
