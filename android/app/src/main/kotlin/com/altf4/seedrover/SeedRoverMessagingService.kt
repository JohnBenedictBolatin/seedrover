package com.altf4.seedrover

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class SeedRoverMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        SeedRoverPushEvents.tokenRefreshed(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val notificationData = message.data.toMutableMap()
        message.notification?.title?.let { notificationData["title"] = it }
        message.notification?.body?.let { notificationData["body"] = it }
        if (notificationData["title"].isNullOrBlank() &&
            notificationData["body"].isNullOrBlank()
        ) {
            return
        }

        SeedRoverPushEvents.foregroundMessage(notificationData)
    }
}
