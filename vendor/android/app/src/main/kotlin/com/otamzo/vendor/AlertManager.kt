package com.otamzo.vendor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * Native side of the hard-to-miss new-order alert.
 *
 * Android blocks a background app from jumping to the front on its own, so a
 * new order relies on three mechanisms working together:
 *   1. the alarm stream is forced to maximum, so the app's looping alarm sound
 *      is as loud as the phone physically allows;
 *   2. a high-importance notification with a full-screen intent wakes the
 *      screen and shows the app over the lock screen;
 *   3. when the "Display over other apps" permission is granted (or the moment
 *      the user unlocks the phone) the activity is launched directly.
 *
 * The looping sound itself is played by the Flutter layer (OrderAlarm); this
 * class only makes sure the phone is loud, awake and showing the app.
 */
object AlertManager {
    private const val CHANNEL_ID = "otamzo_order_alerts"
    private const val NOTIF_ID = 871230

    private var wakeLock: PowerManager.WakeLock? = null
    private var unlockReceiver: BroadcastReceiver? = null
    private var appContext: Context? = null
    private var lastTitle = "New order"
    private var lastBody = ""
    private var lastOrderId = 0
    private var alarmPlayer: MediaPlayer? = null

    fun start(context: Context, title: String, body: String, orderId: Int) {
        val ctx = context.applicationContext
        appContext = ctx
        lastTitle = title
        lastBody = body
        lastOrderId = orderId

        raiseAlarmVolume(ctx)
        startAlarmAudio(ctx)
        acquireWakeLock(ctx)
        ensureChannel(ctx)
        showFullScreenNotification(ctx)
        registerUnlockReceiver(ctx)
        launchActivity(ctx)
    }

    fun stop(context: Context?) {
        val ctx = context?.applicationContext ?: appContext ?: return
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIF_ID)
        } catch (_: Throwable) {
        }
        releaseWakeLock()
        stopAlarmAudio()
        unregisterUnlockReceiver(ctx)
        lastOrderId = 0
    }

    fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    fun pendingAlertOrderId(): Int = lastOrderId

    fun requestOverlayPermission(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + context.packageName),
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (_: Throwable) {
        }
    }

    fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 34) {
            return try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.canUseFullScreenIntent()
            } catch (_: Throwable) {
                true
            }
        }
        return true
    }

    private fun raiseAlarmVolume(ctx: Context) {
        try {
            val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxAlarm = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            am.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
        } catch (_: Throwable) {
        }
    }

    // The Flutter asset is bundled uncompressed in the APK and can also be
    // played by this native path when Flutter/Dart is not running yet.
    @Synchronized
    private fun startAlarmAudio(ctx: Context) {
        if (alarmPlayer?.isPlaying == true) return
        stopAlarmAudio()
        try {
            val afd = ctx.assets.openFd("flutter_assets/assets/audio/new_order_alarm.wav")
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            player.isLooping = true
            player.setVolume(1f, 1f)
            player.setOnPreparedListener { it.start() }
            player.prepareAsync()
            alarmPlayer = player
        } catch (_: Throwable) {
            stopAlarmAudio()
        }
    }

    @Synchronized
    private fun stopAlarmAudio() {
        try { alarmPlayer?.stop() } catch (_: Throwable) {}
        try { alarmPlayer?.release() } catch (_: Throwable) {}
        alarmPlayer = null
    }

    private fun acquireWakeLock(ctx: Context) {
        if (wakeLock != null) return
        try {
            val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "otamzo:order_alert")
            wl.setReferenceCounted(false)
            wl.acquire(10 * 60 * 1000L)
            wakeLock = wl
        } catch (_: Throwable) {
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.release()
        } catch (_: Throwable) {
        }
        wakeLock = null
    }

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(CHANNEL_ID, "Order alerts", NotificationManager.IMPORTANCE_HIGH)
                ch.description = "New orders and delivery offers"
                ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                ch.setSound(null, null)
                ch.enableVibration(true)
                nm.createNotificationChannel(ch)
            }
        } catch (_: Throwable) {
        }
    }

    private fun activityIntent(ctx: Context): Intent? {
        val i = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
        i.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
        )
        i.putExtra("otamzo_alert_order", lastOrderId)
        return i
    }

    private fun showFullScreenNotification(ctx: Context) {
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val pi = PendingIntent.getActivity(
                ctx,
                0,
                activityIntent(ctx) ?: Intent(),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(ctx, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(ctx)
            }
            builder
                .setSmallIcon(ctx.applicationInfo.icon)
                .setContentTitle(lastTitle)
                .setContentText(lastBody)
                .setAutoCancel(true)
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_ALARM)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setContentIntent(pi)
                .setFullScreenIntent(pi, true)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                builder.setPriority(Notification.PRIORITY_MAX)
            }
            nm.notify(NOTIF_ID, builder.build())
        } catch (_: Throwable) {
        }
    }

    private fun launchActivity(ctx: Context) {
        if (!canDrawOverlays(ctx)) return
        try {
            val i = activityIntent(ctx) ?: return
            ctx.startActivity(i)
        } catch (_: Throwable) {
        }
    }

    private fun registerUnlockReceiver(ctx: Context) {
        if (unlockReceiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_USER_PRESENT) {
                    launchActivity(c?.applicationContext ?: ctx)
                }
            }
        }
        try {
            ctx.registerReceiver(r, IntentFilter(Intent.ACTION_USER_PRESENT))
            unlockReceiver = r
        } catch (_: Throwable) {
        }
    }

    private fun unregisterUnlockReceiver(ctx: Context) {
        val r = unlockReceiver ?: return
        try {
            ctx.unregisterReceiver(r)
        } catch (_: Throwable) {
        }
        unlockReceiver = null
    }
}
