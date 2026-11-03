package com.otamzo.store

import android.app.Application

class StoreApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize OneSignal before any other SDK call.
        OneSignalManager.initialize(this)
    }
}
