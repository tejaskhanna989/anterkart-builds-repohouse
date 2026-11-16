package com.otamzo.vendor

import androidx.annotation.Keep
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

/** Starts the native alarm path even when Flutter is not running. */
@Keep
class OrderNotificationExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        // A push can outlive the local sign-in. Do not start an alarm if the
        // app has no persisted vendor session to load and act on the order.
        val prefs = event.context.getSharedPreferences("FlutterSharedPreferences", 0)
        if (prefs.getString("flutter.vendor_token", null).isNullOrBlank() ||
            prefs.getString("flutter.vendor_data", null).isNullOrBlank()
        ) return

        val notification = event.notification
        val data = notification.additionalData ?: return
        val type = data.optString("type", "")
        if (type !in setOf("new_order", "new_order_ping")) return
        val orderId = data.optInt("order_id", 0)
        AlertManager.start(
            event.context,
            notification.title?.takeIf { it.isNotBlank() } ?: "New Order!",
            notification.body ?: "A new order is waiting. Respond now.",
            orderId,
        )
    }
}
