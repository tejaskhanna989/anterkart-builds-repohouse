plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // google-services enabled once google-services.json is present (Firebase setup pending).
}

import java.util.Properties

// Release signing material.
//
// `android/key.properties` and `android/app/upload-keystore.jks` are
// git-ignored, so they are not part of the repository. CI recreates both
// from the GitHub secrets right before the build. When they are missing the
// release build stays unsigned instead of failing, so a plain `flutter run`
// still works on a developer machine.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val releaseStoreFile = file(keystoreProperties.getProperty("storeFile") ?: "upload-keystore.jks")
val hasReleaseSigning = keystorePropertiesFile.exists() && releaseStoreFile.exists()

android {
    namespace = "com.otamzo.store"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                // v1 keeps devices older than Android 7 working, v2 and v3
                // are what Android 11 (API 30) requires.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    defaultConfig {
        applicationId = "com.otamzo.store"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Without the keystore the release build stays unsigned instead
            // of failing the whole build.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.onesignal:OneSignal:[5.0.0, 5.99.99]")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

// Force Kotlin stdlib to 2.0.0 to avoid metadata version mismatch with Kotlin 1.9.10 compiler
configurations.all {
    resolutionStrategy {
        force("org.jetbrains.kotlin:kotlin-stdlib:2.0.0")
        force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.0.0")
        force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.0.0")
    }
}
