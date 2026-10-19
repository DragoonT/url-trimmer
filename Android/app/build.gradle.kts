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
        versionCode = 14
        versionName = "0.3.2"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}
