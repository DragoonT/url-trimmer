package com.dragoon.trimplaylist

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * After an in-app update, Android replaces the package and kills the process.
 * Alarms from the old process are cleared, so relaunch here when the new build is installed.
 */
class PackageReplacedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        launch.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP,
        )
        context.startActivity(launch)
    }
}
