package com.otamzo.rider

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val alertChannel = "otamzo/alert"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize OneSignal before any other calls
        OneSignalManager.initialize(this)
        // Observe push-subscription registration; shows the one-time
        // verification dialog once the device registers with OneSignal.
        OneSignalManager.setupPushSubscriptionObserver(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Bridge for the hard-to-miss offer alert (max volume, wake screen,
        // full-screen notification, auto-launch on unlock).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alertChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlert" -> {
                    AlertManager.start(
                        this,
                        call.argument<String>("title") ?: "New delivery offer",
                        call.argument<String>("body") ?: "",
                        call.argument<Int>("orderId") ?: 0,
                    )
                    result.success(true)
                }
                "stopAlert" -> {
                    AlertManager.stop(this)
                    result.success(true)
                }
                "canDrawOverlays" -> result.success(AlertManager.canDrawOverlays(this))
                "pendingAlertOrderId" -> result.success(AlertManager.pendingAlertOrderId())
                "requestOverlayPermission" -> {
                    AlertManager.requestOverlayPermission(this)
                    result.success(true)
                }
                "canUseFullScreenIntent" -> result.success(AlertManager.canUseFullScreenIntent(this))
                else -> result.notImplemented()
            }
        }
    }
}
