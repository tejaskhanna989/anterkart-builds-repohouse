package com.otamzo.rider

import android.app.Application

class RiderApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize OneSignal before any other SDK call.
        OneSignalManager.initialize(this)
    }
}
