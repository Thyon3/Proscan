plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply Firebase plugins conditionally - only if google-services.json exists
// This prevents build failures when Firebase is not configured
val googleServicesFile = project.file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    logger.warn("WARNING: google-services.json not found. Firebase features will be disabled.")
    logger.warn("To enable Firebase: Download google-services.json from Firebase Console and place in android/app/")
}

android {
    namespace = "com.example.thyscan"
    // Use compileSdk 36 for production-ready build
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        // Disable Kotlin incremental compilation at task level
        // Prevents cross-drive path resolution issues
        freeCompilerArgs += listOf("-Xno-check-actual")
    }

    // Force all androidx.work dependencies to use a consistent version
    // This resolves duplicate class errors with workmanager
    configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "androidx.work") {
                    // Force all modules in the androidx.work group to a consistent version
                    useVersion("2.9.0")
                }
            }
        }
    }

    defaultConfig {
        applicationId = "com.example.thyscan"
        // Minimum SDK 23 (Android 6.0) required for WorkManager 2.9.0
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Add packaging options for 16 KB page size support
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
