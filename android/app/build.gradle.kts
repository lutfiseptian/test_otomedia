plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.test_otomedia"
    compileSdk = 36 // ✅ Tetap di 36 untuk geolocator
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // ✅ PERBAIKAN DI SINI: Menggunakan kotlinOptions standar Kotlin DSL yang aman
    kotlinOptions {
        freeCompilerArgs = freeCompilerArgs + "-Xjvm-default=all"
        @Suppress("DEPRECATION")
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.test_otomedia"
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // ✅ Sesuaikan target ke 36 juga agar optimal
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
