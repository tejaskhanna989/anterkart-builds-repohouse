package com.otamzo.store

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.onesignal.OneSignal
import com.onesignal.debug.LogLevel
import com.onesignal.user.subscriptions.IPushSubscriptionObserver
import com.onesignal.user.subscriptions.PushSubscriptionChangedState
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Centralized wrapper for every OneSignal SDK call on Android.
 *
 * All OneSignal interactions (init, identity, tags, permission, subscription
 * observation) go through here — no other native file calls the SDK directly.
 * The Dart side has its own twin wrapper (OneSignalService) for Flutter code;
 * both initialize with the same app id (native init runs first, Dart re-init
 * with the same id is idempotent).
 */
object OneSignalManager {
    const val ONESIGNAL_APP_ID = "99648958-99e9-4e1e-a015-96e4b512af7d"

    @Volatile
    private var isInitialized = false

    // Shown-once guard for the verification dialog (process lifetime).
    private val verificationDialogShown = AtomicBoolean(false)

    // OneSignal stores observers weakly — keep a strong, app-scoped reference
    // so the observer survives for the lifetime of the app.
    private var pushSubscriptionObserver: IPushSubscriptionObserver? = null

    @Synchronized
    fun initialize(context: Context) {
        if (isInitialized) return
        // Production-safe default: no verbose logging. Call setLogLevel()
        // explicitly when diagnosing (avoids depending on BuildConfig).
        OneSignal.Debug.logLevel = LogLevel.NONE
        OneSignal.initWithContext(context, ONESIGNAL_APP_ID)
        isInitialized = true
    }

    fun setLogLevel(level: LogLevel) {
        OneSignal.Debug.logLevel = level
    }

    fun login(externalId: String) {
        OneSignal.login(externalId)
    }

    fun logout() {
        OneSignal.logout()
    }

    fun setEmail(email: String) {
        OneSignal.User.addEmail(email)
    }

    fun setSmsNumber(number: String) {
        OneSignal.User.addSms(number)
    }

    fun setTag(key: String, value: String) {
        OneSignal.User.addTag(key, value)
    }

    fun requestPushPermission() {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                OneSignal.Notifications.requestPermission(true)
            } catch (ignored: Exception) {
            }
        }
    }

    // A real, server-assigned subscription id is non-empty and not the local-
    // placeholder the SDK assigns before the device registers.
    private fun isRegistered(subscriptionId: String?): Boolean =
        !subscriptionId.isNullOrEmpty() && !subscriptionId.startsWith("local-")

    private fun maybeShowIntegrationCompleteDialog(
        activity: Activity,
        subscriptionId: String?,
    ) {
        if (isRegistered(subscriptionId) && verificationDialogShown.compareAndSet(false, true)) {
            Handler(Looper.getMainLooper()).post {
                showIntegrationCompleteDialog(activity)
            }
        }
    }

    /**
     * Attach the push-subscription observer. Call once (e.g. from
     * MainActivity.onCreate). Evaluates the current id immediately as well,
     * since it may already be server-assigned before the observer attaches.
     */
    fun setupPushSubscriptionObserver(activity: Activity) {
        val observer = object : IPushSubscriptionObserver {
            override fun onPushSubscriptionChange(state: PushSubscriptionChangedState) {
                maybeShowIntegrationCompleteDialog(activity, state.current.id)
            }
        }
        pushSubscriptionObserver = observer
        OneSignal.User.pushSubscription.addObserver(observer)
        maybeShowIntegrationCompleteDialog(activity, OneSignal.User.pushSubscription.id)
    }

    private fun showIntegrationCompleteDialog(activity: Activity) {
        if (activity.isFinishing || activity.isDestroyed) return
        AlertDialog.Builder(activity)
            .setTitle("Your OneSignal SDK integration is complete!")
            .setMessage(
                "You can now send Push Notifications & In-App Messages through OneSignal. " +
                    "Tap below to enable push notifications.",
            )
            .setPositiveButton("Got it") { _, _ ->
                requestPushPermission()
            }
            .setCancelable(false)
            .show()
    }
}
