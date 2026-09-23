plugins {
    id("com.android.application")
    id("kotlin-android")
    // Plugin Flutter phải được khai báo sau plugin Android và Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bleattendance.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.bleattendance.app"
        // Các giá trị SDK và phiên bản được quản lý từ cấu hình Flutter.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Bản mẫu dùng khóa debug; production phải dùng khóa release riêng.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
