import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadPropertiesFile = rootProject.file("key.properties")
val uploadProperties = Properties().apply {
    if (uploadPropertiesFile.isFile) {
        uploadPropertiesFile.inputStream().use { load(it) }
    }
}
val uploadStoreFile = uploadProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }?.let { rootProject.file(it) }

android {
    namespace = "community.planets.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "community.planets.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = uploadProperties.getProperty("keyAlias")
            keyPassword = uploadProperties.getProperty("keyPassword")
            storeFile = uploadStoreFile
            storePassword = uploadProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Keep debug builds usable without secrets, but gate every release entry point
// (including aggregate Gradle builds). Never produce an unsigned/debug release.
tasks.configureEach {
    if (name == "preReleaseBuild" || name == "validateSigningRelease") {
        doFirst {
            val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            val missing = required.filter { uploadProperties.getProperty(it).isNullOrBlank() }
            check(uploadPropertiesFile.isFile && missing.isEmpty()) {
                "PLANETS release signing requires android/key.properties with " +
                    "storeFile, storePassword, keyAlias and keyPassword. " +
                    "See docs/development/play-closed-test.md. Missing fields: ${missing.joinToString()}"
            }
            check(uploadStoreFile?.isFile == true) {
                "PLANETS upload keystore does not exist; check storeFile in android/key.properties."
            }
            check(uploadProperties.getProperty("keyAlias") != "androiddebugkey" &&
                uploadStoreFile?.name != "debug.keystore") {
                "PLANETS release builds require an upload key, not the Android debug key."
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
