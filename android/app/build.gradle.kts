import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read properties from local.properties
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

// Release signing config, read from android/key.properties (gitignored -
// see android/.gitignore's `key.properties` / `**/*.keystore` / `**/*.jks`
// entries; never commit the real file, only share it or its values
// out-of-band with whoever else needs to produce a signed release build).
// Falls back to null (handled below) rather than throwing if the file is
// missing, so debug builds and CI checkouts without release secrets still
// configure and build normally - only `assembleRelease`/`bundleRelease`
// actually need this to be present and correct.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
val hasReleaseSigningConfig = keyPropertiesFile.exists()
if (hasReleaseSigningConfig) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "com.example.intravel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.intravel"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Pass the key to AndroidManifest.xml
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Use the real release keystore (android/key.properties) once
            // it exists; otherwise fall back to debug-signing so the
            // project still builds for anyone who hasn't set up release
            // signing yet. A build using the debug-signed fallback is NOT
            // suitable for distribution - it must not be what ships.
            signingConfig = if (hasReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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