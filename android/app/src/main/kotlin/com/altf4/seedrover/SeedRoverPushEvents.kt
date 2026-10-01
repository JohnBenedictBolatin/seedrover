package com.altf4.seedrover

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object SeedRoverPushEvents {
    @Volatile
    var tokenSink: EventChannel.EventSink? = null

    @Volatile
    var foregroundMessageSink: EventChannel.EventSink? = null

    @Volatile
    var notificationTapSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun tokenRefreshed(token: String) {
        mainHandler.post { tokenSink?.success(token) }
    }

    fun foregroundMessage(message: Map<String, Any?>) {
        mainHandler.post { foregroundMessageSink?.success(message) }
    }

    fun notificationTapped(route: String) {
        mainHandler.post { notificationTapSink?.success(route) }
    }
}
