pluginManagement {
    val flutterSdkPath =
        run {
            val envSdk = System.getenv("FLUTTER_ROOT")
            if (envSdk != null && envSdk.isNotEmpty()) envSdk
            else {
                val properties = java.util.Properties()
                val file = file("local.properties")
                if (file.exists()) {
                    file.inputStream().use { properties.load(it) }
                    properties.getProperty("flutter.sdk")
                } else null
            } ?: throw GradleException("flutter.sdk not found. Set FLUTTER_ROOT env var or create android/local.properties with flutter.sdk=/path/to/flutter")
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.2.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
