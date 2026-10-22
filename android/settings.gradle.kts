pluginManagement {
    buildscript {
        repositories {
            google()
            mavenCentral()
            maven {
                url = uri("https://storage.googleapis.com/r8-releases/raw")
                content { includeModule("com.android.tools", "r8") }
            }
        }
        dependencies {
            // Firebase Auth 25 requires Kotlin 2.4 metadata support.
            classpath("com.android.tools:r8:9.1.29")
        }
    }
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
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
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Reads android/app/google-services.json for Firebase.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
