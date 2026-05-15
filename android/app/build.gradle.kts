import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dropinbad.badminton"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "dropinbad.badminton"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            val alias = keystoreProperties.getProperty("keyAlias")
            if (!alias.isNullOrBlank()) {
                create("release") {
                    keyAlias = alias
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                    storePassword = keystoreProperties.getProperty("storePassword")
                    storeFile = rootProject.file(keystoreProperties.getProperty("storeFile")!!)
                }
            }
        }
    }

    buildTypes {
        release {
            val releaseCfg = signingConfigs.findByName("release")
            signingConfig = releaseCfg ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // เพิ่มบรรทัดนี้เพื่อดึง library สำหรับ desugaring มาใช้
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
