package com.otamzo.vendor

import android.app.Application

class VendorApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize OneSignal before any other SDK call.
        OneSignalManager.initialize(this)
    }
}
