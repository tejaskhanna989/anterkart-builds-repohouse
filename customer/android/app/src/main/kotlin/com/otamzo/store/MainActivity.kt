package com.otamzo.store

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize OneSignal before any other calls
        OneSignalManager.initialize(this)
        // Observe push-subscription registration; shows the one-time
        // verification dialog once the device registers with OneSignal.
        OneSignalManager.setupPushSubscriptionObserver(this)
    }
}
