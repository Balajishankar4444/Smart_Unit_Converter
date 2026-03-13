import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.balaji.smart_converter"
    compileSdk = 36 // Updated to 36 as required

    signingConfigs {
        create("release") {
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            
            if (keystorePropertiesFile.exists()) {
                // Using 'use' ensures the file stream is closed properly
                keystorePropertiesFile.inputStream().use { input ->
                    keystoreProperties.load(input)
                }
                
                // We use .getProperty() and provide a default empty string to avoid NullPointerException
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
                storePassword = keystoreProperties.getProperty("storePassword") ?: ""
                
                val stFile = keystoreProperties.getProperty("storeFile")
                if (!stFile.isNullOrEmpty()) {
                    storeFile = file(stFile)
                }
            } else {
                logger.error("ERROR: key.properties not found at: ${keystorePropertiesFile.absolutePath}")
            }
        }
    }

    defaultConfig {
        applicationId = "com.balaji.smart_converter"
        minSdk = 26
        targetSdk = 35 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}