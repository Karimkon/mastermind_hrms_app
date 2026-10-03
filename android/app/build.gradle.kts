import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing key properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// The Android API floor, declared here rather than inherited.
//
// Upgrading Flutter moved flutter.minSdkVersion from 21 to 24, and the next
// bundle stopped supporting 22,228 device models Play had been serving - every
// Android 5.0, 5.1 and 6.0 handset. Nobody chose that; it arrived with a tool
// upgrade, and plenty of client-site staff are on those phones.
//
// It cannot be undone, and the reasons are worth writing down so nobody spends
// another afternoon on it:
//
//   Flutter 3.38.5        errors below 23, warns below 24
//   record_android 1.5.2  minSdk 23      (voice notes in staff chat)
//   shared_preferences    minSdk 24      (hardcoded in 2.4.23 - auth token store)
//   flutter_local_notif.  minSdk 24      (hardcoded in 22.3.0)
//
// So Android 5.0 and 5.1 are gone whatever we do - Flutter will not build for
// them. Android 6.0 alone could be bought back, and only by downgrading
// shared_preferences and flutter_local_notifications, which hold the auth token
// and the notification pipeline. That is not a trade worth making for one OS
// version that Google stopped patching in 2018.
//
// Pinned rather than left as flutter.minSdkVersion so the next Flutter upgrade
// cannot move it again without somebody editing this line and reading this.
val androidMinSdk = 24

android {
    namespace = "com.mastermind.consultants.hrms"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias     = keystoreProperties["keyAlias"]     as String? ?: ""
            keyPassword  = keystoreProperties["keyPassword"]  as String? ?: ""
            storeFile    = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword= keystoreProperties["storePassword"]as String? ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.mastermind.consultants.hrms"
        minSdk = androidMinSdk
        targetSdk     = flutter.targetSdkVersion
        // Taken from pubspec.yaml's `version:` rather than written here.
        //
        // These were pinned at 14 / "1.0.14" while the pubspec had moved on to
        // 1.2.0+16, so every Android build since carried the old number whatever
        // the pubspec said — and Play rejects a bundle whose versionCode it has
        // already seen. One source of truth avoids shipping a release that looks
        // like the previous one.
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig   = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
