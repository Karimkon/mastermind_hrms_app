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
        minSdk = flutter.minSdkVersion
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
