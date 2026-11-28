plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.dragoon.trimplaylist"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.dragoon.trimplaylist"
        minSdk = 26
        targetSdk = 35
        versionCode = 20
        versionName = "0.1.19"
        ndk {
            // Phone ABIs only — keeps the APK under GitHub's upload limits.
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    val ytdlpAndroid = "0.18.1"
    implementation("io.github.junkfood02.youtubedl-android:library:$ytdlpAndroid")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:$ytdlpAndroid")
}
