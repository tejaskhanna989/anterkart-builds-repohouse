package com.otamzo.rider

import androidx.annotation.Keep
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

/** Starts the native alarm path even when Flutter is not running. */
@Keep
class OrderNotificationExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        // Ignore stale pushes when the rider is signed out; otherwise the
        // native alarm can ring without an authenticated offer inbox.
        val prefs = event.context.getSharedPreferences("FlutterSharedPreferences", 0)
        if (prefs.getString("flutter.rider_token", null).isNullOrBlank() ||
            prefs.getString("flutter.rider_data", null).isNullOrBlank()
        ) return

        val notification = event.notification
        val data = notification.additionalData ?: return
        val type = data.optString("type", "")
        if (type !in setOf("driver_offer", "driver_offer_ping")) return
        val orderId = data.optInt("order_id", 0)
        AlertManager.start(
            event.context,
            notification.title?.takeIf { it.isNotBlank() } ?: "New Delivery Offer",
            notification.body ?: "A delivery offer is waiting. Respond now.",
            orderId,
        )
    }
}
