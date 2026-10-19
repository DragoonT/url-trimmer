package com.dragoon.trimplaylist

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/** Keeps the playing song on the shade and the lock screen while audio continues. */
class PlaybackService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            PREV, NEXT, TOGGLE -> {
                PlaybackBridge.onAction?.invoke(intent.action!!)
                return START_NOT_STICKY
            }
        }
        val note = if (Build.VERSION.SDK_INT >= 33) {
            intent?.getParcelableExtra("note", Notification::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra("note")
        } ?: return START_NOT_STICKY
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTE_ID, note)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        const val NOTE_ID = 7
        const val PREV = "trimplaylist.prev"
        const val NEXT = "trimplaylist.next"
        const val TOGGLE = "trimplaylist.toggle"
    }
}

object PlaybackBridge {
    var onAction: ((String) -> Unit)? = null
}
